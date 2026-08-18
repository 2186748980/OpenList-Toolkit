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

这样在手机终端中可以直接把二维码交给另一台设备扫描访问 OpenList，而不需要手动输入 IP 地址。

### ⚡ aria2

Toolkit 内置 aria2 管理，集中处理下载服务：

- 启动 aria2
- 停止 aria2
- 重启 aria2
- 查看 aria2 状态
- 查看 aria2 日志
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

Toolkit 可以在 aria2 管理中安装、更新和启动 AriaNg，为 aria2 提供浏览器 WebUI。

AriaNg 默认由 Toolkit 在本地端口运行：

```text
http://127.0.0.1:6880
```

功能包括：

- 安装 / 更新 AriaNg
- 启动 / 停止 AriaNg
- 查看 AriaNg 日志
- 通过浏览器管理 aria2 下载任务
- 与本机 `6800` RPC 服务配合使用

AriaNg 更新逻辑会尝试检测 `mayswind/AriaNg` 的最新 Release，并生成对应的 `AriaNg-版本-AllInOne.zip` 下载地址；如果无法检测最新版本，则保留稳定版本作为兜底。

**注意：** AriaNg 是 WebUI，本身不是 aria2 服务。需要先运行 aria2，AriaNg 才能连接 RPC。

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

通过 Toolkit 配置 Tunnel 时，可以完成登录授权、创建 Tunnel、绑定域名以及启动 / 停止 Tunnel。

例如可以将：

```text
http://127.0.0.1:5244
```

映射到你自己的 Cloudflare 域名。

### 🔄 自动版本检测

Toolkit 会检测 OpenList 上游最新版本，并使用本地缓存减少重复请求。

版本检测缓存默认有效约 60 分钟，因此启动菜单时不会每次都重复请求 GitHub API。

### 🔁 Termux 开机自启 + 异常恢复

在 Android / Termux 环境中，Toolkit 可以创建 Termux:Boot 启动脚本：

1. 系统启动后等待一段时间
2. 自动启动 OpenList
3. 启动 watchdog
4. watchdog 周期性检查 OpenList
5. 如果 OpenList 异常退出，则尝试自动恢复

需要安装 **Termux:Boot**，并允许 Termux 后台运行及系统自启动。

关闭自启后，Toolkit 会同时移除 watchdog 和相关状态文件。

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

Android / Termux 会自动使用 OpenList 的 Android 对应安装包。

## 🖥️ Linux

Linux 环境同样使用统一脚本。

如果系统存在 systemd 且当前用户具备 root 权限，Toolkit 会创建：

```text
/etc/systemd/system/openlist-toolkit.service
```

服务具备失败自动重启能力，并设置为随系统启动。

没有 systemd 时，则使用 PID 文件管理 OpenList。

## 🛠️ 主菜单

当前主菜单结构：

```text
=======================================================
                   OpenList Toolkit
=======================================================
系统：android   架构：arm64
OpenList：v4.x.x → 最新 v4.x.x
状态：运行中
本机访问：http://127.0.0.1:5244
热点/Wi-Fi访问：http://192.168.x.x:5244
=======================================================
1. 安装 OpenList
2. 更新 OpenList
3. 启动 OpenList
4. 停止 OpenList
5. 重启 OpenList
6. 查看状态
7. 查看 OpenList 日志
8. 备份数据
9. 更多功能
0. 退出
=======================================================
```

主界面会根据当前运行情况显示 OpenList 状态和网络访问地址。

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
3. 重启 aria2
4. 查看 aria2 状态
5. 查看 aria2 日志
6. 编辑 aria2 配置文件
7. 更新 aria2 BT Tracker
8. 安装/更新并启动 AriaNg
9. 停止 AriaNg
10. 查看 AriaNg 日志
0. 返回主菜单
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

安装 / 更新入口为：

```text
8. 安装/更新并启动 AriaNg
```

正常安装后，在浏览器访问：

```text
http://127.0.0.1:6880
```

如果需要从局域网其他设备访问，需要将 `6880` 对应的地址改为运行 Toolkit 设备的局域网 IP，并确保网络环境允许访问该端口。

## ☁️ Cloudflare Tunnel 使用流程

Cloudflare Tunnel 需要先完成 Cloudflare 登录授权。

典型流程：

```text
1. 登录 Cloudflare
2. 选择要授权的 Zone
3. 创建 Tunnel
4. 输入 Tunnel 名称
5. 输入绑定域名
6. Toolkit 启动 cloudflared
7. 使用绑定域名访问 OpenList
```

Tunnel 凭据由 cloudflared 保存到用户目录，**不要上传到 GitHub**。

## 📋 命令行模式

Toolkit 支持部分常用非交互操作：

```bash
./openlist.sh --install
./openlist.sh --update
./openlist.sh --start
./openlist.sh --stop
./openlist.sh --restart
./openlist.sh --status
./openlist.sh --logs
./openlist.sh --backup
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

备份功能用于保存 OpenList 数据，避免更新或调整配置时丢失重要内容。

## 🔐 安全建议

- 不要把 `~/.aria2_secret` 提交到 GitHub。
- 不要把 `~/.cloudflared/cert.pem` 或 Tunnel credentials JSON 上传到仓库。
- Cloudflare Tunnel 对外开放后，请使用强密码保护 OpenList。
- aria2 RPC 不建议直接暴露到公网。
- 局域网访问也应建立在可信网络环境中。
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
OpenList Toolkit：v0.6.1
```

脚本中的 Toolkit 版本号与 README 保持同步。

## 📄 License

本项目采用仓库中声明的许可证（如有）。

如果这个项目对你有帮助，欢迎 Star、Issue 或提交 Pull Request。
