#!/usr/bin/env bash
# ==============================================================================
# scripts/litellm-service.sh: LiteLLM 本地网关常驻后台守护服务管理器
# 支持常驻后台运行 (Daemon)、系统自启 (macOS LaunchAgent / Linux systemd)、探活与日志
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PORT="${LITELLM_PORT:-4000}"
CONFIG_FILE="${LITELLM_CONFIG:-${REPO_ROOT}/configs/litellm.yaml}"
RUN_DIR="${REPO_ROOT}/.litellm"
PID_FILE="${RUN_DIR}/litellm.pid"
LOG_FILE="${RUN_DIR}/litellm.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[litellm-service]${NC} $1"; }
log_success() { echo -e "${GREEN}[litellm-service]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[litellm-service]${NC} $1"; }
log_error() { echo -e "${RED}[litellm-service]${NC} $1" >&2; }

usage() {
    cat <<EOF
LiteLLM 本地网关后台守护服务管理器

用法:
  $0 start              在后台启动网关服务 (常驻守护模式)
  $0 stop               停止后台网关服务
  $0 restart            重启后台网关服务
  $0 status             检查服务运行状态与健康探活
  $0 logs               实时查看网关服务运行日志
  $0 install-daemon     注册为系统级开机自启常驻服务 (macOS LaunchAgent / Linux systemd)
  $0 uninstall-daemon   卸载开机自启常驻服务

环境与配置:
  端口:   ${PORT} (可通过 LITELLM_PORT 覆盖)
  配置:   ${CONFIG_FILE}
  日志:   ${LOG_FILE}
EOF
    exit 1
}

find_litellm_bin() {
    if command -v litellm >/dev/null 2>&1; then
        command -v litellm
    elif [ -x "${HOME}/.local/bin/litellm" ]; then
        echo "${HOME}/.local/bin/litellm"
    else
        log_error "未找到 litellm 可执行文件。请先运行: uv tool install 'litellm[proxy]'"
        exit 1
    fi
}

is_port_listening() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1
    elif command -v nc >/dev/null 2>&1; then
        nc -z 127.0.0.1 "${PORT}" >/dev/null 2>&1
    else
        curl -s -m 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1
    fi
}

cmd_start() {
    mkdir -p "${RUN_DIR}"

    if is_port_listening; then
        log_warn "端口 :${PORT} 已被占用，网关已在运行中。"
        cmd_status
        return 0
    fi

    local bin
    bin="$(find_litellm_bin)"

    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "配置文件不存在: ${CONFIG_FILE}"
        exit 1
    fi

    log_info "正在后台启动 LiteLLM 常驻服务 (端口 :${PORT})..."
    nohup "${bin}" --config "${CONFIG_FILE}" --port "${PORT}" > "${LOG_FILE}" 2>&1 &
    local new_pid=$!
    echo "${new_pid}" > "${PID_FILE}"

    # 等待端口就绪与探活验证
    local ready=0
    for _ in {1..15}; do
        if is_port_listening; then
            ready=1
            break
        fi
        sleep 0.5
    done

    if [ "${ready}" -eq 1 ]; then
        log_success "LiteLLM 网关已成功常驻后台运行 (PID: ${new_pid}, 端口 :${PORT})"
        log_info "日志输出: ${LOG_FILE}"
    else
        log_error "网关未能成功启动，请查看日志: ${LOG_FILE}"
        tail -n 20 "${LOG_FILE}" || true
        exit 1
    fi
}

cmd_stop() {
    local target_pid=""
    if [ -f "${PID_FILE}" ]; then
        target_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
    fi

    if [ -z "${target_pid}" ] && command -v lsof >/dev/null 2>&1; then
        target_pid="$(lsof -ti ":${PORT}" 2>/dev/null || true)"
    fi

    if [ -z "${target_pid}" ]; then
        log_warn "未发现运行中的 LiteLLM 网关服务。"
        rm -f "${PID_FILE}"
        return 0
    fi

    log_info "正在停止 LiteLLM 网关服务 (PID: ${target_pid})..."
    kill "${target_pid}" 2>/dev/null || true

    for _ in {1..10}; do
        if ! kill -0 "${target_pid}" 2>/dev/null; then
            break
        fi
        sleep 0.5
    done

    if kill -0 "${target_pid}" 2>/dev/null; then
        log_warn "服务未正常响应 SIGTERM，尝试强制退出..."
        kill -9 "${target_pid}" 2>/dev/null || true
    fi

    rm -f "${PID_FILE}"
    log_success "LiteLLM 网关服务已停止。"
}

cmd_restart() {
    cmd_stop
    sleep 1
    cmd_start
}

cmd_status() {
    local status_text="未运行"
    local pid_info="无"

    if [ -f "${PID_FILE}" ]; then
        local p
        p="$(cat "${PID_FILE}" 2>/dev/null || true)"
        if [ -n "${p}" ] && kill -0 "${p}" 2>/dev/null; then
            pid_info="${p}"
        fi
    fi

    if [ "${pid_info}" = "无" ] && command -v lsof >/dev/null 2>&1; then
        local p
        p="$(lsof -ti ":${PORT}" 2>/dev/null || true)"
        if [ -n "${p}" ]; then
            pid_info="${p} (端口检测)"
        fi
    fi

    local health="不可达"
    if is_port_listening; then
        status_text="运行中 (端口 :${PORT} 监听)"
        if curl -s -m 2 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
            health="正常 (HTTP 200)"
        else
            health="端口已监听 (探活响应中)"
        fi
    fi

    echo "================================================================================"
    echo "  LiteLLM 网关守护状态:"
    echo "  - 状态:       ${status_text}"
    echo "  - PID:        ${pid_info}"
    echo "  - 端口:       ${PORT}"
    echo "  - 探活:       ${health}"
    echo "  - 配置文件:   ${CONFIG_FILE}"
    echo "  - 日志文件:   ${LOG_FILE}"
    echo "================================================================================"
}

cmd_logs() {
    if [ ! -f "${LOG_FILE}" ]; then
        log_warn "暂无日志文件: ${LOG_FILE}"
        return 0
    fi
    log_info "正在查看实时日志 (Ctrl+C 退出)..."
    tail -n 50 -f "${LOG_FILE}"
}

cmd_install_daemon() {
    local bin
    bin="$(find_litellm_bin)"
    mkdir -p "${RUN_DIR}"

    if [ "$(uname -s)" = "Darwin" ]; then
        local plist_dir="${HOME}/Library/LaunchAgents"
        local plist_file="${plist_dir}/com.10x.litellm.plist"
        mkdir -p "${plist_dir}"

        log_info "正在生成 macOS LaunchAgent 用户自启配置: ${plist_file}..."
        cat <<EOF > "${plist_file}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.10x.litellm</string>
    <key>ProgramArguments</key>
    <array>
        <string>${bin}</string>
        <string>--config</string>
        <string>${CONFIG_FILE}</string>
        <string>--port</string>
        <string>${PORT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>
    <key>WorkingDirectory</key>
    <string>${REPO_ROOT}</string>
</dict>
</plist>
EOF
        launchctl unload "${plist_file}" 2>/dev/null || true
        launchctl load -w "${plist_file}"
        log_success "macOS LaunchAgent 常驻守护服务已注册并激活！开机/登录后自动常驻后台运行。"
        log_info "状态管理: launchctl list | grep com.10x.litellm"
    elif [ "$(uname -s)" = "Linux" ]; then
        local service_dir="${HOME}/.config/systemd/user"
        local service_file="${service_dir}/litellm.service"
        mkdir -p "${service_dir}"

        log_info "正在生成 Linux systemd 用户级守护配置: ${service_file}..."
        cat <<EOF > "${service_file}"
[Unit]
Description=10x LiteLLM Universal Model Gateway
After=network.target

[Service]
Type=simple
ExecStart=${bin} --config ${CONFIG_FILE} --port ${PORT}
WorkingDirectory=${REPO_ROOT}
Restart=always
RestartSec=5
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=default.target
EOF
        systemctl --user daemon-reload
        systemctl --user enable --now litellm
        log_success "Linux systemd 用户级守护服务已激活！开机登录自动常驻后台运行。"
        log_info "状态管理: systemctl --user status litellm"
    else
        log_warn "暂不支持当前操作系统的系统级自启注册，请使用 '$0 start' 后台常驻模式。"
    fi
}

cmd_uninstall_daemon() {
    if [ "$(uname -s)" = "Darwin" ]; then
        local plist_file="${HOME}/Library/LaunchAgents/com.10x.litellm.plist"
        if [ -f "${plist_file}" ]; then
            launchctl unload "${plist_file}" 2>/dev/null || true
            rm -f "${plist_file}"
            log_success "已注销并清理 macOS LaunchAgent 常驻守护配置。"
        else
            log_warn "未检测到已安装的 LaunchAgent 服务。"
        fi
    elif [ "$(uname -s)" = "Linux" ]; then
        local service_file="${HOME}/.config/systemd/user/litellm.service"
        if [ -f "${service_file}" ]; then
            systemctl --user stop litellm 2>/dev/null || true
            systemctl --user disable litellm 2>/dev/null || true
            rm -f "${service_file}"
            systemctl --user daemon-reload
            log_success "已注销并清理 Linux systemd 常驻守护配置。"
        else
            log_warn "未检测到已安装的 systemd 服务。"
        fi
    fi
}

case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    install-daemon)
        cmd_install_daemon
        ;;
    uninstall-daemon)
        cmd_uninstall_daemon
        ;;
    *)
        usage
        ;;
esac
