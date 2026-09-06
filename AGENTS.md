# Agent Guide

This checkout is the declarative source for one NixOS Plasma 6 desktop on
Wayland. Keep changes small, explicit, reproducible, and easy to review.

## Repository shape

- `flake.nix`: flake inputs and the `desktop` NixOS output.
- `hosts/desktop.nix`: system services, hardware defaults, networking, SOPS,
  and Home Manager wiring.
- `home/desktop.nix`: user applications, desktop preferences, and shell policy.
- `home/rime/`: checked-in Rime customization only.
- `README.md`: public operator documentation.

The repository deliberately has one host and no speculative module framework.
Extract shared modules only when a second host or a real reuse case exists.

## Local-only layer

The following files are ignored and must stay out of Git:

- `local.nix`: account, home directory, and host name for this installation.
- `local-hardware.nix`: generated filesystem and hardware settings.
- `.sops.yaml.local`: local SOPS creation rules.
- `secrets/password.yaml` and `secrets/mihomo-config`: encrypted local data.

Do not print, commit, or move plaintext secrets, age private keys, subscription
URLs, or backup passwords into the repository. Public age recipient keys and
machine UUIDs are not needed by the public configuration and should remain in
the local layer as well.

## Change workflow

Inspect the worktree before editing and preserve unrelated changes. For Nix
changes, run:

```bash
nix fmt -- --ci
nix flake check --no-build path:.
nix build path:.#nixosConfigurations.desktop.config.system.build.toplevel
```

Only activate an authorized change after evaluation and build checks pass:

```bash
sudo nixos-rebuild test --flake path:.#desktop
sudo nixos-rebuild switch --flake path:.#desktop
```

`test` is temporary. Do not reboot unless explicitly requested. A successful
evaluation or build is not proof that a service is healthy; check the affected
runtime behavior after activation.

The `path:.` prefix is mandatory because ignored local files are excluded from
Git-backed flake evaluation. Never activate `.#example`. A plain `.#desktop`
must fail rather than silently use generic identity or filesystem defaults.

## Package policy

Keep ordinary applications in Home Manager and keep Steam at the system layer.
Project-specific Node, Rust, Go, and native toolchains belong in project
flakes, not the global desktop closure.

The main system follows `nixos-unstable`. Applications that need a faster
release cadence should use a focused package or flake input. Codex uses the
dedicated `codex-cli-nix` package and its documented third-party cache; do not
replace the whole system input just to update one application.

Avoid mutable nightly URLs when an immutable release or commit is available.
Every manually fetched source needs a fixed hash and a focused verification.

## Networking and secrets

Mihomo is managed by the official NixOS module as the only proxy core. Keep
its controller, subscription, and decrypted runtime files local. Do not add a
second core, custom wrapper service, or an external UI path under the home
directory.

For incidents, start read-only: inspect unit state, logs, listeners, resolver
configuration, and the actual traffic path before changing routing or
restarting services.

## Public repository boundary

The public branch contains only generic configuration and documentation. Do
not add personal paths, host identifiers, filesystem layout, recovery mounts,
credentials, or local diagnostic artifacts. The local ignored layer is the
place for machine-specific values.
