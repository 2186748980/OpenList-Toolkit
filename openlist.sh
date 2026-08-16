#!/usr/bin/env bash
# OpenList Toolkit - lightweight OpenList management script
# Supports common Linux distributions and Termux.

set -u

APP_NAME="OpenList Toolkit"
INSTALL_DIR="${OPENLIST_HOME:-$HOME/.openlist}"
BIN_DIR="$INSTALL_DIR/bin"
DATA_DIR="$INSTALL_DIR/data"
CONFIG_DIR="$INSTALL_DIR/config"
LOG_DIR="$INSTALL_DIR/logs"
BINARY="$BIN_DIR/openlist"
SERVICE_NAME="openlist"

if command -v curl >/dev/null 2>&1; then
  CURL="curl"
elif command -v wget >/dev/null 2>&1; then
  CURL="wget -qO-"
else
  echo "错误：需要 curl 或 wget。"
  exit 1
fi

info() { echo -e "\033[36m[INFO]\033[0m $*"; }
ok() { echo -e "\033[32m[ OK ]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
err() { echo -e "\033[31m[ERR ]\033[0m $*"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

get_arch() {
  local a
  a="$(uname -m)"
  case "$a" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv7) echo "armv7" ;;
    armv6l|armv6) echo "armv6" ;;
    i386|i686) echo "386" ;;
    *) echo "$a" ;;
  esac
}

get_os() {
  if [ -n "${TERMUX_VERSION:-}" ] || [ -d "$PREFIX" ] && [[ "${PREFIX:-}" == *com.termux* ]]; then
    echo "termux"
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
  local json
  if command_exists curl; then
    json="$(curl -fsSL "$url" 2>/dev/null || true)"
  else
    json="$(wget -qO- "$url" 2>/dev/null || true)"
  fi
  printf '%s\n' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

installed_version() {
  if [ -x "$BINARY" ]; then
    "$BINARY" version 2>/dev/null | head -n1 || true
  else
    echo "未安装"
  fi
}

stop_process() {
  if [ -f "$INSTALL_DIR/openlist.pid" ]; then
    local pid
    pid="$(cat "$INSTALL_DIR/openlist.pid" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$INSTALL_DIR/openlist.pid"
  fi

  pkill -f "$BINARY server" 2>/dev/null || true
}

is_running() {
  if [ -f "$INSTALL_DIR/openlist.pid" ]; then
    local pid
    pid="$(cat "$INSTALL_DIR/openlist.pid" 2>/dev/null || true)"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
  fi
  return 1
}

start_openlist() {
  ensure_dirs
  if [ ! -x "$BINARY" ]; then
    err "OpenList 尚未安装。"
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

  if kill -0 "$pid" 2>/dev/null; then
    ok "OpenList 已启动，PID: $pid"
  else
    err "OpenList 启动失败，请查看日志。"
    return 1
  fi
}

stop_openlist() {
  if ! is_running; then
    warn "OpenList 当前没有运行。"
    rm -f "$INSTALL_DIR/openlist.pid"
    return 0
  fi
  stop_process
  ok "OpenList 已停止。"
}

install_openlist() {
  ensure_dirs
  local arch os version url tmp
  arch="$(get_arch)"
  os="$(get_os)"

  case "$arch" in
    amd64|arm64|armv7|armv6|386) ;;
    *) err "暂不支持的 CPU 架构：$arch"; return 1 ;;
  esac

  info "检测到系统：$os / $arch"
  info "正在获取 OpenList 最新版本……"
  version="$(latest_version)"
  if [ -z "$version" ]; then
    err "无法获取最新版本，请检查网络。"
    return 1
  fi

  # OpenList release asset naming: openlist-<os>-<arch>.tar.gz
  local target_os="linux"
  if [ "$os" = "termux" ]; then target_os="android"; fi
  url="https://github.com/OpenListTeam/OpenList/releases/download/${version}/openlist-${target_os}-${arch}.tar.gz"
  tmp="$(mktemp -d)"

  info "下载 $version：$url"
  if command_exists curl; then
    if ! curl -fL --retry 3 "$url" -o "$tmp/openlist.tar.gz"; then
      err "下载失败。"
      rm -rf "$tmp"
      return 1
    fi
  else
    if ! wget -q --show-progress "$url" -O "$tmp/openlist.tar.gz"; then
      err "下载失败。"
      rm -rf "$tmp"
      return 1
    fi
  fi

  if ! tar -xzf "$tmp/openlist.tar.gz" -C "$tmp"; then
    err "解压失败。"
    rm -rf "$tmp"
    return 1
  fi

  local extracted
  extracted="$(find "$tmp" -type f -name 'openlist*' -perm -u+x 2>/dev/null | head -n1)"
  if [ -z "$extracted" ]; then
    extracted="$(find "$tmp" -type f -name 'openlist*' 2>/dev/null | head -n1)"
  fi
  if [ -z "$extracted" ]; then
    err "安装包中没有找到 OpenList 可执行文件。"
    rm -rf "$tmp"
    return 1
  fi

  stop_process
  cp "$extracted" "$BINARY"
  chmod +x "$BINARY"
  echo "$version" > "$INSTALL_DIR/version"
  rm -rf "$tmp"
  ok "OpenList $version 安装完成。"
}

update_openlist() {
  if [ ! -x "$BINARY" ]; then
    install_openlist
    return
  fi
  local current latest
  current="$(cat "$INSTALL_DIR/version" 2>/dev/null || true)"
  latest="$(latest_version)"
  info "当前版本：${current:-未知}"
  info "最新版本：${latest:-未知}"
  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    ok "已经是最新版本。"
    return
  fi
  install_openlist
}

show_status() {
  echo
  echo "系统：$(get_os)"
  echo "架构：$(get_arch)"
  echo "安装目录：$INSTALL_DIR"
  echo "版本：$(cat "$INSTALL_DIR/version" 2>/dev/null || echo 未安装)"
  if is_running; then
    echo "状态：运行中"
    echo "PID：$(cat "$INSTALL_DIR/openlist.pid")"
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
  if command_exists tail; then
    tail -n 80 "$log"
  else
    cat "$log"
  fi
}

uninstall_openlist() {
  echo "这将删除 OpenList Toolkit 的安装文件和运行数据。"
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
    echo "║             v0.1                   ║"
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

if [ "${1:-}" = "--install" ]; then
  install_openlist
  exit $?
elif [ "${1:-}" = "--start" ]; then
  start_openlist
  exit $?
elif [ "${1:-}" = "--stop" ]; then
  stop_openlist
  exit $?
elif [ "${1:-}" = "--restart" ]; then
  stop_openlist
  start_openlist
  exit $?
elif [ "${1:-}" = "--status" ]; then
  show_status
  exit 0
fi

menu
