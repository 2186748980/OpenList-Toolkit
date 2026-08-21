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
    printf '是否同步停止 aria2 和 AriaNg？(y/n，默认 n)：'
    read -r choice
    case "$choice" in
        y|Y)
            stop_ariang
            stop_aria2
            ;;
        n|N|'')
            info '已保留 aria2 和 AriaNg 运行。'
            ;;
        *)
            warn '输入无效，已保留 aria2 和 AriaNg 运行。'
            ;;
    esac
}
restart_openlist(){ stop_openlist; start_openlist; }
setup_aria2(){