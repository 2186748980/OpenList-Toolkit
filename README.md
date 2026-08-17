# OpenList Toolkit

一个轻量、中文友好的 **OpenList 管理工具**，专为 Linux 与 Android / Termux 环境设计。

它把 OpenList 的安装、更新、启动、状态查看、日志、备份，以及常用扩展功能集中到一个简单的命令行菜单中，让你在手机或服务器上也能轻松管理 OpenList。

> 本项目是社区工具，与 [OpenList 官方团队](https://github.com/OpenListTeam/OpenList) 无隶属关系。

## ✨ 功能特性

### OpenList 管理

- 一键安装 OpenList
- 自动获取 OpenList 最新版本
- 一键更新 OpenList
- 启动 / 停止 / 重启
- 查看运行状态
- 查看 OpenList 日志
- OpenList 数据备份与还原
- 支持非交互命令模式

### 🌐 网络访问检测

Toolkit 会自动识别当前设备可用于局域网访问的 IPv4 地址，并根据网络接口显示访问方式：

- 本机访问：`127.0.0.1`
- 手机热点：自动识别 `ap*`
- Wi-Fi：自动识别 `wlan*`
- 其他局域网接口：自动显示
- 自动排除 VPN `tun*` 和移动数据 `ccmni*` 等不适合作为局域网访问地址的接口

例如手机开启热点后，电脑连接手机热点，可以直接看到：

```text
本机访问：http://127.0.0.1:5244
热点访问：http://10.158.167.108:5244
```

无需每次手动执行 `ifconfig` 查找热点 IP。

### 📦 扩展功能

- aria2 RPC 管理
- aria2 BT Tracker 更新
- Cloudflare Tunnel 外网访问
- Cloudflare Tunnel 日志查看
- OpenList 每日自动更新
- Termux / Android 环境适配
- Linux systemd 服务管理

## 🚀 一键运行

无需提前下载项目，直接运行：

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh | bash
```

也可以下载后运行：

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh -o openlist.sh
chmod +x openlist.sh
./openlist.sh
```

## 📱 Termux / Android

推荐在 Termux 中运行：

```bash
pkg update
pkg install curl wget tar
```

然后运行 Toolkit：

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh | bash
```

OpenList 会自动根据设备架构选择对应版本，目前支持：

- AMD64 / x86_64
- ARM64 / aarch64
- ARMv7
- ARMv6
- 386 / i386

## 🖥️ Linux

支持常见 Linux 环境，并在检测到 systemd 且具备相应权限时自动配置 OpenList systemd 服务。

直接运行：

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh | bash
```

## 📋 非交互模式

适合脚本、自动化或远程管理：

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

## 🔌 默认端口

OpenList 默认监听：

```text
5244
```

本机访问：

```text
http://127.0.0.1:5244
```

如果手机开启热点并让电脑连接热点，可以在 Toolkit 的状态信息中直接获取热点访问地址：

```text
热点访问：http://手机热点IP:5244
```

## 📁 数据目录

默认安装目录：

```text
~/.openlist/
├── bin/        # OpenList 可执行文件
├── data/       # OpenList 数据
├── config/     # Toolkit 配置目录
├── logs/       # OpenList 日志
├── version     # 当前 OpenList 版本
├── latest-version
└── openlist.pid
```

可以通过 `OPENLIST_HOME` 自定义 OpenList 安装目录：

```bash
OPENLIST_HOME=/opt/openlist bash openlist.sh
```

## 💾 备份

Toolkit 会使用独立的备份目录保存 OpenList 数据：

```text
~/OpenList-Backups/
```

可以通过主菜单中的备份功能进行备份与还原。

## ☁️ Cloudflare Tunnel

Toolkit 集成 Cloudflare Tunnel 管理，可以在主菜单的「更多功能」中开启或停止 OpenList 外网访问，并查看 Tunnel 日志。

适合不方便进行端口转发的设备或服务器环境。

## ⚡ aria2

Toolkit 可以自动安装并管理 aria2，并提供：

- aria2 RPC
- RPC 密钥配置
- aria2 启动 / 停止
- BT Tracker 更新
- aria2 日志查看

相关配置默认位于：

```text
~/aria2/
├── aria2.conf
├── aria2.log
└── aria2.pid
```

## 🔄 自动更新

Toolkit 支持每日自动更新 OpenList，可在「更多功能」中开启或关闭。

在 Android / Termux 环境中，可配合 **Termux:Boot** 使用；Linux 环境则根据系统能力使用相应的服务机制。

## 🛠️ 主菜单

启动 Toolkit 后，可以通过菜单完成常用操作：

```text
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
```

「更多功能」包含密码修改、配置编辑、aria2、Cloudflare Tunnel、备份还原和自动更新等功能。

## 🔐 安全说明

- 默认只提供本机 / 局域网访问能力，不会自动开放公网端口。
- 使用 Cloudflare Tunnel 或其他公网访问方式时，请务必设置强密码。
- aria2 RPC 建议使用独立且复杂的 RPC 密钥。
- 不建议在不受信任的公共网络中直接暴露 OpenList 管理界面。

## 📌 当前版本

```text
OpenList Toolkit：v0.5.1
```

## 📄 License

本项目采用仓库中声明的许可证（如有）。

如果你觉得这个项目有用，欢迎 Star、Issue 或提交 Pull Request。
