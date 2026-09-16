{
  pkgs,
  codex-cli-nix,
  userName ? "desktop",
  homeDirectory ? "/home/desktop",
  ...
}:
let
  rimeData = pkgs.symlinkJoin {
    name = "rime-data";
    paths = [
      "${pkgs.rime-ice}/share/rime-data"
      ./rime
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
  wechatDirect = pkgs.callPackage (pkgs.path + "/pkgs/by-name/we/wechat/package.nix") {
    fetchurl =
      _:
      pkgs.fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-ay4g5wAGNy6N37rkDqhkVkUgyHsH0BYLYA7JP3j9XMI=";
      };
  };
  cockpitTools = pkgs.callPackage ../pkgs/cockpit-tools.nix { };
  davinciResolve = pkgs.callPackage ../pkgs/davinci-resolve.nix { };
  foliaMajor = pkgs.callPackage ../pkgs/folia-major.nix { };
in
{
  home = {
    username = userName;
    homeDirectory = homeDirectory;
    stateVersion = "26.11";
  };

  home.packages = with pkgs; [
    ariang
    ayugram-desktop
    bililiverecorder
    cockpitTools
    codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    davinciResolve
    foliaMajor
    git
    github-cli
    ghostty
    krita
    libreoffice-stable
    mpv
    netease-cloud-music-gtk
    obs-studio
    qq
    ripgrep
    spotify
    unrar
    uv
    vscode
    wechatDirect
  ];

  programs = {
    aria2 = {
      enable = true;
      settings = {
        dir = "${homeDirectory}/Downloads";
        rpc-allow-origin-all = true;
        rpc-listen-all = false;
        rpc-listen-port = 6800;
        max-connection-per-server = 8;
        min-split-size = "10M";
        split = 8;
        user-agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36";
      };
      systemd.enable = true;
    };
    bash.enable = true;
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
    helix = {
      enable = true;
      package = pkgs.helix;
      defaultEditor = true;
      settings.theme = {
        dark = "github_dark_high_contrast";
        light = "github_light";
        fallback = "github_light";
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "text/markdown" = [ "code.desktop" ];
      "text/plain" = [ "code.desktop" ];
      "x-scheme-handler/mailto" = [ "chromium-browser.desktop" ];
      "x-scheme-handler/tg" = [ "userapp-AyuGram Desktop-FDR4S3.desktop" ];
      "x-scheme-handler/tonsite" = [ "userapp-AyuGram Desktop-O5H4S3.desktop" ];
    };
    defaultApplications = {
      "text/markdown" = [ "code.desktop" ];
      "text/plain" = [ "code.desktop" ];
      "x-scheme-handler/mailto" = [ "chromium-browser.desktop" ];
      "x-scheme-handler/tg" = [ "userapp-AyuGram Desktop-FDR4S3.desktop" ];
      "x-scheme-handler/tonsite" = [ "userapp-AyuGram Desktop-O5H4S3.desktop" ];
    };
  };

  # Replace the existing Plasma-generated file when Home Manager first takes
  # ownership of these declarative MIME associations.
  xdg.configFile."mimeapps.list".force = true;

  xdg.configFile."Code/User/settings.json".text = builtins.toJSON {
    "editor.formatOnPaste" = false;
    "editor.formatOnSave" = false;
    "extensions.ignoreRecommendations" = true;
    "files.autoSave" = "onFocusChange";
    "files.insertFinalNewline" = true;
    "files.trimFinalNewlines" = true;
    "files.trimTrailingWhitespace" = true;
    "security.workspace.trust.enabled" = false;
    "telemetry.telemetryLevel" = "off";
    "window.autoDetectColorScheme" = true;
    "workbench.preferredDarkColorTheme" = "Dark 2026";
    "workbench.preferredLightColorTheme" = "Light 2026";
    "workbench.startupEditor" = "none";
  };

  xdg.configFile."ghostty/config".text = ''
    theme = light:Adwaita,dark:Adwaita Dark
    window-theme = system
  '';

  # Serve AriaNg over the local HTTP endpoint because Chromium blocks RPC
  # requests from the packaged file:// entry.
  xdg.desktopEntries.ariang = {
    name = "AriaNg";
    comment = "Web frontend for aria2";
    exec = "chromium --app=http://127.0.0.1:8765/";
    icon = "ariang";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "WebBrowser"
    ];
  };

  # The packaged entry advertises D-Bus activation, but its D-Bus service is
  # not linked into the Home Manager profile. Launch the installed binary
  # directly instead.
  xdg.desktopEntries."com.ayugram.desktop" = {
    name = "AyuGram Desktop";
    comment = "Desktop version of AyuGram";
    exec = "env DESKTOPINTEGRATION=1 AyuGram -- %U";
    icon = "com.ayugram.desktop";
    terminal = false;
    type = "Application";
    settings.DBusActivatable = "false";
  };

  xdg.desktopEntries."com.mitchellh.ghostty" = {
    name = "Ghostty";
    comment = "Fast, feature-rich, and cross-platform terminal emulator";
    exec = "ghostty";
    icon = "com.mitchellh.ghostty";
    terminal = false;
    type = "Application";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    settings.DBusActivatable = "false";
  };

  # The AppImage drops ozone flags before starting its UI. Its legacy GTK and
  # Qt input paths need Fcitx modules, but only WeChat needs this fallback.
  xdg.desktopEntries.wechat = {
    name = "WeChat";
    comment = "WeChat Desktop";
    exec = "env GTK_IM_MODULE=fcitx GTK_PATH=${pkgs.fcitx5-gtk}/lib/gtk-3.0 QT_IM_MODULE=fcitx QT_PLUGIN_PATH=${pkgs.qt6Packages.fcitx5-with-addons}/lib/qt-5.15.19/plugins wechat %U";
    icon = "wechat";
    terminal = false;
    type = "Application";
    categories = [ "Utility" ];
  };

  home.file = {
    ".local/share/fcitx5/rime" = {
      source = rimeData;
      recursive = true;
    };
  };
}
