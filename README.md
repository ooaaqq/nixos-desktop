# NixOS Plasma Desktop

Declarative NixOS and Home Manager configuration for a Plasma 6 desktop on
Wayland. System services live in `hosts/desktop.nix`; user applications and
desktop preferences live in `home/desktop.nix`.

## Local machine layer

Machine-specific identity, filesystem hardware, SOPS policy, and encrypted
secrets are intentionally kept outside the public checkout:

- `local.nix` supplies the local account, home directory, and host name.
- `local-hardware.nix` supplies generated filesystem and hardware settings.
- `.sops.yaml.local` supplies local encryption rules.
- `secrets/password.yaml` and `secrets/mihomo-config` remain untracked.

The public Git tree exposes only the `example` configuration. A complete local
checkout exposes `desktop` when all ignored machine files are present. This
fails closed: accidentally evaluating the Git-only source cannot produce an
installable generic system in place of the real machine configuration.

Never commit an age private key, plaintext secret, subscription URL, or backup
password.

## Build and activate

```bash
nix flake check --no-build path:.
nix build path:.#nixosConfigurations.desktop.config.system.build.toplevel
sudo nixos-rebuild test --flake path:.#desktop
sudo nixos-rebuild switch --flake path:.#desktop
```

`test` is temporary and does not survive a reboot. Reboot only when it is
intentional and separately verified.

## Updates

The main system follows `nixos-unstable`. Update the lock file deliberately,
review the diff, and test before switching:

```bash
nix flake update
nix flake check --no-build path:.
sudo nixos-rebuild test --flake path:.#desktop
```

Codex is supplied by the dedicated `codex-cli-nix` flake so it can follow
upstream releases independently of the main nixpkgs update. Its public
third-party binary cache is declared in `hosts/desktop.nix`.

## Secrets and networking

Mihomo is the only proxy core. Its configuration is decrypted by sops-nix at
activation time and is never stored as plaintext in Git. Keep the local
dashboard and subscription details private.

## Development

Project-specific Node, Rust, Go, and native toolchains belong in each
project's own `nix develop` environment. This desktop configuration should
remain small and reproducible.
