#!/usr/bin/env bash
set -u

TOOLKIT_VERSION="0.3"
INSTALL_DIR="${OPENLIST_HOME:-$HOME/.openlist}"
BIN_DIR="$INSTALL_DIR/bin"
DATA_DIR="$INSTALL_DIR/data"
LOG_DIR="$INSTALL_DIR/logs"
BINARY="$BIN_DIR/openlist"
SYSTEMD_UNIT="openlist-toolkit.service"
SYSTEMD_FILE="/etc/systemd/system/$SYSTEMD_UNIT"

info(){ echo -e "\033[36m[INFO]\033[0m $*"; }
ok(){ echo -e "\033[32m[ OK ]\033[0m $*"; }
warn(){ echo -e "\033[33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[31m[ERR ]\033[0m $*"; }
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
ensure_dirs(){ mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOG_DIR"; }
latest_version(){
  local j=""
  if command_exists curl; then j="$(curl -fsSL --retry 3 https://api.github.com/repos/OpenListTeam/OpenList/releases/latest 2>/dev/null || true)";
  elif command_exists wget; then j="$(wget -qO- https://api.github.com/repos/OpenListTeam/OpenList/releases/latest 2>/dev/null || true)"; fi
  printf '%s\n' "$j" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}
is_systemd(){ command_exists systemctl && [ -d /run/systemd/system ]; }
need_root(){ [ "$(id -u)" -eq 0 ]; }

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

is_running(){
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then systemctl is-active --quiet "$SYSTEMD_UNIT"; return $?; fi
  [ -f "$INSTALL_DIR/openlist.pid" ] && kill -0 "$(cat "$INSTALL_DIR/openlist.pid" 2>/dev/null)" 2>/dev/null
}

start_openlist(){
  ensure_dirs
  [ -x "$BINARY" ] || { err "OpenList 尚未安装，请先选择 1。"; return 1; }
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then systemctl start "$SYSTEMD_UNIT" && ok "OpenList 已启动。" || { err "启动失败，请查看日志。"; return 1; }; return 0; fi
  is_running && { warn "OpenList 已经在运行。"; return 0; }
  nohup "$BINARY" server --data "$DATA_DIR" >"$LOG_DIR/openlist.log" 2>&1 &
  local pid=$!; echo "$pid" > "$INSTALL_DIR/openlist.pid"; sleep 1
  if is_running; then ok "OpenList 已启动，PID: $pid"; else err "启动失败，请查看日志。"; rm -f "$INSTALL_DIR/openlist.pid"; return 1; fi
}
stop_openlist(){
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then systemctl stop "$SYSTEMD_UNIT" && ok "OpenList 已停止。"; return 0; fi
  if [ -f "$INSTALL_DIR/openlist.pid" ]; then local p; p="$(cat "$INSTALL_DIR/openlist.pid" 2>/dev/null || true)"; if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then kill "$p" 2>/dev/null || true; sleep 1; kill -9 "$p" 2>/dev/null || true; fi; rm -f "$INSTALL_DIR/openlist.pid"; fi
  warn "OpenList 已停止或原本未运行。"
}

install_openlist(){
  ensure_dirs
  local arch os target version asset url tmp extracted
  arch="$(get_arch)"; os="$(get_os)"
  [ "$arch" != unsupported ] || { err "不支持的 CPU：$(uname -m)"; return 1; }
  target=linux; [ "$os" = android ] && target=android
  version="$(latest_version)"; [ -n "$version" ] || { err "无法获取最新版本，请检查网络。"; return 1; }
  asset="openlist-${target}-${arch}.tar.gz"; url="https://github.com/OpenListTeam/OpenList/releases/download/${version}/${asset}"; tmp="$(mktemp -d)"
  info "系统：$os  架构：$arch  版本：$version"
  if command_exists curl; then curl -fL --retry 3 "$url" -o "$tmp/openlist.tar.gz" || { err "下载失败"; rm -rf "$tmp"; return 1; }
  elif command_exists wget; then wget -q --show-progress "$url" -O "$tmp/openlist.tar.gz" || { err "下载失败"; rm -rf "$tmp"; return 1; }
  else err "需要 curl 或 wget。"; rm -rf "$tmp"; return 1; fi
  command_exists tar || { err "未找到 tar。"; rm -rf "$tmp"; return 1; }
  tar -xzf "$tmp/openlist.tar.gz" -C "$tmp" || { err "解压失败。"; rm -rf "$tmp"; return 1; }
  extracted="$(find "$tmp" -type f -name openlist | head -n1)"; [ -n "$extracted" ] || { err "安装包中未找到 openlist。"; rm -rf "$tmp"; return 1; }
  if is_running; then stop_openlist; fi
  cp "$extracted" "$BINARY"; chmod +x "$BINARY"
  "$BINARY" version >/dev/null 2>&1 || { err "OpenList 可执行文件验证失败。"; rm -f "$BINARY"; rm -rf "$tmp"; return 1; }
  echo "$version" > "$INSTALL_DIR/version"; rm -rf "$tmp"
  install_service
  ok "OpenList $version 安装完成。"
}
update_openlist(){
  local latest current
  [ -x "$BINARY" ] || { install_openlist; return $?; }
  current="$(cat "$INSTALL_DIR/version" 2>/dev/null || true)"; latest="$(latest_version)"
  info "当前：${current:-未知}  最新：${latest:-未知}"
  [ -n "$latest" ] && [ "$current" = "$latest" ] && { ok "已经是最新版本。"; return 0; }
  install_openlist
}
show_status(){
  echo; echo "OpenList Toolkit：v$TOOLKIT_VERSION"; echo "系统：$(get_os)"; echo "架构：$(get_arch)"; echo "安装目录：$INSTALL_DIR"; echo "版本：$(cat "$INSTALL_DIR/version" 2>/dev/null || echo 未安装)"
  if is_running; then echo "状态：运行中"; else echo "状态：未运行"; fi
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then echo "管理方式：systemd"; echo "服务：$SYSTEMD_UNIT"; fi; echo
}
show_logs(){
  if is_systemd && [ -f "$SYSTEMD_FILE" ]; then journalctl -u "$SYSTEMD_UNIT" -n 100 --no-pager; elif [ -f "$LOG_DIR/openlist.log" ]; then tail -n 100 "$LOG_DIR/openlist.log"; else warn "暂无日志。"; fi
}
backup_openlist(){
  ensure_dirs; local out="$HOME/openlist-backup-$(date +%Y%m%d-%H%M%S).tar.gz"; tar -czf "$out" -C "$DATA_DIR" . 2>/dev/null && ok "备份完成：$out" || err "备份失败。"
}
uninstall_openlist(){
  read -r -p "确认卸载？输入 YES：" c; [ "$c" = YES ] || { warn "已取消。"; return; }
  if is_systemd && need_root && [ -f "$SYSTEMD_FILE" ]; then systemctl disable --now "$SYSTEMD_UNIT" >/dev/null 2>&1 || true; rm -f "$SYSTEMD_FILE"; systemctl daemon-reload; fi
  rm -rf "$INSTALL_DIR"; ok "OpenList 已卸载。"
}
menu(){
 while true; do clear 2>/dev/null || true; echo "╔════════════════════════════════════╗"; echo "║         OpenList Toolkit           ║"; printf '║             v%-18s ║\n' "$TOOLKIT_VERSION"; echo "╠════════════════════════════════════╣"; echo "║  1. 安装 OpenList                  ║"; echo "║  2. 更新 OpenList                  ║"; echo "║  3. 启动 OpenList                  ║"; echo "║  4. 停止 OpenList                  ║"; echo "║  5. 重启 OpenList                  ║"; echo "║  6. 查看状态                       ║"; echo "║  7. 查看日志                       ║"; echo "║  8. 备份数据                       ║"; echo "║  9. 卸载 OpenList                  ║"; echo "║  0. 退出                            ║"; echo "╚════════════════════════════════════╝"; printf '请选择：'; read -r c; echo; case "$c" in 1) install_openlist;; 2) update_openlist;; 3) start_openlist;; 4) stop_openlist;; 5) stop_openlist; start_openlist;; 6) show_status;; 7) show_logs;; 8) backup_openlist;; 9) uninstall_openlist;; 0) exit 0;; *) warn '无效选项。';; esac; echo; read -r -p '按 Enter 返回菜单……' _; done
}
case "${1:-}" in
  --install) install_openlist;; --update) update_openlist;; --start) start_openlist;; --stop) stop_openlist;; --restart) stop_openlist; start_openlist;; --status) show_status;; --logs) show_logs;; --backup) backup_openlist;; *) menu;;
esac
