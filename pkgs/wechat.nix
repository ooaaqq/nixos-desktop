{
  wechat,
  symlinkJoin,
  makeWrapper,
  fcitx5-gtk,
  qt5,
  qt6Packages,
}:

symlinkJoin {
  name = "wechat-${wechat.version}";
  inherit (wechat) pname version meta;
  paths = [ wechat ];
  nativeBuildInputs = [ makeWrapper ];

  # The AppImage needs the legacy GTK and Qt input modules on Wayland.
  postBuild = ''
    wrapProgram "$out/bin/wechat" \
      --set GTK_IM_MODULE fcitx \
      --set GTK_PATH "${fcitx5-gtk}/lib/gtk-3.0" \
      --set QT_IM_MODULE fcitx \
      --set QT_PLUGIN_PATH "${qt6Packages.fcitx5-with-addons}/${qt5.qtbase.qtPluginPrefix}"
  '';
}
