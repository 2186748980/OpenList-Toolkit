#!/data/data/com.termux/files/usr/bin/bash
set -u

# OpenList Toolkit - merged/cleaned for Termux and Linux
# TOOLKIT_FEATURES_V061
REPO="2186748980/OpenList-Toolkit"
UPSTREAM="OpenListTeam/OpenList"
ARIANG_REPO="mayswind/AriaNg"
HOME_DIR="${OPENLIST_HOME:-$HOME/.openlist}"
TOOLKIT_SYNCED_HASH_FILE="$HOME_DIR/.toolkit-synced-hash"
BIN_DIR="$HOME_DIR/bin"
DATA_DIR="$HOME_DIR/data"
LOG_DIR="$HOME_DIR/logs"
BINARY="$BIN_DIR/openlist"
PID_FILE="$HOME_DIR/openlist.pid"
VERSION_FILE="$HOME_DIR/version"
VERSION_CACHE="$HOME_DIR/latest-version"
VERSION_CHECKING="$HOME_DIR/.version-checking"
SHORTCUT="$HOME/.local/bin/oplist"
ARIA2_DIR="$HOME/aria2"
ARIA2_CONF="$ARIA2_DIR/aria2.conf"
ARIA2_LOG="$ARIA2_DIR/aria2.log"
ARIA2_PID_FILE="$ARIA2_DIR/aria2.pid"
ARIANG_DIR="$ARIA2_DIR/ariang"
ARIANG_HTML="$ARIANG_DIR/index.html"
ARIANG_LOG="$ARIA2_DIR/ariang.log"
ARIANG_PID_FILE="$ARIA2_DIR/ariang.pid"
ARIANG_PORT=6880
ARIANG_VERSION_FILE="$ARIANG_DIR/version"
CF_DIR="$HOME/.cloudflared"
CF_CONFIG="$CF_DIR/config.yml"
CF_LOG="$CF_DIR/tunnel.log"
BACKUP_DIR="$HOME/OpenList-Backups"
GITHUB_TOKEN_FILE="$HOME/.github_token"
ARIA2_SECRET_FILE="$HOME/.aria2_secret"
TUNNEL_NAME_FILE="$CF_DIR/tunnel.name"
DOMAIN_FILE="$CF_DIR/domain"
BOOT_DIR="$HOME/.termux/boot"
BOOT_FILE="$BOOT_DIR/openlist-toolkit.sh"
WATCHDOG_FILE="$BOOT_DIR/openlist-watchdog.sh"
WATCHDOG_ENABLED="$HOME_DIR/.watchdog-enabled"
MANUAL_STOP_FILE="$HOME_DIR/.manual-stop"
LOCAL_PORT=5244

R='\033[0m'; CY='\033[1;36m'; GR='\033[1;32m'; YE='\033[1;33m'; RE='\033[1;31m'; MA='\033[1;35m'; BL='\033[1;34m'; OR='\033[38;5;208m'; PI='\033[38;5;213m'; LI='\033[38;5;118m'; GRY='\033[1;30m'
info(){ echo -e "${CY}[INFO]${R} $*"; }
ok(){ echo -e "${GR}[ OK ]${R} $*"; }
warn(){ echo -e "${YE}[WARN]${R} $*"; }
err(){ echo -e "${RE}[ERR ]${R} $*"; }
has(){ command -v "$1" >/dev/null 2>&1; }
is_termux(){ [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *com.termux* ]]; }
root(){ [ "$(id -u)" -eq 0 ]; }
systemd(){ has systemctl && [ -d /run/systemd/system ]; }
arch(){ case "$(uname -m)" in x86_64|amd64) echo amd64;; aarch64|arm64) echo arm64;; armv7l|armv7) echo arm-7;; armv6l|armv6) echo arm-6;; i386|i686) echo 386;; *) echo unsupported;; esac; }
os_name(){ if is_termux; then echo android; elif [ -f /etc/os-release ]; then . /etc/os-release; echo "${ID:-linux}"; else echo linux; fi; }
mkdirs(){ mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOG_DIR" "$ARIA2_DIR" "$ARIANG_DIR" "$CF_DIR" "$BACKUP_DIR" "$HOME/.local/bin"; }
term_width(){ local w; w=$(stty size 2>/dev/null | awk '{print $2}'); case "$w" in ''|*[!0-9]*) w=80;; esac; echo "$w"; }
box_width(){ local w; w=$(term_width); [ "$w" -gt 58 ] && w=58; [ "$w" -lt 34 ] && w=34; echo "$w"; }
line(){ local w; w=$(box_width); printf "%b%s%b\n" "$BL" "$(printf "%*s" "$w" "" | tr " " "=")" "$R"; }
center(){ local text="$1" w len pad; w=$(box_width); len=${#text}; pad=$(( (w-len)/2 )); [ "$pad" -lt 0 ] && pad=0; printf '%*s%b%s%b%*s\n' "$pad" '' "$MA" "$text" "$BL" $((w-len-pad)) ''; }
pause_menu(){ echo; printf '按 Enter 返回菜单……'; read -r _; }
get_github_token(){ GITHUB_TOKEN=""; [ -f "$GITHUB_TOKEN_FILE" ] && GITHUB_TOKEN="$(cat "$GITHUB_TOKEN_FILE" 2>/dev/null || true)"; }
api_get(){ local url="$1"; get_github_token; if has curl; then if [ -n "$GITHUB_TOKEN" ]; then curl -fsSL --retry 1 --connect-timeout 5 -H "Authorization: Bearer $GITHUB_TOKEN" "$url" 2>/dev/null || true; else curl -fsSL --retry 1 --connect-timeout 5 "$url" 2>/dev/null || true; fi; elif has wget; then wget -qO- --timeout=8 "$url" 2>/dev/null || true; fi; }
upstream_version(){ api_get "https://api.github.com/repos/$UPSTREAM/releases/latest" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1; }
check_version_bg(){ mkdirs; [ -f "$VERSION_CACHE" ] && [ "$(find "$VERSION_CACHE" -mmin -60 2>/dev/null)" ] && return 0; [ -f "$VERSION_CHECKING" ] && return 0; : > "$VERSION_CHECKING"; ( v="$(upstream_version)"; [ -n "$v" ] && printf '%s\n' "$v" > "$VERSION_CACHE"; rm -f "$VERSION_CHECKING" ) >/dev/null 2>&1 & }
latest_version(){ [ -s "$VERSION_CACHE" ] && cat "$VERSION_CACHE" || echo "检测中"; }
running(){ if systemd && [ -f /etc/systemd/system/openlist-toolkit.service ]; then systemctl is-active --quiet openlist-toolkit.service; return $?; fi; [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; }
aria2_running(){ [ -f "$ARIA2_PID_FILE" ] && kill -0 "$(cat "$ARIA2_PID_FILE" 2>/dev/null)" 2>/dev/null; }
ariang_running(){ [ -f "$ARIANG_PID_FILE" ] && kill -0 "$(cat "$ARIANG_PID_FILE" 2>/dev/null)" 2>/dev/null; }
tunnel_running(){ has pgrep && pgrep -f 'cloudflared.*tunnel.*run' >/dev/null 2>&1; }
local_ips(){
    if ! has ifconfig; then return 0; fi
    ifconfig 2>/dev/null | awk '
        /^[a-zA-Z0-9_.-]+:/ { iface=$1; sub(/:$/, "", iface); next }
        /inet / { ip=$2; if (ip == "127.0.0.1") next; if (iface ~ /^tun[0-9]*$/) next; if (iface ~ /^ccmni[0-9]*$/) next; if (iface ~ /^lo$/) next; if (ip ~ /^169.254./) next; print iface "|" ip }
    '
}
sha256_of(){ if has sha256sum; then sha256sum | awk '{print $1}'; elif has shasum; then shasum -a 256 | awk '{print $1}'; elif has openssl; then openssl dgst -sha256 | awk '{print $NF}'; else echo ''; fi; }
toolkit_remote_code(){ api_get "https://raw.githubusercontent.com/$REPO/main/openlist.sh"; }
toolkit_local_code(){ cat "${BASH_SOURCE[0]}" 2>/dev/null; }
toolkit_hash(){ printf '%s' "$1" | sha256_of; }
toolkit_build_id(){ local h; h="$(toolkit_hash "$(toolkit_local_code)")"; [ -n "$h" ] && printf '%s\n' "${h:0:7}" || echo 'dev'; }
apply_toolkit_code(){
    local remote_content="$1" remote_hash="$2" tmp src
    src="${BASH_SOURCE[0]}"
    tmp="$(mktemp)"
    printf '%s\n' "$remote_content" > "$tmp"
    head -n1 "$tmp" | grep -q '^#!' || { err '云端代码 校验失败，已取消同步。'; rm -f "$tmp"; return 1; }
    [ "$(wc -c < "$tmp")" -gt 500 ] || { err '云端代码 内容异常，已取消同步。'; rm -f "$tmp"; return 1; }
    chmod +x "$tmp"
    cp "$tmp" "$src"
    mkdir -p "$(dirname "$SHORTCUT")"
    cp "$tmp" "$SHORTCUT" 2>/dev/null || true
    chmod +x "$SHORTCUT" 2>/dev/null || true
    rm -f "$tmp"
    printf '%s\n' "$remote_hash" > "$TOOLKIT_SYNCED_HASH_FILE"
    ok 'Toolkit 代码已同步为 GitHub main 最新版本。'
}
network_status(){
    echo "网络访问："; if ! running; then echo "  OpenList 当前未运行"; return 0; fi
    echo "  本机：http://127.0.0.1:$LOCAL_PORT"; local found=0 label
    while IFS="|" read -r iface ip; do [ -n "$ip" ] || continue; found=1; case "$iface" in ap*) label="热点";; wlan*) label="Wi-Fi";; *) label="局域网";; esac; echo "  $label：http://$ip:$LOCAL_PORT"; done <<EOF
$(local_ips)
EOF
    [ "$found" -eq 1 ] || echo "  未发现可用局域网地址"
}
check_environment(){
    line; center '环境与依赖检查'; line; local okc=0 warnc=0
    check_dep(){ local name="$1" cmd="$2"; if has "$cmd"; then echo -e "${GR}✓${R} $name：$cmd"; okc=$((okc+1)); else echo -e "${YE}!${R} $name：未安装（$cmd）"; warnc=$((warnc+1)); fi; }
    if is_termux; then echo -e "${GR}✓${R} Android / Termux"; else echo -e "${GR}✓${R} Linux：$(os_name)"; fi
    check_dep "网络工具" curl; check_dep "压缩工具" tar; check_dep "网卡检测" ifconfig; check_dep "进程检测" pgrep
    if is_termux && [ -d "$HOME/storage/shared" ]; then echo -e "${GR}✓${R} Termux 存储权限"; elif is_termux; then echo -e "${YE}!${R} Termux 存储未配置，可执行 termux-setup-storage"; warnc=$((warnc+1)); fi
    if [ -x "$BINARY" ]; then echo -e "${GR}✓${R} OpenList：$(cat "$VERSION_FILE" 2>/dev/null || echo 已安装)"; else echo -e "${YE}!${R} OpenList：未安装"; warnc=$((warnc+1)); fi
    echo "检查完成：$okc 项正常，$warnc 项需要注意。"
}
show_qr(){
    local url=""; while IFS="|" read -r iface ip; do [ -n "$ip" ] || continue; case "$iface" in ap*|wlan*) url="http://$ip:$LOCAL_PORT"; break;; esac; done <<EOF
$(local_ips)
EOF
    [ -n "$url" ] || { warn '当前未发现热点/Wi-Fi 地址。'; return 1; }; echo "访问地址：$url"
    if has qrencode; then qrencode -t ANSIUTF8 "$url"; return; fi
    if ! has python; then warn '未找到 Python，无法生成二维码。'; return 1; fi
    if ! python -c 'import qrcode' >/dev/null 2>&1; then info '正在安装 Python 二维码模块...'; python -m pip install --user qrcode[pil] || { err 'Python 二维码模块安装失败。'; return 1; }; fi
    python - "$url" <<'PYQR'
import sys,qrcode
url=sys.argv[1]; qr=qrcode.QRCode(version=None,error_correction=qrcode.constants.ERROR_CORRECT_M,box_size=1,border=1); qr.add_data(url); qr.make(fit=True)
for row in qr.get_matrix(): print("".join("██" if c else "  " for c in row))
PYQR
}
setup_boot(){
    is_termux || { warn '开机自启目前仅针对 Termux。'; return 1; }; mkdir -p "$BOOT_DIR"; : > "$WATCHDOG_ENABLED"; rm -f "$MANUAL_STOP_FILE"
    cat > "$BOOT_FILE" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
sleep 15
$SHORTCUT --start >/dev/null 2>&1 || true
$SHORTCUT --watchdog >/dev/null 2>&1 &
EOF
    cat > "$WATCHDOG_FILE" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
while [ -f "$WATCHDOG_ENABLED" ]; do
    if [ ! -f "$MANUAL_STOP_FILE" ] && [ -x "$BINARY" ]; then
        if ! "$SHORTCUT" --status 2>/dev/null | grep -q '状态：.*运行中'; then "$SHORTCUT" --start >/dev/null 2>&1 || true; fi
    fi
    sleep 30
done
EOF
    chmod +x "$BOOT_FILE" "$WATCHDOG_FILE"; ok '已开启 Termux 开机自启 + OpenList 异常自动恢复。'; info '需要安装 Termux:Boot，并允许系统自启动/后台运行。'
}
remove_boot(){ is_termux || return 0; rm -f "$BOOT_FILE" "$WATCHDOG_FILE" "$WATCHDOG_ENABLED" "$MANUAL_STOP_FILE"; ok '已关闭 Termux 开机自启与异常自动恢复。'; }
install_service(){ systemd && root || return 0; cat > /etc/systemd/system/openlist-toolkit.service <<EOF
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
systemctl daemon-reload; systemctl enable openlist-toolkit.service >/dev/null 2>&1 || true; }
install_openlist(){
    mkdirs; local a o v target asset url tmp file; a="$(arch)"; o="$(os_name)"; [ "$a" != unsupported ] || { err "不支持的 CPU：$(uname -m)"; return 1; }; target=linux; [ "$o" = android ] && target=android
    v="$(upstream_version)"; [ -n "$v" ] || { err '无法获取 OpenList 最新版本，请检查网络。'; return 1; }; asset="openlist-${target}-${a}.tar.gz"; url="https://github.com/$UPSTREAM/releases/download/$v/$asset"; tmp="$(mktemp -d)"
    info "系统：$o  架构：$a  版本：$v"; if has curl; then curl -fL --retry 3 --connect-timeout 15 "$url" -o "$tmp/openlist.tar.gz" || { err '下载失败。'; rm -rf "$tmp"; return 1; }; elif has wget; then wget -q --show-progress "$url" -O "$tmp/openlist.tar.gz" || { err '下载失败。'; rm -rf "$tmp"; return 1; }; else err '需要 curl 或 wget。'; rm -rf "$tmp"; return 1; fi
    tar -xzf "$tmp/openlist.tar.gz" -C "$tmp" || { err '解压失败。'; rm -rf "$tmp"; return 1; }; file="$(find "$tmp" -type f -name openlist | head -n1)"; [ -n "$file" ] || { err '安装包中未找到 openlist。'; rm -rf "$tmp"; return 1; }
    running && stop_openlist >/dev/null 2>&1 || true; cp "$file" "$BINARY"; chmod +x "$BINARY"; "$BINARY" version >/dev/null 2>&1 || { err 'OpenList 可执行文件验证失败。'; rm -f "$BINARY"; rm -rf "$tmp"; return 1; }; printf '%s\n' "$v" > "$VERSION_FILE"; printf '%s\n' "$v" > "$VERSION_CACHE"; rm -rf "$tmp"; install_service; ok "OpenList $v 安装完成。"
}
update_openlist(){ [ -x "$BINARY" ] || { install_openlist; return; }; local cur latest; cur="$(cat "$VERSION_FILE" 2>/dev/null || true)"; latest="$(upstream_version)"; info "当前：${cur:-未知}  最新：${latest:-未知}"; [ -n "$latest" ] || { err '无法获取上游版本。'; return 1; }; [ "$cur" = "$latest" ] && { ok '已经是最新版本。'; return; }; install_openlist; }
offer_start_aria2_ariang(){
    [ -t 0 ] || return 0
    printf '是否同时启动 aria2 和 AriaNg？(y/n)：'
    read -r c
    [[ "$c" =~ ^[Yy]$ ]] || return 0
    echo
    info '正在启动 aria2...'
    start_aria2
    echo
    info '正在启动 AriaNg...'
    start_ariang
}
start_openlist(){
    rm -f "$MANUAL_STOP_FILE"; mkdirs; [ -x "$BINARY" ] || { err 'OpenList 尚未安装，请先选择 1。'; return 1; }
    if systemd && [ -f /etc/systemd/system/openlist-toolkit.service ]; then
        if systemctl start openlist-toolkit.service; then
            ok 'OpenList 已启动。'
            offer_start_aria2_ariang
        else
            err '启动失败，请查看日志。'
            return 1
        fi
        return
    fi
    running && { warn 'OpenList 已经在运行。'; return; }
    nohup "$BINARY" server --data "$DATA_DIR" >"$LOG_DIR/openlist.log" 2>&1 & local p=$!
    printf '%s\n' "$p" > "$PID_FILE"
    sleep 0.5
    if running; then
        ok "OpenList 已启动，PID：$p"
        offer_start_aria2_ariang
    else
        err '启动失败，请查看日志。'
        rm -f "$PID_FILE"
        return 1
    fi
}
stop_openlist(){
    : > "$MANUAL_STOP_FILE"
    if systemd && [ -f /etc/systemd/system/openlist-toolkit.service ]; then
        systemctl stop openlist-toolkit.service >/dev/null 2>&1 || true
    elif [ -f "$PID_FILE" ]; then
        local p="$(cat "$PID_FILE" 2>/dev/null || true)"
        [ -z "$p" ] || kill "$p" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    ok 'OpenList 已停止。'
    printf '是否同步停止 aria2 和 AriaNg？(y/n)：'
    read -r choice
    case "$choice" in
        y|Y)
            stop_ariang
            stop_aria2
            ;;
        n|N)
            info '已保留 aria2 和 AriaNg 运行。'
            ;;
        *)
            info '输入无效，已保留 aria2 和 AriaNg 运行。'
            ;;
    esac
}
restart_openlist(){ stop_openlist; start_openlist; }
setup_aria2(){
    if ! has aria2c; then if is_termux && has pkg; then pkg install -y aria2 || return 1; else err '未检测到 aria2c，请先安装 aria2。'; return 1; fi; fi
    mkdirs; if [ ! -f "$ARIA2_SECRET_FILE" ]; then printf '%b' "${CY}请输入 aria2 RPC 密钥：${R}"; read -r s; [ -n "$s" ] || s='change-me'; printf '%s\n' "$s" > "$ARIA2_SECRET_FILE"; chmod 600 "$ARIA2_SECRET_FILE"; fi
    local secret="$(cat "$ARIA2_SECRET_FILE")"; if [ ! -f "$ARIA2_CONF" ]; then cat > "$ARIA2_CONF" <<EOF
# aria2 configuration

EOF
        touch "$ARIA2_DIR/aria2.session"; chmod 600 "$ARIA2_CONF" "$ARIA2_DIR/aria2.session"; fi
}
start_aria2(){ setup_aria2 || return 1; aria2_running && { warn 'aria2 已运行。'; return; }; nohup aria2c --conf-path="$ARIA2_CONF" >"$ARIA2_LOG" 2>&1 & local p=$!; printf '%s\n' "$p" > "$ARIA2_PID_FILE"; sleep 0.5; aria2_running && ok "aria2 已启动，PID：$p" || { err 'aria2 启动失败。'; rm -f "$ARIA2_PID_FILE"; return 1; }; }
stop_aria2(){ if [ -f "$ARIA2_PID_FILE" ]; then local p="$(cat "$ARIA2_PID_FILE" 2>/dev/null || true)"; [ -z "$p" ] || kill "$p" 2>/dev/null || true; rm -f "$ARIA2_PID_FILE"; fi; ok 'aria2 已停止。'; }
start_ariang(){
    mkdirs
    if [ ! -s "$ARIANG_HTML" ]; then
        info '正在安装 AriaNg...'
        local url="https://github.com/$ARIANG_REPO/releases/latest/download/AriaNg.zip" tmp="$(mktemp -d)"
        if has curl; then curl -fL --retry 2 --connect-timeout 10 "$url" -o "$tmp/ariang.zip" || { rm -rf "$tmp"; err 'AriaNg 下载失败。'; return 1; }
        elif has wget; then wget -qO "$tmp/ariang.zip" "$url" || { rm -rf "$tmp"; err 'AriaNg 下载失败。'; return 1; }
        else rm -rf "$tmp"; err '需要 curl 或 wget。'; return 1; fi
        unzip -q "$tmp/ariang.zip" -d "$ARIANG_DIR" || { rm -rf "$tmp"; err 'AriaNg 解压失败。'; return 1; }
        rm -rf "$tmp"
    fi
    ariang_running && { warn 'AriaNg 已运行。'; return; }
    if has python3; then nohup python3 -m http.server "$ARIANG_PORT" --directory "$ARIANG_DIR" >"$ARIANG_LOG" 2>&1 & local p=$!; printf '%s\n' "$p" > "$ARIANG_PID_FILE"; elif has python; then nohup python -m http.server "$ARIANG_PORT" --directory "$ARIANG_DIR" >"$ARIANG_LOG" 2>&1 & local p=$!; printf '%s\n' "$p" > "$ARIANG_PID_FILE"; else err '未找到 Python，无法启动 AriaNg。'; return 1; fi
    sleep 0.5; ariang_running && ok "AriaNg 已启动：http://127.0.0.1:$ARIANG_PORT" || { err 'AriaNg 启动失败。'; rm -f "$ARIANG_PID_FILE"; return 1; }
}
stop_ariang(){ if [ -f "$ARIANG_PID_FILE" ]; then local p="$(cat "$ARIANG_PID_FILE" 2>/dev/null || true)"; [ -z "$p" ] || kill "$p" 2>/dev/null || true; rm -f "$ARIANG_PID_FILE"; fi; ok 'AriaNg 已停止。'; }
aria2_menu(){
    while true; do clear; line; center 'aria2 / AriaNg'; line; aria2_running && echo -e "aria2：${GR}运行中${R}" || echo -e "aria2：${RE}未运行${R}"; ariang_running && echo -e "AriaNg：${GR}运行中${R}" || echo -e "AriaNg：${RE}未运行${R}"; line; echo '1. 启动 aria2'; echo '2. 停止 aria2'; echo '3. 启动 AriaNg'; echo '4. 停止 AriaNg'; echo '5. 同时启动'; echo '6. 同时停止'; echo '0. 返回'; line; printf '请选择：'; read -r c; case "$c" in 1) start_aria2; pause_menu;; 2) stop_aria2; pause_menu;; 3) start_ariang; pause_menu;; 4) stop_ariang; pause_menu;; 5) start_aria2; start_ariang; pause_menu;; 6) stop_ariang; stop_aria2; pause_menu;; 0) break;; *) warn '无效选项。'; sleep 0.5;; esac; done
}
setup_cloudflare(){
    has cloudflared || { err '未安装 cloudflared。'; return 1; }
    mkdir -p "$CF_DIR"
    if [ ! -f "$CF_CONFIG" ]; then
        info '请执行 cloudflared tunnel login 完成授权后再继续。'
        return 1
    fi
    local name domain; printf 'Tunnel 名称：'; read -r name; [ -n "$name" ] || name="openlist"; printf '绑定域名：'; read -r domain; [ -n "$domain" ] || { err '域名不能为空。'; return 1; }
    cloudflared tunnel route dns "$name" "$domain" || return 1
    printf '%s\n' "$name" > "$TUNNEL_NAME_FILE"; printf '%s\n' "$domain" > "$DOMAIN_FILE"; ok 'Cloudflare Tunnel 配置完成。'
}
stop_cloudflare(){ pkill -f 'cloudflared.*tunnel.*run' 2>/dev/null || true; ok 'Cloudflare Tunnel 已停止。'; }
tunnel_logs(){ [ -f "$CF_LOG" ] && tail -n 100 "$CF_LOG" || warn '暂无 Cloudflare Tunnel 日志。'; }
backup_data(){ mkdirs; local stamp="$HOME/OpenList-Backups/openlist-$(date +%Y%m%d-%H%M%S).tar.gz"; tar -czf "$stamp" -C "$HOME_DIR" data 2>/dev/null && ok "备份完成：$stamp" || { err '备份失败。'; return 1; }; }
restore_data(){
    local file; printf '请输入备份文件路径：'; read -r file; [ -f "$file" ] || { err '备份文件不存在。'; return 1; }; mkdirs; tar -xzf "$file" -C "$HOME_DIR" || { err '还原失败。'; return 1; }; ok '数据还原完成。'
}
setup_nightly(){
    if systemd && root; then
        cat > /etc/systemd/system/openlist-toolkit-nightly.service <<EOF
[Unit]
Description=OpenList Toolkit nightly update
[Service]
Type=oneshot
ExecStart=$SHORTCUT --update
EOF
        cat > /etc/systemd/system/openlist-toolkit-nightly.timer <<EOF
[Unit]
Description=OpenList Toolkit nightly timer
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
        systemctl daemon-reload; systemctl enable --now openlist-toolkit-nightly.timer; ok '已开启每日自动更新。'
    else
        warn '当前环境不支持 systemd 定时任务。'
    fi
}
remove_nightly(){ if systemd && root; then systemctl disable --now openlist-toolkit-nightly.timer >/dev/null 2>&1 || true; rm -f /etc/systemd/system/openlist-toolkit-nightly.service /etc/systemd/system/openlist-toolkit-nightly.timer; systemctl daemon-reload; ok '已关闭每日自动更新。'; else warn '当前环境不支持 systemd 定时任务。'; fi; }
self_update(){
    local remote_content remote_hash local_hash src
    src="${BASH_SOURCE[0]}"
    remote_content="$(toolkit_remote_code)"
    [ -n "$remote_content" ] || { err '无法获取 GitHub main 最新 Toolkit。'; return 1; }
    remote_hash="$(toolkit_hash "$remote_content")"
    local_hash="$(toolkit_hash "$(toolkit_local_code)")"
    [ -n "$remote_hash" ] || { err '无法计算远程 Toolkit 哈希。'; return 1; }
    if [ "$remote_hash" = "$local_hash" ]; then
        info "当前 Toolkit：$(toolkit_build_id)"
        ok 'Toolkit 已是最新版本。'
        return 0
    fi
    info '正在与 GitHub main 分支比对 Toolkit 代码...'
    apply_toolkit_code "$remote_content" "$remote_hash" || return 1
    info '请重新运行 oplist 以加载最新 Toolkit。'
}
auto_update_toolkit(){
    [ -t 0 ] || return 0
    local src remote_content remote_hash local_hash last_synced choice
    src="${BASH_SOURCE[0]}"
    [ -f "$src" ] || return 0
    remote_content="$(toolkit_remote_code)"
    [ -n "$remote_content" ] || return 0
    remote_hash="$(toolkit_hash "$remote_content")"
    local_hash="$(toolkit_hash "$(toolkit_local_code)")"
    [ -n "$remote_hash" ] && [ "$remote_hash" = "$local_hash" ] && return 0
    last_synced="$(cat "$TOOLKIT_SYNCED_HASH_FILE" 2>/dev/null || true)"
    if [ -n "$last_synced" ] && [ "$local_hash" != "$last_synced" ]; then
        warn '检测到本地 Toolkit 代码被手动修改，已跳过自动同步（避免覆盖你的改动）。'
        return 0
    fi
    echo
    warn '检测到 GitHub main 分支的 Toolkit 代码已更新。'
    printf '是否立即同步最新代码？(Y/n)：'
    read -r choice
    case "$choice" in n|N) return 0;; esac
    info '正在与 GitHub main 分支比对 Toolkit 代码...'
    apply_toolkit_code "$remote_content" "$remote_hash"
    echo
    info '请重新运行 oplist 以加载最新 Toolkit。'
}
menu(){
    while true; do clear; local cur latest; cur="$(cat "$VERSION_FILE" 2>/dev/null || true)"; latest="$(latest_version)"; line; center 'OpenList Toolkit'; center "Toolkit：$(toolkit_build_id)"; line
        printf '%b系统%b：%s   %b架构%b：%s\n' "$CY" "$R" "$(os_name)" "$CY" "$R" "$(arch)"; if [ -n "$cur" ]; then echo -e "${CY}OpenList${R}：$cur → 最新 ${latest:-未知}"; else echo -e "${CY}OpenList${R}：${YE}未安装${R} → 最新 ${latest:-未知}"; fi
        running && echo -e "${CY}OpenList 状态${R}：${GR}运行中${R}" || echo -e "${CY}OpenList 状态${R}：${RE}未运行${R}"; aria2_running && echo -e "${CY}aria2 状态${R}：${GR}运行中${R}" || echo -e "${CY}aria2 状态${R}：${RE}未运行${R}"; ariang_running && echo -e "${CY}AriaNg 状态${R}：${GR}运行中${R}" || echo -e "${CY}AriaNg 状态${R}：${RE}未运行${R}"; tunnel_running && echo -e "${CY}Cloudflare Tunnel 状态${R}：${GR}运行中${R}" || echo -e "${CY}Cloudflare Tunnel 状态${R}：${RE}未运行${R}"
        if running; then echo "本机访问：http://127.0.0.1:$LOCAL_PORT"; while IFS="|" read -r iface ip; do [ -n "$ip" ] || continue; case "$iface" in ap*) echo "热点访问：http://$ip:$LOCAL_PORT";; wlan*) echo "Wi-Fi访问：http://$ip:$LOCAL_PORT";; *) echo "局域网访问：http://$ip:$LOCAL_PORT";; esac; done <<EOF
$(local_ips)
EOF
        fi
        line; echo '1. 安装 OpenList'; echo '2. 更新 OpenList'; echo '3. 启动 OpenList'; echo '4. 停止 OpenList'; echo '5. 重启 OpenList'; echo '6. 查看 OpenList 日志'; echo '7. 备份数据'; echo '8. aria2 管理'; echo '9. 更多功能'; echo '0. 退出'; line; printf '请选择：'; read -r c; echo
        case "$c" in 1) install_openlist; pause_menu;; 2) update_openlist; pause_menu;; 3) start_openlist; pause_menu;; 4) stop_openlist; pause_menu;; 5) restart_openlist; pause_menu;; 6) logs; pause_menu;; 7) backup_data; pause_menu;; 8) aria2_menu;; 9) more;; 0) exit 0;; *) warn '无效选项。'; sleep 0.5;; esac
    done
}
logs(){ if systemd && [ -f /etc/systemd/system/openlist-toolkit.service ]; then journalctl -u openlist-toolkit.service -n 100 --no-pager; elif [ -f "$LOG_DIR/openlist.log" ]; then tail -n 100 "$LOG_DIR/openlist.log"; else warn '暂无 OpenList 日志。'; fi; }
more(){
    while true; do clear; line; center '更多功能'; line
        echo '1. 修改 OpenList 密码'; echo '2. 编辑 OpenList 配置文件'; echo '3. 更新管理脚本'; echo '4. 备份/还原 OpenList 数据'; echo '5. 开启 OpenList 外网访问'; echo '6. 停止 OpenList 外网访问'; echo '7. 查看 Cloudflare Tunnel 日志'; echo '8. 开启每日自动更新'; echo '9. 关闭每日自动更新'; echo '10. 网络访问地址 / IP 检测'; echo '11. 生成 OpenList 访问二维码'; echo '12. 环境与依赖检查'; echo '13. 开启开机自启 + 异常自动恢复'; echo '14. 关闭开机自启 + 异常自动恢复'; echo '0. 返回主菜单'; line; printf '请输入选项 (0-14)：'; read -r c
        case "$c" in 1) reset_password; pause_menu;; 2) edit_openlist_config; pause_menu;; 3) self_update; pause_menu;; 4) clear; echo '1. 备份'; echo '2. 还原'; printf '请选择：'; read -r b; case "$b" in 1) backup_data;; 2) restore_data;; esac; pause_menu;; 5) setup_cloudflare; pause_menu;; 6) stop_cloudflare; pause_menu;; 7) clear; tunnel_logs; pause_menu;; 8) setup_nightly; pause_menu;; 9) remove_nightly; pause_menu;; 10) clear; network_status; pause_menu;; 11) clear; show_qr; pause_menu;; 12) clear; check_environment; pause_menu;; 13) setup_boot; pause_menu;; 14) remove_boot; pause_menu;; 0) break;; *) warn '无效选项。'; sleep 0.5;; esac
    done
}
mkdirs
check_version_bg
if [ "${1:-}" = "--watchdog" ]; then
    while [ -f "$WATCHDOG_ENABLED" ]; do
        if [ ! -f "$MANUAL_STOP_FILE" ] && [ -x "$BINARY" ]; then
            if ! running; then "$SHORTCUT" --start >/dev/null 2>&1 || true; fi
        fi
        sleep 30
    done
    exit 0
fi
case "${1:-}" in
    --start) start_openlist;;
    --stop) stop_openlist;;
    --restart) restart_openlist;;
    --status) running && echo '状态：运行中' || echo '状态：未运行';;
    --update) update_openlist;;
    --self-update|--update-toolkit) self_update;;
    --watchdog) ;;
    *) auto_update_toolkit; menu;;
esac
