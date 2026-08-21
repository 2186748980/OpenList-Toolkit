# OpenList Toolkit

一个轻量、中文友好的 **OpenList 管理工具**，面向 Linux 与 Android / Termux 环境。

OpenList Toolkit 把 OpenList、aria2、AriaNg、Cloudflare Tunnel、网络访问、二维码、备份、自启动与异常恢复等常用能力集中到一个交互式命令行工具中。

> 本项目是社区工具，与 [OpenList 官方团队](https://github.com/OpenListTeam/OpenList) 无隶属关系。

## ✨ 主要特性

### OpenList

- 自动识别操作系统与 CPU 架构
- 自动获取 OpenList 官方最新 Release
- 一键安装 / 更新 OpenList
- 启动 / 停止 / 重启
- 状态检查
- 日志查看
- 数据备份
- 支持非交互命令模式
- Linux 检测到 systemd 时可创建并启用 systemd 服务
- 已安装 OpenList 时，选择“安装”会先确认，避免误操作重复安装
- 重新安装时只处理 OpenList，不会默认停止 aria2 / AriaNg

### 🔄 Toolkit 自更新（3.1）

Toolkit 3.1 不再依赖 `TOOLKIT_VERSION` 或固定版本号判断 Toolkit 是否更新。

现在直接对 GitHub `main` 分支的 `openlist.sh` 与本地 `openlist.sh` 计算 **SHA-256**：

```text
本地 openlist.sh ── SHA-256 ──┐
                              ├─ 比较
GitHub main/openlist.sh ──────┘
```

两者完全一致时，Toolkit 已是最新；不一致时会提示是否同步 GitHub `main` 的最新代码。

支持：

```bash
./openlist.sh --self-update
./openlist.sh --update-toolkit
```

菜单中的 Toolkit 自更新同样使用这套机制。

Toolkit 会记录最近一次同步的远程 SHA-256。如果发现本地代码在同步后被手动修改，自动同步会跳过，以避免直接覆盖用户自己的改动。

更新完成后需要重新运行 `oplist` / `./openlist.sh`，使新代码重新加载。

### 🌐 网络访问

Toolkit 会自动检测可用 IPv4，并将网络接口转换成更直观的访问地址：

- 本机：`127.0.0.1:5244`
- Android 热点：识别 `ap*`
- Wi-Fi：识别 `wlan*`
- 其他局域网接口：显示为局域网地址
- 自动排除 `tun*`、`ccmni*`、回环地址和链路本地地址

例如：

```text
本机访问：http://127.0.0.1:5244
热点访问：http://10.x.x.x:5244
```

### 📱 二维码访问

Toolkit 可以直接在终端生成 OpenList 局域网访问二维码。

优先使用 `qrencode`；如果 Termux 软件源没有 `qrencode`，则自动使用 Python `qrcode` 模块生成终端二维码。

### ⚡ aria2

Toolkit 内置 aria2 管理：

- 启动 / 停止 / 重启 aria2
- 查看状态与日志
- 编辑 aria2 配置
- 更新 BT Tracker
- RPC 地址：`http://127.0.0.1:6800`
- RPC 密钥独立保存

默认目录：

```text
~/aria2/
├── aria2.conf
├── aria2.log
├── aria2.pid
└── ariang/
```

### 🖥️ AriaNg Web 管理

Toolkit 可以安装、更新和启动 AriaNg，为 aria2 提供浏览器 WebUI。

默认地址：

```text
http://127.0.0.1:6880
```

AriaNg 是 WebUI，不是 aria2 服务；需要先运行 aria2，AriaNg 才能连接 RPC。

### ☁️ Cloudflare Tunnel

Toolkit 支持 Cloudflare Tunnel，用于在没有端口转发的情况下为 OpenList 提供外网访问入口。

相关信息默认保存于：

```text
~/.cloudflared/
├── cert.pem
├── config.yml
├── tunnel.log
├── tunnel.name
└── domain
```

### 🔗 OpenList / aria2 / AriaNg 停止联动

选择主菜单的：

```text
4. 停止 OpenList
```

OpenList 停止后会询问：

```text
是否同步停止 aria2 和 AriaNg？(y/n)：
```

- `y` / `Y`：同步停止 aria2 和 AriaNg
- `n` / `N`：保留 aria2 和 AriaNg 继续运行
- 直接按 Enter：默认保留 aria2 和 AriaNg 运行
- 其他输入：同样保留 aria2 和 AriaNg 运行

这样可以避免仅仅停止 OpenList 时误把下载服务一起停止。

### 🔁 Termux 开机自启 + 异常恢复

在 Android / Termux 环境中，Toolkit 可以创建 Termux:Boot 启动脚本，并通过 watchdog 检查 OpenList 是否异常退出。

## 🚀 快速开始

### 方式一：直接运行

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh | bash
```

### 方式二：下载后运行

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh -o openlist.sh
chmod +x openlist.sh
./openlist.sh
```

## 📱 Android / Termux

建议先安装基础依赖：

```bash
pkg update
pkg install curl wget tar git
```

然后运行 Toolkit：

```bash
./openlist.sh
```

首次使用 Termux 时，如果需要访问共享存储，可以执行：

```bash
termux-setup-storage
```

Toolkit 会根据 `uname -m` 自动识别架构，目前支持：

- `amd64` / x86_64
- `arm64` / aarch64
- `arm-7`
- `arm-6`
- `386` / i386

Android / Termux 会自动使用 OpenList 对应安装包。

## 🖥️ Linux

Linux 环境同样使用统一脚本。

如果系统存在 systemd 且当前用户具备 root 权限，Toolkit 会创建：

```text
/etc/systemd/system/openlist-toolkit.service
```

没有 systemd 时，则使用 PID 文件管理 OpenList。

## 🛠️ 主菜单

当前主菜单结构：

```text
=======================================================
                   OpenList Toolkit
                    Toolkit：xxxxxxxx
=======================================================
系统：android   架构：arm64
OpenList：v4.x.x → 最新 v4.x.x
OpenList 状态：运行中 / 未运行
aria2 状态：运行中 / 未运行
AriaNg 状态：运行中 / 未运行
Cloudflare Tunnel 状态：运行中 / 未运行
本机访问：http://127.0.0.1:5244
=======================================================
1. 安装 OpenList
2. 更新 OpenList
3. 启动 OpenList
4. 停止 OpenList
5. 重启 OpenList
6. 查看 OpenList 日志
7. 备份数据
8. aria2 管理
9. 更多功能
0. 退出
=======================================================
```

Toolkit 标识使用当前 `openlist.sh` SHA-256 的前 7 位生成，不再使用固定 Toolkit 版本号。

### 更多功能

更多功能用于放置不需要频繁操作的扩展能力，例如：

- 环境与依赖检查
- OpenList 配置相关操作
- 备份 / 还原
- Cloudflare Tunnel
- 自动更新相关设置
- aria2 管理
- AriaNg 管理
- 二维码访问
- Termux 开机自启与 watchdog

## ⚡ aria2 管理菜单

进入 aria2 管理后，可以使用：

```text
=======================================================
                       aria2 管理
=======================================================
aria2 状态：运行中 / 未运行
RPC 服务：http://127.0.0.1:6800
Web 管理：AriaNg 运行中 / 未运行
=======================================================
1. 启动 aria2
2. 停止 aria2
3. 启动 AriaNg
4. 停止 AriaNg
5. 同时启动
6. 同时停止
0. 返回
=======================================================
```

### aria2 RPC

RPC 默认监听：

```text
127.0.0.1:6800
```

RPC 密钥文件：

```text
~/.aria2_secret
```

不要将 RPC 密钥提交到 GitHub 或其他公开位置。

### AriaNg

AriaNg 默认监听：

```text
127.0.0.1:6880
```

正常安装后，在浏览器访问：

```text
http://127.0.0.1:6880
```

## 📋 命令行模式

Toolkit 支持常用非交互操作：

```bash
./openlist.sh --install
./openlist.sh --update
./openlist.sh --start
./openlist.sh --stop
./openlist.sh --restart
./openlist.sh --status
./openlist.sh --logs
./openlist.sh --backup
./openlist.sh --self-update
./openlist.sh --update-toolkit
```

如果安装过程中生成了快捷命令，也可以使用：

```bash
oplist --status
```

## 📁 目录结构

### OpenList

默认：

```text
~/.openlist/
├── bin/
│   └── openlist
├── data/
├── logs/
├── version
├── latest-version
├── .toolkit-synced-hash
└── openlist.pid
```

也可以通过环境变量修改 OpenList 根目录：

```bash
OPENLIST_HOME=/opt/openlist ./openlist.sh
```

### aria2 / AriaNg

```text
~/aria2/
├── aria2.conf
├── aria2.log
├── aria2.pid
├── ariang/
│   ├── index.html
│   └── version
└── ariang.pid
```

### Cloudflare

```text
~/.cloudflared/
├── cert.pem
├── config.yml
├── tunnel.log
├── tunnel.name
└── domain
```

### 备份

```text
~/OpenList-Backups/
```

## 💾 备份

Toolkit 使用独立目录保存 OpenList 备份：

```text
~/OpenList-Backups/
```

## 🔐 安全建议

- 不要把 `~/.aria2_secret` 提交到 GitHub。
- 不要把 `~/.cloudflared/cert.pem` 或 Tunnel credentials JSON 上传到仓库。
- Cloudflare Tunnel 对外开放后，请使用强密码保护 OpenList。
- aria2 RPC 不建议直接暴露到公网。
- GitHub Token 如有配置，应保存在本机的 `~/.github_token`，不要写入脚本。

## 🧩 依赖检查

Toolkit 会检查基础能力，包括：

- `curl`
- `tar`
- `ifconfig`
- `pgrep`
- Termux 存储权限（Android / Termux）
- OpenList 是否已经安装

缺少可选组件时，Toolkit 会根据功能给出提示。

二维码功能在没有 `qrencode` 的 Termux 环境中可以回退到 Python `qrcode` 实现。

## 📝 当前版本

```text
OpenList Toolkit：3.1
更新机制：GitHub main/openlist.sh SHA-256
```

Toolkit 不再使用固定的 `TOOLKIT_VERSION` 判断自身是否更新。

## 📄 License

本项目采用仓库中声明的许可证（如有）。

如果这个项目对你有帮助，欢迎 Star、Issue 或提交 Pull Request。
