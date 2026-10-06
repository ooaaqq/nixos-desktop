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
  wechat = pkgs.callPackage ../pkgs/wechat.nix { };
  cc-switch = pkgs.callPackage ../pkgs/cc-switch.nix { };
  folia-major = pkgs.callPackage ../pkgs/folia-major.nix { };

in
{
  home = {
    username = userName;
    homeDirectory = homeDirectory;
    stateVersion = "26.11";
  };

  home.packages = with pkgs; [
    ayugram-desktop
    bililiverecorder
    cc-switch
    codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    davinci-resolve
    folia-major
    git
    github-cli
    ghostty
    krita
    libreoffice-stable
    micro
    mpv
    netease-cloud-music-gtk
    obs-studio
    qq
    ripgrep
    spotify
    unrar
    uv
    vscode
    wechat
  ];

  programs = {
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
  };

  home.sessionVariables = {
    EDITOR = "micro";
    VISUAL = "micro";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/markdown" = [ "code.desktop" ];
      "text/plain" = [ "code.desktop" ];
      "x-scheme-handler/mailto" = [ "chromium-browser.desktop" ];
      "x-scheme-handler/tg" = [ "com.ayugram.desktop.desktop" ];
      "x-scheme-handler/tonsite" = [ "com.ayugram.desktop.desktop" ];
    };
  };

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
