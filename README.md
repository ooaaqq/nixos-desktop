# NixOS 桌面

Plasma 6、Wayland 和 Home Manager 配置。 `hosts/desktop.nix`
管理系统，`home/desktop.nix` 管理用户应用和桌面设置。 使用 infra
工作区的开发环境。

## 本机配置

以下文件只保存在本机，不提交 Git：

- `local.nix`：账户、家目录和主机名。
- `local-hardware.nix`：文件系统和硬件。
- `.sops.yaml.local`：本机加密规则。
- `secrets/password.yaml`：加密后的本机凭据。

本机文件必须齐全，flake 只提供真实 `desktop`。 本机操作使用 `path:.`，让 Nix
读取被 Git 忽略的配置。

## 检查和切换

```sh
infra check nixos-desktop
sudo nixos-rebuild switch --flake path:.#desktop
```

`switch` 完成构建并切换。切换后检查本次修改的实际功能。调查时可以用 `nix build`
单独构建，或用 `nixos-rebuild test` 临时切换。更新系统输入用
`nix flake update`，审查 diff 后按上面步骤交付。 Codex 由 `codex-cli-nix`
输入提供，缓存见 `hosts/desktop.nix`；CC Switch 单独固定在
`pkgs/cc-switch.nix`。 账户和应用数据继续保存在本机。系统提供原生
`/etc/containers` 配置和 `nix-ld`，供工作区容器工具及 npm 锁定的 Linux
二进制使用。维护工具由工作区环境提供。

## Mihomo

官方 NixOS 模块运行代理，配置为 `/etc/mihomo/config.yaml`，仅 root 可读，通过
systemd credential 加载。 新机器首次启用前需准备配置。在 infra 工作区运行：

```sh
infra mihomo apply
```

该命令渲染 fleet 策略并调用本机
`mihomo-update`。安装器校验配置、保留代理组选择，启动失败时恢复旧配置；内容相同则跳过重启。
更新策略无需重建桌面。便携导出见 fleet 的 `services/mihomo/README.md`，生成的
YAML 含凭据。
