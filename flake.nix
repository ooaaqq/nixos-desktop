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
      localFiles = map (path: ./. + "/${path}") [
        "local.nix"
        "local-hardware.nix"
        "secrets/password.yaml"
        "secrets/mihomo-subscription-url"
      ];
      hasLocalConfiguration = builtins.all builtins.pathExists localFiles;
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
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      nixosConfigurations = {
        example = mkDesktop;
      }
      // nixpkgs.lib.optionalAttrs hasLocalConfiguration {
        desktop = mkDesktop;
      };
    };
}
