{
  config,
  codex-cli-nix,
  lib,
  pkgs,
  ...
}:
let
  local = if builtins.pathExists ../local.nix then import ../local.nix else { };
  userName = local.userName or "desktop";
  homeDirectory = local.homeDirectory or "/home/desktop";
  hostName = local.hostName or "nixos-desktop";
  hasPassword = builtins.pathExists ../secrets/password.yaml;
  hasMihomoSubscription = builtins.pathExists ../secrets/mihomo-subscription-url;
in
{
  imports = lib.optional (builtins.pathExists ../local-hardware.nix) ../local-hardware.nix;

  # Generic defaults keep the public configuration evaluable. The ignored
  # local-hardware.nix provides the real devices on the installed machine.
  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/NIXOS_ROOT";
    fsType = lib.mkDefault "btrfs";
  };

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        consoleMode = "max";
      };
    };
  };

  networking = {
    inherit hostName;
    modemmanager.enable = false;
    networkmanager = {
      enable = true;
      # Apply Mihomo DNS after each DHCP resolver update.
      insertNameservers = [ "127.0.0.1" ];
    };
    firewall = rec {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
    nftables.enable = true;
  };

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  users = {
    mutableUsers = !hasPassword;
    users.${userName} = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [
        "networkmanager"
        "render"
        "video"
        "wheel"
      ];
      hashedPasswordFile = lib.mkIf hasPassword config.sops.secrets.password-hash.path;
    };
  };
  security.sudo.wheelNeedsPassword = false;

  services = {
    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      extraConfig.pipewire."10-clock-rates"."context.properties" = {
        "default.clock.allowed-rates" = [
          44100
          48000
          96000
        ];
      };
    };
    geoclue2.enable = false;
    orca.enable = false;
    speechd.enable = false;
  };
  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    graphics.enable = true;
    amdgpu.opencl.enable = true;
  };
  security.rtkit.enable = true;
  programs = {
    kdeconnect.enable = true;
    steam.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.nginx = {
    enable = true;
    virtualHosts."127.0.0.1" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 8765;
        }
      ];
      root = "${pkgs.ariang}/share/ariang";
    };
  };
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    discover
    elisa
    gwenview
    kate
    khelpcenter
    okular
    plasma-browser-integration
    kwin-x11
    krdp
    plasma-keyboard
    qtvirtualkeyboard
    union
    dolphin-plugins
    ffmpegthumbs
  ];
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    autoLogin = {
      enable = false;
    };
  };
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-rime
      ];
      settings.addons.classicui.globalSection = {
        Theme = "plasma";
        DarkTheme = "plasma";
        UseDarkTheme = "True";
        UseAccentColor = "True";
      };
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "rime";
        };
        "Groups/0/Items/0" = {
          Name = "rime";
          Layout = "";
        };
        GroupOrder."0" = "Default";
      };
    };
  };

  fonts = {
    packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
    fontconfig.defaultFonts = {
      sansSerif = [
        "Noto Sans"
        "Noto Sans CJK SC"
      ];
      serif = [
        "Noto Serif"
        "Noto Serif CJK SC"
      ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono CJK SC"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  sops = lib.mkIf (hasPassword || hasMihomoSubscription) (
    {
      age.keyFile = local.ageKeyFile or "/var/lib/sops-nix/key.txt";
      secrets =
        lib.optionalAttrs hasPassword {
          password-hash = {
            sopsFile = ../secrets/password.yaml;
            format = "yaml";
            neededForUsers = true;
          };
        }
        // lib.optionalAttrs hasMihomoSubscription {
          mihomo-subscription-url = { };
        };
    }
    // lib.optionalAttrs hasMihomoSubscription {
      defaultSopsFile = ../secrets/mihomo-subscription-url;
      defaultSopsFormat = "binary";
    }
  );

  services.mihomo = lib.mkIf hasMihomoSubscription {
    enable = true;
    configFile = "/var/lib/mihomo-subscription/config.yaml";
    tunMode = true;
    webui = pkgs.metacubexd;
  };
  environment.systemPackages = lib.optionals hasMihomoSubscription [
    (pkgs.writeShellApplication {
      name = "mihomo-update";
      runtimeInputs = [
        pkgs.mihomo
        pkgs.systemd
      ];
      text = ''
        exec ${pkgs.python3.withPackages (p: [ p.pyyaml ])}/bin/python3 ${../pkgs/mihomo-update.py} "$@"
      '';
    })
  ];
  systemd.services.mihomo.serviceConfig = {
    AmbientCapabilities = lib.mkForce [
      "CAP_NET_ADMIN"
      "CAP_NET_BIND_SERVICE"
    ];
    CapabilityBoundingSet = lib.mkForce [
      "CAP_NET_ADMIN"
      "CAP_NET_BIND_SERVICE"
    ];
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    settings = {
      substituters = [
        "https://cache.nixos.org/"
        "https://codex-cli.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
  nixpkgs.config.allowUnfree = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit codex-cli-nix userName homeDirectory; };
    users.${userName} = import ../home/desktop.nix;
  };

  system.stateVersion = "26.11";
}
