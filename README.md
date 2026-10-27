# NixOS 桌面

Plasma 6、Wayland 和 Home Manager 配置。 `hosts/desktop.nix`
管理系统，`home/desktop.nix` 管理用户应用、启动入口和 Shell 环境。 使用 infra
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

## 应用设置

VS Code 通过设置界面或 `~/.config/Code/User/settings.json` 调整；Ghostty 通过
`~/.config/ghostty/config` 调整，使用随包提供的 GitHub Light Default / GitHub Dark
Default 主题并跟随系统明暗偏好；等宽字体跟随系统，启动 fish，窗口装饰由 KWin
提供。Ghostty 是当前默认终端，Plasma 的终端选择保存在 `~/.config/kdeglobals`，
`Ctrl+Alt+T` 的应用快捷键由 KDE 管理。修改配置后用 `Ctrl+Shift+,` 重载，
窗口尺寸和留白等设置需新开窗口生效。
Dolphin 的布局和视图外观通过应用设置调整，保存在 `~/.config/dolphinrc`。
默认应用通过 Plasma 系统设置或文件的“打开方式”
修改，用户关联保存在 `~/.config/mimeapps.list`。

fish 是默认交互 Shell，由 Home Manager 接入 Starship 和 direnv；Bash 保留供脚本运行。
Starship 个人外观通过可写的 `~/.config/starship.toml` 调整，未创建配置时使用默认值。
fish 个人函数放在 `~/.config/fish/functions/`，个人启动设置放在
`~/.config/fish/conf.d/`，不编辑 Home Manager 生成的 `config.fish`。
进入工作区时 direnv 自动加载根 flake 开发环境；手动进入时用 `nix develop --command fish`。

Firefox 使用锁定 nixpkgs 提供的 `pkgs.firefox` 普通版，通过应用菜单或
`firefox` 启动；浏览器个人设置、扩展和资料由 Firefox 管理。

SPlayer-Next 统一播放网易云音乐、QQ 音乐和本地音乐。`pkgs/splayer-next.nix`
固定官方 Linux 安装包和校验哈希，通过应用菜单或 `SPlayer-Next` 启动。
账号登录、歌单、音质和缓存设置由应用管理；更新后需在应用中核对实际播放音质。

KMail 通过应用菜单或 `kmail` 启动，Home Manager 同时安装 Akonadi、邮件资源和账户向导。
邮箱账户、邮件、索引和阅读偏好由应用管理，系统切换不覆盖这些数据。

AyuGram 和 Ghostty 使用安装包提供的桌面入口与 D-Bus 激活服务。
Fcitx5 的输入法分组、默认输入法和外观通过配置界面调整，分别保存在
`~/.config/fcitx5/profile` 和 `~/.config/fcitx5/conf/classicui.conf`；系统只安装
输入法及插件，由 KWin 启动 Fcitx5 并提供 Wayland 输入法连接，禁用独立桌面自启动。
启动入口在系统 `kwinrc` 中固定，个人输入法偏好仍由 Fcitx5 管理。
调整启动入口并切换系统后，停止旧的独立 Fcitx5 实例，再通过
`org.kde.kconfig.notify.ConfigChanged` 通知 KWin 重读 `kwinrc` 的
`Wayland/InputMethod`；普通 `reconfigure` 不会刷新该入口。
通过 KWin 启动后，使用 KWin 管理输入法进程，避免从托盘单独重启而丢失输入法连接。

Rime 的个人方案选择、候选页大小和快捷键在
`~/.local/share/fcitx5/rime/*.custom.yaml` 中维护。方案和词库随系统安装，个人配置、
学习数据和部署结果保存在用户目录。

## 字体

`hosts/desktop.nix` 显式管理字体包及默认字体，关闭 NixOS 默认字体包，并替换
Plasma 附加的字体列表。正文和界面使用 Noto Sans，衬线正文使用 Noto Serif，
中文分别由对应的 Noto CJK 字体补齐；等宽内容使用 Maple Mono NF CN，表情使用
Noto Color Emoji。保留 Noto 的多语言、数学和符号覆盖，以及 Liberation 的文档兼容字体。
CJK 使用上游静态字体集，避免 Chromium 将可变字体集的 face/instance 索引误读为细体或其他地区字形。

KDE 的个人字体选择通过系统设置调整，保存在 `~/.config/kdeglobals`；个人字体
渲染设置保存在 `~/.config/fontconfig/fonts.conf`。Home Manager 的用户 Fontconfig
模块关闭，系统切换不会生成或覆盖这些文件。应用字体偏好由应用管理，网页仍可使用自身字体。

## 微信

微信使用锁定 nixpkgs 提供的安装包和下载来源元数据。`pkgs/wechat.nix` 封装微信专用
输入法依赖，Qt 插件目录从依赖包读取；应用菜单和 `wechat` 命令使用同一个入口。

## LAPLACE Persona

`pkgs/laplace-persona.nix` 固定官方 Linux 安装包和校验哈希，由 Home Manager
安装。运行 `laplace-persona` 或使用应用菜单入口；随包提供的 Electron
在 Wayland 会话中原生运行，不强制指定显示后端。设置、场景和登录信息由应用保存在
`~/.laplace/persona/`，系统切换不覆盖这些数据。

包使用 nixpkgs 的 Vulkan loader 发现系统显卡驱动，并通过 ANGLE/Vulkan
启用 Linux WebGPU；启动参数与运行库统一维护在包定义中。

版本及安装包校验值从官方 `https://downloads.vrp.moe/persona/latest-linux.yml`
核对。下载站若要求浏览器验证，用浏览器下载包定义中对应的 `.deb`，执行
`nix-store --add-fixed sha512 <安装包路径>` 导入后再构建；构建仍校验固定哈希。

## Mihomo

官方 NixOS 模块使用 nixpkgs 提供的 Mihomo 包运行代理。配置为
`/etc/mihomo/config.yaml`，仅 root 可读，通过
systemd credential 加载。新机器首次启用前需准备配置。在 infra 工作区运行：

```sh
infra mihomo apply
```

该命令渲染 fleet 策略并调用本机
`mihomo-update`。systemd 在启动阶段最多等待 30 秒，确认控制器、TUN 开关和代理加载就绪；
控制器先于配置加载启动，首次响应时 TUN 可能尚未开启。
安装器校验配置并等待服务启动；代理组选择由 Mihomo 的 `profile.store-selected` 持久化。
启动失败时恢复旧配置；内容相同且服务就绪时跳过重启，否则校验配置后重新启动。
更新策略无需重建桌面。便携导出见 fleet 的 `services/mihomo/README.md`，生成的
YAML 含凭据。
