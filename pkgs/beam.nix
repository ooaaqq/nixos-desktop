{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
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
  ffmpeg_8,
  libva,
  vips,
  wl-clipboard,
  xclip,
  gsettings-desktop-schemas,
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
  pname = "beam";
  version = "0.5.8";

  src = fetchurl {
    url = "https://github.com/BeamRecorder/Beam/releases/download/${finalAttrs.version}/Beam-${finalAttrs.version}-linux-amd64.deb";
    hash = "sha256-IMYxKXvy/GKoW5c43SFw2IFWnL5wPhlAMukkYm9t8Zs=";
  };

  inputPolicy = fetchurl {
    url = "https://raw.githubusercontent.com/BeamRecorder/Beam/${finalAttrs.version}/packages/capture/src/bin/beam-input-helper.policy";
    hash = "sha256-RCPpemOmPAjtQssikDrApTybidU2pNe82dKMJSHfMbU=";
  };

  nativeBuildInputs = [
    dpkg
    patchelf
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
    gsettings-desktop-schemas
    ffmpeg_8
    libva
    vips
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
    mkdir -p "$out/lib/beam" "$out/bin" "$out/share"
    cp -a opt/Beam/. "$out/lib/beam/"
    # The upstream archive includes musl variants alongside the glibc addons.
    find "$out/lib/beam/resources" -type d \( -name '*-musl' -o -name '*linuxmusl*' \) -prune -exec rm -rf {} +
    # Sharp's prebuilt addon names libvips by release; nixpkgs uses its ABI soname.
    patchelf --replace-needed libvips-cpp.so.8.18.7 libvips-cpp.so.42 \
      "$out/lib/beam/resources/app.asar.unpacked/node_modules/@img/sharp-linux-x64/lib/sharp-linux-x64-0.35.5.node"
    cp -a usr/share/applications usr/share/icons "$out/share/"
    substituteInPlace "$out/share/applications/com.beam.app.desktop" \
      --replace-fail '/opt/Beam/beam' "$out/bin/beam"
    ln -s "$out/lib/beam/beam" "$out/bin/beam"
    ln -s "$out/lib/beam/beam-cli" "$out/bin/beam-cli"
    mkdir -p "$out/share/polkit-1/actions"
    cp ${finalAttrs.inputPolicy} "$out/share/polkit-1/actions/com.beam.input-monitor.policy"
    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : "${
      lib.makeBinPath [
        ffmpeg_8
        wl-clipboard
        xclip
      ]
    }")
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
    description = "Screen recorder and editor with smooth cursors and automatic zoom";
    homepage = "https://github.com/BeamRecorder/Beam";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "beam";
  };
})
