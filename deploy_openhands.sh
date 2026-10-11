#!/usr/bin/env bash
# ==============================================================================
# OpenHands 一键部署与运维管理脚本
# 数据卷目录: ~/volumes/openhands/
# ==============================================================================

set -euo pipefail

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 默认配置（可通过环境变量或传入参数覆盖）
# ------------------------------------------------------------------------------
CONTAINER_NAME="${OPENHANDS_CONTAINER_NAME:-openhands-app}"
IMAGE_NAME="${OPENHANDS_IMAGE:-docker.openhands.dev/openhands/openhands:latest}"
AGENT_SERVER_REPO="${AGENT_SERVER_IMAGE_REPOSITORY:-ghcr.io/openhands/agent-server}"
AGENT_SERVER_TAG="${AGENT_SERVER_IMAGE_TAG:-1.26.0-python}"
PORT="${OPENHANDS_PORT:-3000}"
DOCKER_NETWORK="${OPENHANDS_NETWORK:-}"

# 卷根目录
VOLUME_BASE="${OPENHANDS_VOLUME_DIR:-$HOME/volumes/openhands}"
STATE_DIR="${VOLUME_BASE}/state"
WORKSPACE_DIR="${OPENHANDS_WORKSPACE:-$VOLUME_BASE/workspace}"
SKILLS_DIR="${VOLUME_BASE}/skills"
COMPOSE_FILE="${VOLUME_BASE}/docker-compose.yml"

# Docker Socket 路径检测
if [ -S "/var/run/docker.sock" ]; then
    DOCKER_SOCK="/var/run/docker.sock"
elif [ -S "$HOME/.docker/run/docker.sock" ]; then
    DOCKER_SOCK="$HOME/.docker/run/docker.sock"
else
    DOCKER_SOCK="/var/run/docker.sock"
fi

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# ------------------------------------------------------------------------------
# 环境预检
# ------------------------------------------------------------------------------
check_prerequisites() {
    log_info "正在检查运行环境依赖..."

    # 1. 检查 docker CLI 是否安装
    if ! command -v docker >/dev/null 2>&1; then
        log_error "未检测到 Docker，请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop/"
        exit 1
    fi

    # 2. 检查 Docker Daemon 是否在运行
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker 服务未运行！"
        if [ "$(uname)" = "Darwin" ] && [ -d "/Applications/Docker.app" ]; then
            log_info "正在尝试启动 Docker Desktop..."
            open -a Docker
            log_info "等待 Docker 启动 (最多等待 45 秒)..."
            for i in {1..45}; do
                if docker info >/dev/null 2>&1; then
                    log_success "Docker 已就绪！"
                    break
                fi
                sleep 1
            done
            if ! docker info >/dev/null 2>&1; then
                log_error "Docker 启动超时，请手动打开 Docker Desktop 后重试。"
                exit 1
            fi
        else
            log_error "请先启动 Docker 守护进程再运行此脚本。"
            exit 1
        fi
    fi

    # 3. 检查 Docker Socket 访问权限
    if [ ! -r "$DOCKER_SOCK" ] && [ ! -w "$DOCKER_SOCK" ] && [ ! -S "$DOCKER_SOCK" ]; then
        log_warn "Docker Socket 路径 [$DOCKER_SOCK] 可能权限不足，如果遇到权限问题，请确保当前用户拥有读写权限。"
    fi

    log_success "环境检查通过 (Docker 已就绪)"
}

# ------------------------------------------------------------------------------
# 准备持久化目录
# ------------------------------------------------------------------------------
init_directories() {
    log_info "初始化数据卷目录: ${VOLUME_BASE}"
    mkdir -p "${STATE_DIR}" "${WORKSPACE_DIR}" "${SKILLS_DIR}"
    chmod -R 755 "${VOLUME_BASE}"
    log_success "目录创建完成:"
    echo "  - 状态配置卷: ${STATE_DIR}"
    echo "  - 项目工作区: ${WORKSPACE_DIR}"
    echo "  - 自定义技能: ${SKILLS_DIR}"
}

# ------------------------------------------------------------------------------
# 生成 docker-compose.yml 配置文件 (方便后续管理)
# ------------------------------------------------------------------------------
generate_compose_file() {
    log_info "生成 Docker Compose 模板文件: ${COMPOSE_FILE}"
    cat <<EOF > "${COMPOSE_FILE}"
services:
  openhands:
    image: ${IMAGE_NAME}
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${PORT}:3000"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - SANDBOX_USER_ID=$(id -u)
      - AGENT_SERVER_IMAGE_REPOSITORY=${AGENT_SERVER_REPO}
      - AGENT_SERVER_IMAGE_TAG=${AGENT_SERVER_TAG}
      - LOG_ALL_EVENTS=true
      - WORKSPACE_BASE=${WORKSPACE_DIR}
      - SANDBOX_VOLUMES=${WORKSPACE_DIR}:/workspace:rw,${SKILLS_DIR}:/home/openhands/.agents/skills:ro
    volumes:
      - ${DOCKER_SOCK}:/var/run/docker.sock
      - ${STATE_DIR}:/.openhands
      - ${WORKSPACE_DIR}:/workspace
      - ${SKILLS_DIR}:/home/openhands/.agents/skills:ro
EOF
    log_success "Docker Compose 文件已生成。"
}

# ------------------------------------------------------------------------------
# 启动 OpenHands
# ------------------------------------------------------------------------------
start_openhands() {
    check_prerequisites
    init_directories
    generate_compose_file

    # 检查是否有同名容器在运行
    if docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        log_warn "容器 [${CONTAINER_NAME}] 已在运行中！"
        show_status
        return 0
    fi

    # 清理已停止的同名容器
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        log_info "发现已停止的历史容器 [${CONTAINER_NAME}]，正在清理..."
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    fi

    # 检查端口占用
    if lsof -Pi :${PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warn "本地端口 ${PORT} 已被占用，可能导致启动冲突！"
    fi

    log_info "拉取 OpenHands 镜像: ${IMAGE_NAME} ..."
    docker pull "${IMAGE_NAME}" || log_warn "拉取最新镜像失败，尝试使用本地已有镜像..."

    # 如果指定了自定义 Docker 网络，则确保网络存在
    if [ -n "${DOCKER_NETWORK}" ]; then
        if ! docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1; then
            log_info "创建 Docker 网络: ${DOCKER_NETWORK}"
            docker network create "${DOCKER_NETWORK}"
        fi
    fi
    log_info "正在启动 OpenHands 容器..."

    # 构建启动命令参数数组
    DOCKER_CMD=(
        docker run -d
        --name "${CONTAINER_NAME}"
        --restart unless-stopped
        -p "${PORT}:3000"
        -e "SANDBOX_USER_ID=$(id -u)"
        -e "AGENT_SERVER_IMAGE_REPOSITORY=${AGENT_SERVER_REPO}"
        -e "AGENT_SERVER_IMAGE_TAG=${AGENT_SERVER_TAG}"
        -e "LOG_ALL_EVENTS=true"
        -e "WORKSPACE_BASE=${WORKSPACE_DIR}"
        -e "SANDBOX_VOLUMES=${WORKSPACE_DIR}:/workspace:rw,${SKILLS_DIR}:/home/openhands/.agents/skills:ro"
        -v "${DOCKER_SOCK}:/var/run/docker.sock"
        -v "${STATE_DIR}:/.openhands"
        -v "${WORKSPACE_DIR}:/workspace"
        -v "${SKILLS_DIR}:/home/openhands/.agents/skills:ro"
        --add-host host.docker.internal:host-gateway
    )

    # 若指定了自定义网络，加入网络支持容器间互通（如 openclaw）
    if [ -n "${DOCKER_NETWORK}" ]; then
        DOCKER_CMD+=(--network "${DOCKER_NETWORK}")
    fi

    # 注入可选环境变量（如已在宿主机设置了 LLM 配置）
    if [ -n "${LLM_BASE_URL:-}" ]; then
        DOCKER_CMD+=(-e "LLM_BASE_URL=${LLM_BASE_URL}")
    fi
    if [ -n "${LLM_MODEL:-}" ]; then
        DOCKER_CMD+=(-e "LLM_MODEL=${LLM_MODEL}")
    fi
    if [ -n "${LLM_API_KEY:-}" ]; then
        DOCKER_CMD+=(-e "LLM_API_KEY=${LLM_API_KEY}")
    fi

    DOCKER_CMD+=("${IMAGE_NAME}")

    # 执行启动
    "${DOCKER_CMD[@]}"

    log_success "OpenHands 已成功启动！"
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e " 🚀 访问地址: ${GREEN}http://localhost:${PORT}${NC}"
    echo -e " 📂 状态数据: ${CYAN}${STATE_DIR}${NC}"
    echo -e " 💻 默认工作区: ${CYAN}${WORKSPACE_DIR}${NC}"
    echo -e " 🧩 技能扩展区: ${CYAN}${SKILLS_DIR}${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    echo -e "使用建议:"
    echo -e " 1. 打开浏览器访问 http://localhost:${PORT} ，初次进入点击设置配置你的 LLM 模型与 API Key。"
    echo -e " 2. 如需连接宿主机本地模型（如 LMStudio/Ollama），Base URL 填: ${YELLOW}http://host.docker.internal:1234/v1${NC} 或相应端口。"
    echo -e " 3. 查看实时日志命令: ${CYAN}$0 logs${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# 停止容器
# ------------------------------------------------------------------------------
stop_openhands() {
    log_info "正在停止 OpenHands 容器 [${CONTAINER_NAME}]..."
    if docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        docker stop "${CONTAINER_NAME}"
        log_success "容器已停止。"
    else
        log_warn "容器 [${CONTAINER_NAME}] 未在运行。"
    fi
}

# ------------------------------------------------------------------------------
# 移除容器
# ------------------------------------------------------------------------------
down_openhands() {
    log_info "正在停止并删除 OpenHands 容器 [${CONTAINER_NAME}]..."
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        docker rm -f "${CONTAINER_NAME}"
        log_success "容器已移除。（持久化数据保留在 ${VOLUME_BASE}）"
    else
        log_warn "未找到容器 [${CONTAINER_NAME}]。"
    fi
}

# ------------------------------------------------------------------------------
# 查看状态
# ------------------------------------------------------------------------------
show_status() {
    echo -e "\n${BLUE}=== OpenHands 容器状态 ===${NC}"
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        docker ps -a --filter "name=^${CONTAINER_NAME}\$" --format "ID: \t{{.ID}}\n状态: \t{{.Status}}\n端口: \t{{.Ports}}\n镜像: \t{{.Image}}"
    else
        echo -e "${YELLOW}未检测到名为 [${CONTAINER_NAME}] 的容器。${NC}"
    fi

    echo -e "\n${BLUE}=== 数据卷目录信息 ===${NC}"
    if [ -d "${VOLUME_BASE}" ]; then
        ls -ld "${VOLUME_BASE}" "${STATE_DIR}" "${WORKSPACE_DIR}" "${SKILLS_DIR}" 2>/dev/null || true
    else
        echo "数据卷目录尚未创建: ${VOLUME_BASE}"
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# 查看日志
# ------------------------------------------------------------------------------
show_logs() {
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        docker logs -f --tail 100 "${CONTAINER_NAME}"
    else
        log_error "容器 [${CONTAINER_NAME}] 不存在。"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 帮助信息
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
OpenHands 一键部署运维脚本

用法:
  $0 [命令]

可用命令:
  start          [默认] 检查环境、初始化卷目录并启动 OpenHands
  stop           停止运行中的 OpenHands 容器
  restart        重启 OpenHands 容器
  status         查看当前容器运行状态及卷信息
  logs           实时查看 OpenHands 运行日志
  down           停止并删除容器（数据卷保留）
  help           显示此帮助信息

环境变量配置项 (可选):
  OPENHANDS_PORT            指定 Web 端口 (默认: 3000)
  OPENHANDS_VOLUME_DIR      指定卷根路径 (默认: ~/volumes/openhands)
  OPENHANDS_WORKSPACE       指定宿主机项目挂载目录 (默认: ~/volumes/openhands/workspace)
  OPENHANDS_IMAGE           指定镜像名称 (默认: docker.openhands.dev/openhands/openhands:latest)
  OPENHANDS_NETWORK         指定 Docker 网络名称 (例如: 与 openclaw 共享同一个 network)
  LLM_BASE_URL              预设 LLM API 基础地址 (例如: http://host.docker.internal:1234/v1)
  LLM_MODEL                 预设 LLM 模型名 (例如: openai/qwen2.5-coder-32b-instruct)
  LLM_API_KEY               预设 LLM API Key

示例:
  # 默认部署 (卷在 ~/volumes/openhands)
  ./deploy_openhands.sh

  # 自定义端口和挂载当前代码仓库为 workspace
  OPENHANDS_PORT=3001 OPENHANDS_WORKSPACE="\$(pwd)" ./deploy_openhands.sh

EOF
}

# ------------------------------------------------------------------------------
# 主流程分发
# ------------------------------------------------------------------------------
ACTION="${1:-start}"

case "${ACTION}" in
    start)
        start_openhands
        ;;
    stop)
        stop_openhands
        ;;
    restart)
        log_info "正在重启 OpenHands..."
        stop_openhands
        start_openhands
        ;;
    down|clean)
        down_openhands
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "未知命令: ${ACTION}"
        show_help
        exit 1
        ;;
esac
