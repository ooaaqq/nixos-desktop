{
  lib,
  stdenv,
  fetchurl,
  ffmpeg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libGL,
  libxkbcommon,
  libxshmfence,
  mesa,
  nspr,
  nss,
  pango,
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

let
  transparentExportManifest = fetchurl {
    url = "https://raw.githubusercontent.com/chthollyphile/folia-major/v0.7.7/mods/sample-transparent-mov-export/mod.json";
    hash = "sha256-tqGNDKVg+hwdkOCPzceiGSJw/MFaPu32uCK3HNA0Rfo=";
  };
  transparentExportEntry = fetchurl {
    url = "https://raw.githubusercontent.com/chthollyphile/folia-major/v0.7.7/mods/sample-transparent-mov-export/index.cjs";
    hash = "sha256-hxGXj6A+TooEAhOeIfiAyj7Kj7MlOKHiNMMmLjuv6Zc=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "folia-major";
  version = "0.7.7";

  src = fetchurl {
    url = "https://github.com/chthollyphile/folia-major/releases/download/v${finalAttrs.version}/folia-major-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-nv+A94kg2D2Dt46BUIZCXguV8W+d6dRnGWcPsM7fy9Y=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libGL
    libxkbcommon
    libxshmfence
    mesa
    nspr
    nss
    pango
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
  runtimeDependencies = [ (lib.getLib systemd) ];
  dontStrip = true;
  # NixOS uses glibc; Koffi also ships an unused Alpine/musl variant.
  postUnpack = ''
    rm -r "$sourceRoot/resources/app.asar.unpacked/node_modules/@koromix/koffi-linux-x64/musl_x64"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/folia-major" "$out/bin" "$out/share/applications"
    cp -a . "$out/lib/folia-major/"
    install -Dm644 ${transparentExportManifest} \
      "$out/lib/folia-major/resources/mods/transparent-mov-export/mod.json"
    install -Dm644 ${transparentExportEntry} \
      "$out/lib/folia-major/resources/mods/transparent-mov-export/index.cjs"

    install -Dm644 resources/icon.png "$out/share/icons/hicolor/512x512/apps/folia-major.png"
    substitute resources/linux/folia-major.desktop "$out/share/applications/folia-major.desktop" \
      --replace-fail '__APP_PATH__' "$out/bin/folia-major" \
      --replace-fail '__ICON_PATH__' 'folia-major'
    makeWrapper "$out/lib/folia-major/folia-major" "$out/bin/folia-major" \
      --set FOLIA_FFMPEG_PATH ${lib.getExe ffmpeg} \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          wayland
          libxkbcommon
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "Music player with animated lyrics";
    homepage = "https://github.com/chthollyphile/folia-major";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "folia-major";
  };
})
