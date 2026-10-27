{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libGL,
  libgbm,
  libpulseaudio,
  libxkbcommon,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  wayland,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "splayer-next";
  version = "1.2.0";

  src = fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer-Next/releases/download/v${finalAttrs.version}/splayer-next-${finalAttrs.version}-amd64.deb";
    hash = "sha256-7dgjIBhIIMi3Y9QM4I2idxr2U7ePZlW1sICLcYsxXbw=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];
  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libGL
    libgbm
    libpulseaudio
    libxkbcommon
    nspr
    nss
    pango
    pipewire
    stdenv.cc.cc.lib
    systemd
    wayland
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/splayer-next" "$out/bin" "$out/share"
    cp -a opt/SPlayer-Next/. "$out/lib/splayer-next/"
    cp -a usr/share/applications usr/share/icons "$out/share/"
    substituteInPlace "$out/share/applications/top.imsyy.splayer_next.desktop" \
      --replace-fail '/opt/SPlayer-Next/SPlayer-Next' "$out/bin/SPlayer-Next"
    ln -s "$out/lib/splayer-next/SPlayer-Next" "$out/bin/SPlayer-Next"
    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${
      lib.makeLibraryPath [
        libGL
        libpulseaudio
        pipewire
        wayland
      ]
    }")
  '';

  meta = {
    description = "Music player with NetEase Cloud Music and QQ Music account support";
    homepage = "https://github.com/SPlayer-Dev/SPlayer-Next";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "SPlayer-Next";
  };
})
