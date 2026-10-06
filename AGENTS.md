# 桌面维护

修改前读取 infra 工作区的共同原则。本仓库只有一台 Plasma 6 / Wayland 桌面，出现实际复用需求再拆模块。

## 结构与本机边界

- `hosts/desktop.nix`：系统、硬件默认值、网络、SOPS 和 Home Manager 接入。
- `home/desktop.nix`：用户应用、桌面和 Shell 设置。
- `home/rime/`：Rime 自定义配置。
- README：本机配置、检查和切换命令。

`local.nix`、`local-hardware.nix`、`.sops.yaml.local` 和 `secrets/password.yaml` 保持 Git 忽略。
公开源码只含通用配置，账户路径、主机身份、文件系统、恢复挂载、机器 UUID 和 age recipient 放在本机层。
明文凭据、age 私钥、订阅 URL、备份密码和本机诊断产物不进入 Git。

## 修改流程

先检查工作树并保留无关改动。Nix 改动按 README 完成格式、求值和构建检查，再激活已授权的修改。
必须使用 `path:.` 读取本机层；普通 Git flake 不能静默生成可安装的通用桌面。
不激活 `example`，不擅自重启，切换后验证受影响的实际行为。

## 应用与网络

普通应用放 Home Manager，Steam 放系统层。项目工具链放项目开发环境，不扩大全局桌面依赖。
系统跟随 `nixos-unstable`；需更快更新的应用使用独立包或输入，下载固定版本或 revision 与哈希。
Codex 使用 `codex-cli-nix` 及其已声明的缓存，单个应用更新不替换整个系统输入。

Mihomo 使用官方模块。fleet 管策略，本仓库管服务和安装器，配置路径及更新命令见 README。
控制器和解密配置只在本机使用，保留 root 权限和 systemd credential，不添加第二个代理核心或更新定时器。
网络故障先查看 unit、日志、监听端口、解析器和实际流量路径，再修改路由或重启服务。
