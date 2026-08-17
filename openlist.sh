#!/usr/bin/env bash
set -u

# OpenList Toolkit
# https://github.com/2186748980/OpenList-Toolkit
TOOLKIT_VERSION="0.4.0"
REPO="2186748980/OpenList-Toolkit"
UPSTREAM_REPO="OpenListTeam/OpenList"
INSTALL_DIR="${OPENLIST_HOME:-$HOME/.openlist}"
BIN_DIR="$INSTALL_DIR/bin"
DATA_DIR="$INSTALL_DIR/data"
LOG_DIR="$INSTALL_DIR/logs"
BINARY="$BIN_DIR/openlist"
PID_FILE="$INSTALL_DIR/openlist.pid"
VERSION_FILE="$INSTALL_DIR/version"
SYSTEMD_UNIT="openlist-toolkit.service"
SYSTEMD_FILE="/etc/systemd/system/$SYSTEMD_UNIT"
UPDATE_UNIT="openlist-toolkit-update.service"
UPDATE_TIMER="openlist-toolkit-update.timer"
UPDATE_UNIT_FILE="/etc/systemd/system/$UPDATE_UNIT"
UPDATE_TIMER_FILE="/etc/systemd/system/$UPDATE_TIMER"
SHORTCUT="$HOME/.local/bin/oplist"

C_RESET='\033[0m'; C_CYAN='\033[1;36m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[1;31m'; C_MAGENTA='\033[1;35m'; C_BLUE='\033[1;34m'; C_GRAY='\033[1;30m'
info(){ echo -e "${C_CYAN}[INFO]${C_RESET} $*"; }
ok(){ echo -e "${C_GREEN}[ OK ]${C_RESET} $*"; }
warn(){ echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
err(){ echo -e "${C_RED}[ERR ]${C_RESET} $*"; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

get_arch(){
  case "$(uname -m)" in
    x86_64|amd64) echo amd64;; aarch64|arm64) echo arm64;;
    armv7l|armv7) echo arm-7;; armv6l|armv6) echo arm-6;;
    i386|i686) echo 386;; *) echo unsupported;;
  esac
}
get_os(){
  if [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *com.termux* ]]; then echo android;
  elif [ -f /etc/os-release ]; then . /etc/os-release; echo "${ID:-linux}"; else echo linux; fi
}
is_termux(){ [ "$(get_os)" = android ]; }
need_root(){ [ "$(id -u)" -eq 0 ]; }
is_systemd(){ command_exists systemctl && [ -d /run/systemd/system ]; }
ensure_dirs(){ mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOG_DIR"; }

latest_version(){
  local j=""
  if command_exists curl; then j="$(curl -fsSL --retry 3 --connect-timeout 10 "https://api.github.com/repos/$UPSTREAM_REPO/releases/latest" 2>/dev/null || true)";
  elif command_exists wget; then j="$(wget -qO- --timeout=10 "https://api.github.com/repos/$UPSTREAM_REPO/releases/latest" 2>/dev/null || true)"; fi
  printf '%s\n' "$j" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

latest_toolkit_version(){
  local j=""
  if command_exists curl; then j="$(curl -fsSL --retry 2 --connect-timeout 10 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)";
  elif command_exists wget; then j="$(wget -qO- --timeout=10 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)"; fi
  printf '%s\n' "$j" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

is_running(){
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then systemctl is-active --quiet "$SYSTEMD_UNIT"; return $?; fi
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

install_service(){
  if ! is_systemd || ! need_root; then return 0; fi
  cat > "$SYSTEMD_FILE" <<EOF
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
  systemctl daemon-reload
  systemctl enable "$SYSTEMD_UNIT" >/dev/null 2>&1 || true
  ok "已创建 systemd 服务：$SYSTEMD_UNIT"
}

start_openlist(){
  ensure_dirs
  [ -x "$BINARY" ] || { err "OpenList 尚未安装，请先选择 1。"; return 1; }
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then
    systemctl start "$SYSTEMD_UNIT" && ok "OpenList 已启动。" || { err "启动失败，请查看日志。"; return 1; }
    return 0
  fi
  if is_running; then warn "OpenList 已经在运行。"; return 0; fi
  nohup "$BINARY" server --data "$DATA_DIR" >"$LOG_DIR/openlist.log" 2>&1 &
  local pid=$!; echo "$pid" > "$PID_FILE"; sleep 1
  if is_running; then ok "OpenList 已启动，PID: $pid"; else err "启动失败，请查看日志。"; rm -f "$PID_FILE"; return 1; fi
}

stop_openlist(){
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then
    systemctl stop "$SYSTEMD_UNIT" && ok "OpenList 已停止。" || { err "停止失败。"; return 1; }
    return 0
  fi
  if [ -f "$PID_FILE" ]; then
    local p; p="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then kill "$p" 2>/dev/null || true; sleep 1; kill -9 "$p" 2>/dev/null || true; fi
    rm -f "$PID_FILE"
  fi
  warn "OpenList 已停止或原本未运行。"
}

restart_openlist(){ stop_openlist; start_openlist; }

install_openlist(){
  ensure_dirs
  local arch os target version asset url tmp extracted
  arch="$(get_arch)"; os="$(get_os)"
  [ "$arch" != unsupported ] || { err "不支持的 CPU：$(uname -m)"; return 1; }
  target=linux; [ "$os" = android ] && target=android
  version="$(latest_version)"; [ -n "$version" ] || { err "无法获取最新版本，请检查网络。"; return 1; }
  asset="openlist-${target}-${arch}.tar.gz"
  url="https://github.com/$UPSTREAM_REPO/releases/download/${version}/${asset}"
  tmp="$(mktemp -d)"
  info "系统：$os  架构：$arch  版本：$version"
  if command_exists curl; then curl -fL --retry 3 --connect-timeout 15 "$url" -o "$tmp/openlist.tar.gz" || { err "下载失败"; rm -rf "$tmp"; return 1; }
  elif command_exists wget; then wget -q --show-progress "$url" -O "$tmp/openlist.tar.gz" || { err "下载失败"; rm -rf "$tmp"; return 1; }
  else err "需要 curl 或 wget。"; rm -rf "$tmp"; return 1; fi
  command_exists tar || { err "未找到 tar。"; rm -rf "$tmp"; return 1; }
  tar -xzf "$tmp/openlist.tar.gz" -C "$tmp" || { err "解压失败。"; rm -rf "$tmp"; return 1; }
  extracted="$(find "$tmp" -type f -name openlist | head -n1)"
  [ -n "$extracted" ] || { err "安装包中未找到 openlist。"; rm -rf "$tmp"; return 1; }
  if is_running; then stop_openlist; fi
  cp "$extracted" "$BINARY"; chmod +x "$BINARY"
  "$BINARY" version >/dev/null 2>&1 || { err "OpenList 可执行文件验证失败。"; rm -f "$BINARY"; rm -rf "$tmp"; return 1; }
  echo "$version" > "$VERSION_FILE"; rm -rf "$tmp"
  install_service
  ok "OpenList $version 安装完成。"
}

update_openlist(){
  local latest current
  [ -x "$BINARY" ] || { install_openlist; return $?; }
  current="$(cat "$VERSION_FILE" 2>/dev/null || true)"
  latest="$(latest_version)"
  info "当前：${current:-未知}  最新：${latest:-未知}"
  [ -n "$latest" ] || { err "无法获取上游版本。"; return 1; }
  [ "$current" = "$latest" ] && { ok "已经是最新版本。"; return 0; }
  warn "发现新版本 $latest，开始更新……"
  install_openlist
}

self_update(){
  local latest tmp url current_file
  latest="$(latest_toolkit_version)"
  [ -n "$latest" ] || { err "无法获取 Toolkit 最新版本。"; return 1; }
  info "当前 Toolkit：v$TOOLKIT_VERSION  最新：$latest"
  [ "v$TOOLKIT_VERSION" = "$latest" ] && { ok "Toolkit 已是最新版本。"; return 0; }
  current_file="${BASH_SOURCE[0]}"
  tmp="$(mktemp)"
  url="https://raw.githubusercontent.com/$REPO/main/openlist.sh"
  if command_exists curl; then curl -fsSL --retry 3 "$url" -o "$tmp"; else wget -qO "$tmp" "$url"; fi
  if [ ! -s "$tmp" ]; then err "下载 Toolkit 更新失败。"; rm -f "$tmp"; return 1; fi
  chmod +x "$tmp"
  mv "$tmp" "$current_file"
  if [ -x "$SHORTCUT" ] && [ "$SHORTCUT" != "$current_file" ]; then cp "$current_file" "$SHORTCUT"; chmod +x "$SHORTCUT"; fi
  ok "Toolkit 已更新，请重新运行 oplist。"
}

install_shortcut(){
  mkdir -p "$(dirname "$SHORTCUT")"
  local source="${BASH_SOURCE[0]}"
  if [ -f "$source" ]; then cp "$source" "$SHORTCUT"; chmod +x "$SHORTCUT"; ok "已安装全局命令：oplist"; else warn "无法定位当前脚本，跳过 oplist 快捷命令。"; fi
}

setup_nightly_update(){
  if ! is_systemd || ! need_root; then
    warn "当前环境不是 root + systemd，暂不创建 systemd 定时更新。"
    if is_termux; then
      info "Termux 可配合 Termux:Boot/定时任务自行调用：oplist --update"
    fi
    return 0
  fi
  cat > "$UPDATE_UNIT_FILE" <<EOF
[Unit]
Description=OpenList Toolkit nightly update
After=network-online.target

[Service]
Type=oneshot
ExecStart=$BINARY version
ExecStart=$BASH -lc '$BASH $SYSTEMD_FILE >/dev/null 2>&1 || true'
EOF
  # Replace the service body with the toolkit's own update command.
  cat > "$UPDATE_UNIT_FILE" <<EOF
[Unit]
Description=OpenList Toolkit nightly update
After=network-online.target

[Service]
Type=oneshot
ExecStart=$BASH $INSTALL_DIR/toolkit-update.sh
EOF
  cat > "$INSTALL_DIR/toolkit-update.sh" <<EOF
#!/usr/bin/env bash
set -u
$BASH "$SHORTCUT" --update >/dev/null 2>&1 || true
EOF
  chmod +x "$INSTALL_DIR/toolkit-update.sh"
  cat > "$UPDATE_TIMER_FILE" <<EOF
[Unit]
Description=Run OpenList Toolkit update every night

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=15m

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now "$UPDATE_TIMER" >/dev/null 2>&1 || true
  ok "已设置每日凌晨自动检查 OpenList 更新（约 03:30）。"
}

remove_nightly_update(){
  if is_systemd && need_root; then
    systemctl disable --now "$UPDATE_TIMER" >/dev/null 2>&1 || true
    rm -f "$UPDATE_TIMER_FILE" "$UPDATE_UNIT_FILE"
    systemctl daemon-reload
    ok "已关闭每日自动更新。"
  else
    warn "当前环境没有可管理的 systemd 定时任务。"
  fi
}

show_status(){
  echo
echo -e "${C_MAGENTA}OpenList Toolkit${C_RESET}：v$TOOLKIT_VERSION"
echo "系统：$(get_os)"
echo "架构：$(get_arch)"
echo "安装目录：$INSTALL_DIR"
echo "版本：$(cat "$VERSION_FILE" 2>/dev/null || echo 未安装)"
  if is_running; then echo -e "状态：${C_GREEN}运行中${C_RESET}"; else echo -e "状态：${C_RED}未运行${C_RESET}"; fi
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then echo "管理方式：systemd"; echo "服务：$SYSTEMD_UNIT"; fi
  echo
}

show_logs(){
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then journalctl -u "$SYSTEMD_UNIT" -n 100 --no-pager; elif [ -f "$LOG_DIR/openlist.log" ]; then tail -n 100 "$LOG_DIR/openlist.log"; else warn "暂无日志。"; fi
}

backup_openlist(){
  ensure_dirs
  local out="$HOME/openlist-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$out" -C "$DATA_DIR" . 2>/dev/null && ok "备份完成：$out" || err "备份失败。"
}

uninstall_openlist(){
  read -r -p "确认卸载？输入 YES：" c; [ "$c" = YES ] || { warn "已取消。"; return; }
  if is_systemd && need_root && [ -f "$SYSTEMD_FILE" ]; then systemctl disable --now "$SYSTEMD_UNIT" >/dev/null 2>&1 || true; rm -f "$SYSTEMD_FILE"; systemctl daemon-reload; fi
  rm -rf "$INSTALL_DIR"; ok "OpenList 已卸载。"
}

more_menu(){
  while true; do
    clear 2>/dev/null || true
    echo -e "${C_BLUE}============= 更多功能 =============${C_RESET}"
    echo "1. 修改/更新 Toolkit"
    echo "2. 开启每日自动更新"
    echo "3. 关闭每日自动更新"
    echo "4. 安装 oplist 全局命令"
    echo "5. 查看 OpenList 启动日志"
    echo "0. 返回主菜单"
    printf '请输入选项 (0-5)：'
    read -r c
    case "$c" in
      1) self_update;;
      2) setup_nightly_update;;
      3) remove_nightly_update;;
      4) install_shortcut;;
      5) show_logs;;
      0) break;;
      *) warn "无效选项。";;
    esac
    echo; read -r -p '按 Enter 返回菜单……' _
  done
}

menu(){
  while true; do
    clear 2>/dev/null || true
    local current latest status
    current="$(cat "$VERSION_FILE" 2>/dev/null || true)"
    latest="$(latest_version 2>/dev/null || true)"
    if is_running; then status="${C_GREEN}运行中${C_RESET}"; else status="${C_RED}未运行${C_RESET}"; fi
    echo -e "${C_BLUE}╔══════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BLUE}║${C_MAGENTA}          OpenList Toolkit            ${C_BLUE}║${C_RESET}"
    printf '${C_BLUE}║${C_RESET}              v%-18s${C_BLUE}║${C_RESET}\n' "$TOOLKIT_VERSION"
    echo -e "${C_BLUE}╠══════════════════════════════════════╣${C_RESET}"
    echo -e "${C_CYAN}系统${C_RESET}：$(get_os)   ${C_CYAN}架构${C_RESET}：$(get_arch)"
    echo -e "${C_CYAN}OpenList${C_RESET}：${current:-未安装} → 最新 ${latest:-未知}"
    echo -e "${C_CYAN}状态${C_RESET}：$status"
    echo -e "${C_BLUE}╠══════════════════════════════════════╣${C_RESET}"
    echo "  1. 安装 OpenList"
    echo "  2. 更新 OpenList"
    echo "  3. 启动 OpenList"
    echo "  4. 停止 OpenList"
    echo "  5. 重启 OpenList"
    echo "  6. 查看状态"
    echo "  7. 查看日志"
    echo "  8. 备份数据"
    echo "  9. 更多功能"
    echo "  0. 退出"
    echo -e "${C_BLUE}╚══════════════════════════════════════╝${C_RESET}"
    printf '请选择：'
    read -r c; echo
    case "$c" in
      1) install_openlist;;
      2) update_openlist;;
      3) start_openlist;;
      4) stop_openlist;;
      5) restart_openlist;;
      6) show_status;;
      7) show_logs;;
      8) backup_openlist;;
      9) more_menu;;
      0) exit 0;;
      *) warn '无效选项。';;
    esac
    echo; read -r -p '按 Enter 返回菜单……' _
  done
}

case "${1:-}" in
  --install) install_openlist;;
  --update) update_openlist;;
  --start) start_openlist;;
  --stop) stop_openlist;;
  --restart) restart_openlist;;
  --status) show_status;;
  --logs) show_logs;;
  --backup) backup_openlist;;
  --self-update) self_update;;
  --setup-nightly-update) setup_nightly_update;;
  --remove-nightly-update) remove_nightly_update;;
  --install-shortcut) install_shortcut;;
  *) install_shortcut >/dev/null 2>&1 || true; menu;;
esac
