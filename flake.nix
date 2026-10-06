{
  description = "NixOS Plasma desktop configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      sops-nix,
      codex-cli-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkDesktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit codex-cli-nix; };
        modules = [
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          ./hosts/desktop.nix
        ];
      };
    in
    {
      checks.${system}.mihomo =
        pkgs.runCommand "mihomo-update-checks"
          {
            src = nixpkgs.lib.fileset.toSource {
              root = ./.;
              fileset = nixpkgs.lib.fileset.unions [
                ./pkgs/mihomo-update.py
                ./tests/test_mihomo_update.py
              ];
            };
            nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ];
          }
          ''
            cp -r "$src" source
            chmod -R u+w source
            cd source
            python3 -m unittest discover -s tests -p 'test_*.py'
            touch "$out"
          '';
      formatter.${system} = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [
          pkgs.treefmt
          pkgs.nixfmt
          pkgs.ruff
        ];
        text = ''exec treefmt "$@"'';
      };

      nixosConfigurations.desktop = mkDesktop;
    };
}
