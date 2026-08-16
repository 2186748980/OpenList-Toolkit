#!/usr/bin/env bash
# OpenList Toolkit - lightweight OpenList management script
# Community project for Linux and Termux.

set -u

TOOLKIT_VERSION="0.2"
INSTALL_DIR="${OPENLIST_HOME:-$HOME/.openlist}"
BIN_DIR="$INSTALL_DIR/bin"
DATA_DIR="$INSTALL_DIR/data"
CONFIG_DIR="$INSTALL_DIR/config"
LOG_DIR="$INSTALL_DIR/logs"
BINARY="$BIN_DIR/openlist"

info() { echo -e "\033[36m[INFO]\033[0m $*"; }
ok() { echo -e "\033[32m[ OK ]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
err() { echo -e "\033[31m[ERR ]\033[0m $*"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv7) echo "arm-7" ;;
    armv6l|armv6) echo "arm-6" ;;
    i386|i686) echo "386" ;;
    *) echo "unsupported" ;;
  esac
}

get_os() {
  if [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *com.termux* ]]; then
    echo "android"
  elif [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "${ID:-linux}"
  else
    echo "linux"
  fi
}

ensure_dirs() {
  mkdir -p "$BIN_DIR" "$DATA_DIR" "$CONFIG_DIR" "$LOG_DIR"
}

latest_version() {
  local url="https://api.github.com/repos/OpenListTeam/OpenList/releases/latest"
  local json=""
  if command_exists curl; then
    json="$(curl -fsSL --retry 3 "$url" 2>/dev/null || true)"
  elif command_exists wget; then
    json="$(wget -qO- "$url" 2>/dev/null || true)"
  fi
  printf '%s\n' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

is_running() {
  local pid=""
  if [ -f "$INSTALL_DIR/openlist.pid" ]; then
    pid="$(cat "$INSTALL_DIR/openlist.pid" 2>/dev/null || true)"
  fi
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

stop_process() {
  local pid=""
  if [ -f "$INSTALL_DIR/openlist.pid" ]; then
    pid="$(cat "$INSTALL_DIR/openlist.pid" 2>/dev/null || true)"
  fi
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$INSTALL_DIR/openlist.pid"
}

start_openlist() {
  ensure_dirs
  if [ ! -x "$BINARY" ]; then
    err "OpenList 尚未安装，请先选择 1。"
    return 1
  fi
  if is_running; then
    warn "OpenList 已经在运行。"
    return 0
  fi

  nohup "$BINARY" server --data "$DATA_DIR" >"$LOG_DIR/openlist.log" 2>&1 &
  local pid=$!
  echo "$pid" > "$INSTALL_DIR/openlist.pid"
  sleep 1

  if is_running; then
    ok "OpenList 已启动，PID: $pid"
    info "默认访问地址：http://服务器IP:5244"
  else
    err "OpenList 启动失败，请选择 7 查看日志。"
    rm -f "$INSTALL_DIR/openlist.pid"
    return 1
  fi
}

stop_openlist() {
  if ! is_running; then
    rm -f "$INSTALL_DIR/openlist.pid"
    warn "OpenList 当前没有运行。"
    return 0
  fi
  stop_process
  ok "OpenList 已停止。"
}

install_openlist() {
  ensure_dirs

  local arch os version target_os asset url tmp extracted
  arch="$(get_arch)"
  os="$(get_os)"

  if [ "$arch" = "unsupported" ]; then
    err "暂不支持的 CPU 架构：$(uname -m)"
    return 1
  fi

  if [ "$os" = "android" ]; then
    target_os="android"
  else
    target_os="linux"
  fi

  version="$(latest_version)"
  if [ -z "$version" ]; then
    err "无法获取 OpenList 最新版本，请检查网络。"
    return 1
  fi

  # OpenList official release assets use arm-6/arm-7 naming for 32-bit ARM.
  asset="openlist-${target_os}-${arch}.tar.gz"
  url="https://github.com/OpenListTeam/OpenList/releases/download/${version}/${asset}"
  tmp="$(mktemp -d)"

  info "系统：$os"
  info "架构：$arch"
  info "版本：$version"
  info "下载：$asset"

  if command_exists curl; then
    if ! curl -fL --retry 3 "$url" -o "$tmp/openlist.tar.gz"; then
      err "下载失败：$url"
      rm -rf "$tmp"
      return 1
    fi
  elif command_exists wget; then
    if ! wget -q --show-progress "$url" -O "$tmp/openlist.tar.gz"; then
      err "下载失败：$url"
      rm -rf "$tmp"
      return 1
    fi
  else
    err "需要 curl 或 wget。"
    rm -rf "$tmp"
    return 1
  fi

  if ! command_exists tar; then
    err "未找到 tar，请先安装 tar。"
    rm -rf "$tmp"
    return 1
  fi

  if ! tar -xzf "$tmp/openlist.tar.gz" -C "$tmp"; then
    err "解压失败。"
    rm -rf "$tmp"
    return 1
  fi

  extracted="$(find "$tmp" -type f -name 'openlist' | head -n1)"
  if [ -z "$extracted" ]; then
    err "安装包中没有找到 openlist 可执行文件。"
    rm -rf "$tmp"
    return 1
  fi

  stop_process
  cp "$extracted" "$BINARY"
  chmod +x "$BINARY"

  # Verify the binary before declaring success.
  if ! "$BINARY" version >/dev/null 2>&1; then
    err "OpenList 可执行文件验证失败。"
    rm -f "$BINARY"
    rm -rf "$tmp"
    return 1
  fi

  echo "$version" > "$INSTALL_DIR/version"
  rm -rf "$tmp"
  ok "OpenList $version 安装完成。"
}

update_openlist() {
  local current latest
  if [ ! -x "$BINARY" ]; then
    install_openlist
    return $?
  fi

  current="$(cat "$INSTALL_DIR/version" 2>/dev/null || true)"
  latest="$(latest_version)"
  info "当前版本：${current:-未知}"
  info "最新版本：${latest:-未知}"

  if [ -n "$current" ] && [ -n "$latest" ] && [ "$current" = "$latest" ]; then
    ok "已经是最新版本。"
    return 0
  fi

  install_openlist
}

show_status() {
  echo
  echo "OpenList Toolkit：v$TOOLKIT_VERSION"
  echo "系统：$(get_os)"
  echo "架构：$(get_arch)"
  echo "安装目录：$INSTALL_DIR"
  echo "版本：$(cat "$INSTALL_DIR/version" 2>/dev/null || echo 未安装)"
  if is_running; then
    echo "状态：运行中"
    echo "PID：$(cat "$INSTALL_DIR/openlist.pid")"
    echo "地址：http://服务器IP:5244"
  else
    echo "状态：未运行"
  fi
  echo
}

show_logs() {
  local log="$LOG_DIR/openlist.log"
  if [ ! -f "$log" ]; then
    warn "暂无日志。"
    return
  fi
  tail -n 100 "$log"
}

uninstall_openlist() {
  echo "这将停止 OpenList 并删除 $INSTALL_DIR。"
  read -r -p "确认卸载？输入 YES：" confirm
  if [ "$confirm" != "YES" ]; then
    warn "已取消。"
    return
  fi
  stop_process
  rm -rf "$INSTALL_DIR"
  ok "OpenList 已卸载。"
}

menu() {
  while true; do
    clear 2>/dev/null || true
    echo "╔════════════════════════════════════╗"
    echo "║         OpenList Toolkit           ║"
    echo "║             v$TOOLKIT_VERSION                  ║"
    echo "╠════════════════════════════════════╣"
    echo "║  1. 安装 OpenList                  ║"
    echo "║  2. 更新 OpenList                  ║"
    echo "║  3. 启动 OpenList                  ║"
    echo "║  4. 停止 OpenList                  ║"
    echo "║  5. 重启 OpenList                  ║"
    echo "║  6. 查看状态                       ║"
    echo "║  7. 查看日志                       ║"
    echo "║  8. 卸载 OpenList                  ║"
    echo "║  0. 退出                            ║"
    echo "╚════════════════════════════════════╝"
    printf "请选择："
    read -r choice
    echo
    case "$choice" in
      1) install_openlist ;;
      2) update_openlist ;;
      3) start_openlist ;;
      4) stop_openlist ;;
      5) stop_openlist; start_openlist ;;
      6) show_status ;;
      7) show_logs ;;
      8) uninstall_openlist ;;
      0) exit 0 ;;
      *) warn "无效选项。" ;;
    esac
    echo
    read -r -p "按 Enter 返回菜单……" _
  done
}

case "${1:-}" in
  --install) install_openlist; exit $? ;;
  --start) start_openlist; exit $? ;;
  --stop) stop_openlist; exit $? ;;
  --restart) stop_openlist; start_openlist; exit $? ;;
  --status) show_status; exit 0 ;;
  *) menu ;;
esac
