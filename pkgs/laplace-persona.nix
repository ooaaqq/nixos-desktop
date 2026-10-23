{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libGL,
  libxkbcommon,
  libgbm,
  vulkan-loader,
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

stdenv.mkDerivation (finalAttrs: {
  pname = "laplace-persona";
  version = "0.71.3";

  src = fetchurl {
    url = "https://downloads.vrp.moe/persona/v${finalAttrs.version}/laplace-persona_${finalAttrs.version}_amd64.deb";
    hash = "sha512-ANmjznThqEkwzJvlqBMEIUPNUtnvWUT6FnoZyZGe8dm1G3/jGe/i9U+lkvak5lYmTQ/z5fu7Q9sJ38bT+AEp2Q==";
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
    gsettings-desktop-schemas
    gtk3
    libGL
    libxkbcommon
    libgbm
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
  dontStrip = true;
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/laplace-persona" "$out/bin" "$out/share"
    cp -a opt/"LAPLACE Persona"/. "$out/lib/laplace-persona/"
    cp -a usr/share/applications usr/share/icons "$out/share/"
    substituteInPlace "$out/share/applications/laplace-persona.desktop" \
      --replace-fail '"/opt/LAPLACE Persona/laplace-persona"' "$out/bin/laplace-persona"
    # Match nixpkgs Electron: the bundled loader cannot discover NixOS drivers.
    ln -sf "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" "$out/lib/laplace-persona/libvulkan.so.1"
    ln -s "$out/lib/laplace-persona/laplace-persona" "$out/bin/laplace-persona"
    runHook postInstall
  '';

  # These libraries are loaded dynamically by Electron's GL/Wayland backends.
  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${
      lib.makeLibraryPath [
        libGL
        wayland
      ]
    }")
    # Linux WebGPU needs opt-in; ANGLE provides Vulkan interop on Wayland.
    gappsWrapperArgs+=(
      --add-flags --enable-unsafe-webgpu
      --add-flags --enable-features=Vulkan,VulkanFromANGLE
      --add-flags --use-angle=vulkan
    )
  '';

  meta = {
    description = "Live2D and VRM virtual avatar studio";
    homepage = "https://laplace.live/persona";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "laplace-persona";
  };
})
