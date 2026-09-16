{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "cockpit-tools";
  version = "1.3.53";
  src = fetchurl {
    url = "https://github.com/jlcodes99/cockpit-tools/releases/download/v${version}/Cockpit.Tools_${version}_amd64.AppImage";
    hash = "sha256-nMAPfPBEKidsX+7kYUKnEbuQw29yh7DLfKftO1rKPRM=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      # The upstream AppImage bundles Wayland libraries. On newer Mesa hosts
      # they make WebKitGTK fail before it can create its EGL display. Let the
      # FHS environment provide the host-compatible Wayland libraries instead.
      rm -f "$out"/usr/lib/libwayland-*.so*
    '';
  };
in
appimageTools.wrapAppImage rec {
  inherit pname version;
  src = appimageContents;

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/Cockpit Tools.desktop" \
      "$out/share/applications/Cockpit Tools.desktop"
    cp -a "${appimageContents}/usr/share/icons" "$out/share/"
    substituteInPlace "$out/share/applications/Cockpit Tools.desktop" \
      --replace-fail 'Comment=Cockpit Tools' 'Comment=Universal AI IDE account manager' \
      --replace-fail 'Exec=cockpit-tools' 'Exec=cockpit-tools %U'
  '';

  meta = {
    description = "Universal AI IDE account management tool";
    homepage = "https://github.com/jlcodes99/cockpit-tools";
    mainProgram = "cockpit-tools";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
