{
  pkgs,
  codex-cli-nix,
  userName,
  homeDirectory,
  ...
}:
let
  rimeData = pkgs.symlinkJoin {
    name = "rime-data";
    paths = [
      "${pkgs.rime-ice}/share/rime-data"
    ];
    # OpenCC 1.4 requires the previously implicit group matching policy.
    postBuild = ''
      config="$out/opencc/emoji.json"
      cp --remove-destination "${pkgs.rime-ice}/share/rime-data/opencc/emoji.json" "$config"
      chmod u+w "$config"
      substituteInPlace "$config" \
        --replace-fail '"type": "group",' '"type": "group", "match_policy": "short_circuit",'
    '';
  };
  wechat = pkgs.callPackage ../pkgs/wechat.nix { };
  cc-switch = pkgs.callPackage ../pkgs/cc-switch.nix { };
  folia-major = pkgs.callPackage ../pkgs/folia-major.nix { };
  laplace-persona = pkgs.callPackage ../pkgs/laplace-persona.nix { };

in
{
  home = {
    username = userName;
    homeDirectory = homeDirectory;
    stateVersion = "26.11";
  };

  # Plasma manages the writable user fontconfig configuration.
  fonts.fontconfig.enable = false;

  home.packages = with pkgs; [
    ayugram-desktop
    bililiverecorder
    cc-switch
    codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    folia-major
    firefox
    git
    github-cli
    ghostty
    kdePackages.akonadi
    kdePackages.akonadi-search
    kdePackages.gwenview
    kdePackages.kdepim-runtime
    kdePackages.kmail
    kdePackages.kmail-account-wizard
    krita
    laplace-persona
    libreoffice-stable
    micro
    mpv
    netease-cloud-music-gtk
    obs-studio
    qq
    ripgrep
    spotify
    unrar
    vscode
    wechat
  ];

  programs = {
    fish.enable = true;
    starship.enable = true;
    chromium = {
      enable = true;
      commandLineArgs = [
        "--ozone-platform=wayland"
        "--enable-features=MiddleClickAutoscroll"
        "--disable-features=AcceleratedVideoEncoder"
      ];
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  home.sessionVariables = {
    EDITOR = "micro";
    VISUAL = "micro";
  };

  home.shell.enableBashIntegration = false;

  home.file = {
    ".local/share/fcitx5/rime" = {
      source = rimeData;
      recursive = true;
    };
  };
}
