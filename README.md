# OpenList Toolkit

一个轻量、中文友好的 OpenList 管理工具，目标是让 OpenList 在 Linux 服务器和 Termux 上更容易安装、更新和维护。

## 当前功能

- 一键安装 OpenList
- 更新 OpenList
- 启动 / 停止 / 重启
- 查看运行状态
- 查看最近日志
- 卸载
- 自动识别 Linux / Termux
- 自动识别 AMD64 / ARM64 / ARMv7 / ARMv6 / 386

## 一键运行

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh | bash
```

也可以下载后运行：

```bash
curl -fsSL https://raw.githubusercontent.com/2186748980/OpenList-Toolkit/main/openlist.sh -o openlist
chmod +x openlist
./openlist
```

## 安装目录

默认安装到：

```text
~/.openlist/
├── bin/        # OpenList 程序
├── data/       # OpenList 数据目录
├── config/     # Toolkit 配置预留目录
├── logs/       # 日志
├── version     # 当前版本
└── openlist.pid
```

可以通过 `OPENLIST_HOME` 修改目录：

```bash
OPENLIST_HOME=/opt/openlist bash openlist.sh
```

## 非交互模式

```bash
./openlist.sh --install
./openlist.sh --start
./openlist.sh --stop
./openlist.sh --restart
./openlist.sh --status
```

## 注意

这是项目的早期版本。服务管理目前采用轻量 PID + nohup 方式，后续会增加 systemd、Docker、配置备份、端口检测以及更完善的升级回滚机制。

本项目为社区工具，与 OpenList 官方团队无隶属关系。
