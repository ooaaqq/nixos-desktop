{
  lib,
  makeWrapper,
  mihomo,
  python3,
  runCommand,
  systemd,
}:
let
  python = python3.withPackages (p: [ p.pyyaml ]);
  source = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./mihomo.py
      ./test_mihomo.py
    ];
  };
in
runCommand "mihomo-tools"
  {
    nativeBuildInputs = [ makeWrapper ];
    passthru.tests = runCommand "mihomo-checks" { nativeBuildInputs = [ python ]; } ''
      cp -r ${source} source
      chmod -R u+w source
      cd source
      python3 -m unittest discover -v
      touch "$out"
    '';
  }
  ''
    install -Dm644 ${./mihomo.py} "$out/libexec/mihomo.py"
    mkdir -p "$out/bin"
    makeWrapper ${python}/bin/python3 "$out/bin/mihomo-update" \
      --add-flags "$out/libexec/mihomo.py update" \
      --prefix PATH : ${
        lib.makeBinPath [
          mihomo
          systemd
        ]
      }
    makeWrapper ${python}/bin/python3 "$out/bin/mihomo-ready" \
      --add-flags "$out/libexec/mihomo.py ready"
  ''
