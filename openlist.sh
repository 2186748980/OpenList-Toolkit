#!/usr/bin/env bash
set -u
TOOLKIT_VERSION="0.4.1"
REPO="2186748980/OpenList-Toolkit"
UPSTREAM="OpenListTeam/OpenList"
HOME_DIR="${OPENLIST_HOME:-$HOME/.openlist}"
BIN_DIR="$HOME_DIR/bin"; DATA_DIR="$HOME_DIR/data"; LOG_DIR="$HOME_DIR/logs"
BINARY="$BIN_DIR/openlist"; PID_FILE="$HOME_DIR/openlist.pid"; VERSION_FILE="$HOME_DIR/version"
SHORTCUT="$HOME/.local/bin/oplist"
SERVICE="openlist-toolkit.service"; SERVICE_FILE="/etc/systemd/system/$SERVICE"
TIMER="openlist-toolkit-update.timer"; TIMER_FILE="/etc/systemd/system/$TIMER"
UPDATE_SERVICE="openlist-toolkit-update.service"; UPDATE_SERVICE_FILE="/etc/systemd/system/$UPDATE_SERVICE"
R='\033[0m'; CY='\033[1;36m'; GR='\033[1;32m'; YE='\033[1;33m'; RE='\033[1;31m'; MA='\033[1;35m'; BL='\033[1;34m'
info(){ echo -e "${CY}[INFO]${R} $*"; }; ok(){ echo -e "${GR}[ OK ]${R} $*"; }; warn(){ echo -e "${YE}[WARN]${R} $*"; }; err(){ echo -e "${RE}[ERR ]${R} $*"; }
has(){ command -v "$1" >/dev/null 2>&1; }
arch(){ case "$(uname -m)" in x86_64|amd64) echo amd64;; aarch64|arm64) echo arm64;; armv7l|armv7) echo arm-7;; armv6l|armv6) echo arm-6;; i386|i686) echo 386;; *) echo unsupported;; esac; }
os_name(){ if [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *com.termux* ]]; then echo android; elif [ -f /etc/os-release ]; then . /etc/os-release; echo "${ID:-linux}"; else echo linux; fi; }
is_termux(){ [ "$(os_name)" = android ]; }; root(){ [ "$(id -u)" -eq 0 ]; }; systemd(){ has systemctl && [ -d /run/systemd/system ]; }
mkdirs(){ mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOG_DIR"; }
upstream_version(){ local j=""; if has curl; then j="$(curl -fsSL --retry 3 --connect-timeout 10 "https://api.github.com/repos/$UPSTREAM/releases/latest" 2>/dev/null || true)"; elif has wget; then j="$(wget -qO- --timeout=10 "https://api.github.com/repos/$UPSTREAM/releases/latest" 2>/dev/null || true)"; fi; printf '%s\n' "$j" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1; }
toolkit_version(){ local s=""; if has curl; then s="$(curl -fsSL --retry 2 --connect-timeout 10 "https://raw.githubusercontent.com/$REPO/main/openlist.sh" 2>/dev/null || true)"; elif has wget; then s="$(wget -qO- --timeout=10 "https://raw.githubusercontent.com/$REPO/main/openlist.sh" 2>/dev/null || true)"; fi; printf '%s\n' "$s" | sed -n 's/^TOOLKIT_VERSION="\([^"]*\)"/\1/p' | head -n1; }
running(){ if systemd && [ -f "$SERVICE_FILE" ]; then systemctl is-active --quiet "$SERVICE"; return $?; fi; [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; }
install_service(){ systemd && root || return 0; cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=OpenList managed by OpenList Toolkit
After=network.target
[Service]
Type=simple
WorkingDirectory=$DATA_DIR
ExecStart=$BINARY server --data $DATA_DIR
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null 2>&1 || true; }
start(){ mkdirs; [ -x "$BINARY" ] || { err "OpenList 尚未安装，请先选择 1。"; return 1; }; if systemd && [ -f "$SERVICE_FILE" ]; then systemctl start "$SERVICE" && ok "OpenList 已启动。" || err "启动失败，请查看日志。"; return; fi; running && { warn "OpenList 已经在运行。"; return 0; }; nohup "$BINARY" server --data "$DATA_DIR" >"$LOG_DIR/openlist.log" 2>&1 & local p=$!; echo "$p" > "$PID_FILE"; sleep 1; running && ok "OpenList 已启动，PID: $p" || { err "启动失败，请查看日志。"; rm -f "$PID_FILE"; return 1; }; }
stop(){ if systemd && [ -f "$SERVICE_FILE" ]; then systemctl stop "$SERVICE" && ok "OpenList 已停止。"; return; fi; if [ -f "$PID_FILE" ]; then local p="$(cat "$PID_FILE" 2>/dev/null || true)"; [ -z "$p" ] || kill "$p" 2>/dev/null || true; sleep 1; [ -z "$p" ] || kill -9 "$p" 2>/dev/null || true; rm -f "$PID_FILE"; fi; warn "OpenList 已停止或原本未运行。"; }
install_openlist(){ mkdirs; local a o v target asset url tmp file; a="$(arch)"; o="$(os_name)"; [ "$a" != unsupported ] || { err "不支持的 CPU：$(uname -m)"; return 1; }; target=linux; [ "$o" = android ] && target=android; v="$(upstream_version)"; [ -n "$v" ] || { err "无法获取 OpenList 最新版本，请检查网络。"; return 1; }; asset="openlist-${target}-${a}.tar.gz"; url="https://github.com/$UPSTREAM/releases/download/$v/$asset"; tmp="$(mktemp -d)"; info "系统：$o  架构：$a  版本：$v"; if has curl; then curl -fL --retry 3 --connect-timeout 15 "$url" -o "$tmp/openlist.tar.gz" || { err "下载失败"; rm -rf "$tmp"; return 1; }; elif has wget; then wget -q --show-progress "$url" -O "$tmp/openlist.tar.gz" || { err "下载失败"; rm -rf "$tmp"; return 1; }; else err "需要 curl 或 wget。"; rm -rf "$tmp"; return 1; fi; has tar || { err "未找到 tar。"; rm -rf "$tmp"; return 1; }; tar -xzf "$tmp/openlist.tar.gz" -C "$tmp" || { err "解压失败。"; rm -rf "$tmp"; return 1; }; file="$(find "$tmp" -type f -name openlist | head -n1)"; [ -n "$file" ] || { err "安装包中未找到 openlist。"; rm -rf "$tmp"; return 1; }; running && stop; cp "$file" "$BINARY"; chmod +x "$BINARY"; "$BINARY" version >/dev/null 2>&1 || { err "OpenList 可执行文件验证失败。"; rm -f "$BINARY"; rm -rf "$tmp"; return 1; }; echo "$v" > "$VERSION_FILE"; rm -rf "$tmp"; install_service; ok "OpenList $v 安装完成。"; }
update_openlist(){ [ -x "$BINARY" ] || { install_openlist; return; }; local cur="$(cat "$VERSION_FILE" 2>/dev/null || true)"; local latest="$(upstream_version)"; info "当前：${cur:-未知}  最新：${latest:-未知}"; [ -n "$latest" ] || { err "无法获取上游版本。"; return 1; }; [ "$cur" = "$latest" ] && { ok "已经是最新版本。"; return 0; }; warn "发现新版本 $latest，开始更新……"; install_openlist; }
self_update(){ local latest="$(toolkit_version)"; [ -n "$latest" ] || { err "无法获取 Toolkit 最新版本。"; return 1; }; info "当前 Toolkit：v$TOOLKIT_VERSION  最新：v$latest"; [ "$TOOLKIT_VERSION" = "$latest" ] && { ok "Toolkit 已是最新版本。"; return 0; }; local tmp="$(mktemp)"; local src="${BASH_SOURCE[0]}"; local url="https://raw.githubusercontent.com/$REPO/main/openlist.sh"; if has curl; then curl -fsSL --retry 3 "$url" -o "$tmp"; else wget -qO "$tmp" "$url"; fi; [ -s "$tmp" ] || { err "下载 Toolkit 更新失败。"; rm -f "$tmp"; return 1; }; chmod +x "$tmp"; mv "$tmp" "$src"; [ "$src" = "$SHORTCUT" ] || { cp "$src" "$SHORTCUT" 2>/dev/null || true; chmod +x "$SHORTCUT" 2>/dev/null || true; }; ok "Toolkit 已更新为 v$latest，请重新运行 oplist。"; }
shortcut(){ mkdir -p "$(dirname "$SHORTCUT")"; local src="${BASH_SOURCE[0]}"; [ -f "$src" ] && { cp "$src" "$SHORTCUT"; chmod +x "$SHORTCUT"; ok "已安装全局命令：oplist"; } || warn "无法定位脚本文件。"; }
setup_timer(){ if ! systemd || ! root; then warn "当前环境不是 root + systemd。"; is_termux && info "Termux 可配合 Termux:Boot/定时任务调用：oplist --update"; return 0; fi; cat > "$HOME_DIR/nightly-update.sh" <<EOF
#!/usr/bin/env bash
"$SHORTCUT" --update >/dev/null 2>&1 || true
EOF
chmod +x "$HOME_DIR/nightly-update.sh"; cat > "$UPDATE_SERVICE_FILE" <<EOF
[Unit]
Description=OpenList Toolkit nightly update
After=network-online.target
[Service]
Type=oneshot
ExecStart=$HOME_DIR/nightly-update.sh
EOF
cat > "$TIMER_FILE" <<EOF
[Unit]
Description=OpenList Toolkit nightly update timer
[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=15m
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload; systemctl enable --now "$TIMER" >/dev/null 2>&1 || true; ok "已开启每日凌晨自动检查更新（03:30，随机延迟最多 15 分钟）。"; }
remove_timer(){ systemd && root || { warn "当前环境没有可管理的 systemd 定时任务。"; return; }; systemctl disable --now "$TIMER" >/dev/null 2>&1 || true; rm -f "$TIMER_FILE" "$UPDATE_SERVICE_FILE" "$HOME_DIR/nightly-update.sh"; systemctl daemon-reload; ok "已关闭每日自动更新。"; }
status(){ echo -e "${MA}OpenList Toolkit${R}：v$TOOLKIT_VERSION"; echo "系统：$(os_name)"; echo "架构：$(arch)"; echo "安装目录：$HOME_DIR"; echo "版本：$(cat "$VERSION_FILE" 2>/dev/null || echo 未安装)"; running && echo -e "状态：${GR}运行中${R}" || echo -e "状态：${RE}未运行${R}"; systemd && [ -f "$SERVICE_FILE" ] && echo "管理方式：systemd"; echo; }
logs(){ if systemd && [ -f "$SERVICE_FILE" ]; then journalctl -u "$SERVICE" -n 100 --no-pager; elif [ -f "$LOG_DIR/openlist.log" ]; then tail -n 100 "$LOG_DIR/openlist.log"; else warn "暂无日志。"; fi; }
backup(){ mkdirs; local out="$HOME/openlist-backup-$(date +%Y%m%d-%H%M%S).tar.gz"; tar -czf "$out" -C "$DATA_DIR" . && ok "备份完成：$out" || err "备份失败。"; }
uninstall(){ read -r -p "确认卸载？输入 YES：" c; [ "$c" = YES ] || { warn "已取消。"; return; }; if systemd && root; then systemctl disable --now "$SERVICE" >/dev/null 2>&1 || true; rm -f "$SERVICE_FILE"; systemctl daemon-reload; fi; rm -rf "$HOME_DIR"; ok "OpenList 已卸载。"; }
more(){ while true; do clear; echo -e "${BL}============= 更多功能 =============${R}"; echo "1. 检查/更新 Toolkit"; echo "2. 开启每日自动更新"; echo "3. 关闭每日自动更新"; echo "4. 安装 oplist 全局命令"; echo "5. 查看 OpenList 日志"; echo "0. 返回主菜单"; printf '请输入选项 (0-5)：'; read -r c; case "$c" in 1) self_update;; 2) setup_timer;; 3) remove_timer;; 4) shortcut;; 5) logs;; 0) break;; *) warn "无效选项。";; esac; echo; read -r -p '按 Enter 返回菜单……' _; done; }
menu(){ while true; do clear; local cur="$(cat "$VERSION_FILE" 2>/dev/null || true)"; local latest="$(upstream_version 2>/dev/null || true)"; echo -e "${BL}╔══════════════════════════════════════╗${R}"; echo -e "${BL}║${MA}          OpenList Toolkit            ${BL}║${R}"; printf '%b║%b              v%-18s%b║%b\n' "$BL" "$R" "$TOOLKIT_VERSION" "$BL" "$R"; echo -e "${BL}╠══════════════════════════════════════╣${R}"; echo -e "${CY}系统${R}：$(os_name)   ${CY}架构${R}：$(arch)"; echo -e "${CY}OpenList${R}：${cur:-未安装} → 最新 ${latest:-未知}"; running && echo -e "${CY}状态${R}：${GR}运行中${R}" || echo -e "${CY}状态${R}：${RE}未运行${R}"; echo -e "${BL}╠══════════════════════════════════════╣${R}"; echo "1. 安装 OpenList"; echo "2. 更新 OpenList"; echo "3. 启动 OpenList"; echo "4. 停止 OpenList"; echo "5. 重启 OpenList"; echo "6. 查看状态"; echo "7. 查看日志"; echo "8. 备份数据"; echo "9. 更多功能"; echo "0. 退出"; echo -e "${BL}╚══════════════════════════════════════╝${R}"; printf '请选择：'; read -r c; echo; case "$c" in 1) install_openlist;; 2) update_openlist;; 3) start;; 4) stop;; 5) stop; start;; 6) status;; 7) logs;; 8) backup;; 9) more;; 0) exit 0;; *) warn "无效选项。";; esac; echo; read -r -p '按 Enter 返回菜单……' _; done; }
case "${1:-}" in --install) install_openlist;; --update) update_openlist;; --start) start;; --stop) stop;; --restart) stop; start;; --status) status;; --logs) logs;; --backup) backup;; --self-update) self_update;; --setup-nightly-update) setup_timer;; --remove-nightly-update) remove_timer;; --install-shortcut) shortcut;; --uninstall) uninstall;; *) shortcut >/dev/null 2>&1 || true; menu;; esac
