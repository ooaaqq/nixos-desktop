{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  glib-networking,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  xz,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cc-switch";
  version = "3.20.4";

  src = fetchurl {
    url = "https://github.com/farion1231/cc-switch/releases/download/v${finalAttrs.version}/CC-Switch-v${finalAttrs.version}-Linux-x86_64.deb";
    hash = "sha256-Q0VX064It5LIE4xVCPEE55nzbSztVj+5SzqG/7slCAE=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];
  buildInputs = [
    glib-networking
    libayatana-appindicator
    openssl
    webkitgtk_4_1
    xz
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/bin usr/share "$out/"
    substituteInPlace "$out/share/applications/CC Switch.desktop" \
      --replace-fail 'Categories=' 'Categories=Development;'
    runHook postInstall
  '';

  # The tray library is loaded dynamically rather than linked into the binary.
  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}")
  '';

  meta = {
    description = "Account and provider manager for AI coding applications";
    homepage = "https://github.com/farion1231/cc-switch";
    license = lib.licenses.mit;
    mainProgram = "cc-switch";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
