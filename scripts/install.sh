#!/usr/bin/env bash
# ==============================================================================
# scripts/install.sh - AI-Native 全生命周期研发套件一键安装部署脚本
# 
# 用法:
#   ./scripts/install.sh /path/to/my-project
#   ./scripts/install.sh /path/to/my-project --mode=solo       # 仅安装个人版
#   ./scripts/install.sh /path/to/my-project --mode=full       # 全量安装方案一与方案二 (默认)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[install]${NC} $1"; }
log_success() { echo -e "${GREEN}[install]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[install]${NC} $1"; }
log_error() { echo -e "${RED}[install]${NC} $1" >&2; }

usage() {
    cat <<EOF
AI-Native 全生命周期研发套件一键部署工具

用法:
  $0 <目标工程路径> [--mode=full|solo]

参数说明:
  目标工程路径   待接入 AI-Native 研发能力的外部项目根目录
  --mode=full    全量安装：主控状态机调度器 + MCP 矩阵服务 + Solo 工作车间 (默认)
  --mode=solo    轻量安装：仅安装 Solo Worktree 并行调度器与配置

示例:
  $0 /path/to/my-backend-app
  $0 ../another-service --mode=full
EOF
    exit 1
}

# 1. 参数解析
TARGET_DIR="${1:-}"
MODE="full"

if [ -z "${TARGET_DIR}" ] || [[ "${TARGET_DIR}" =~ ^- ]]; then
    usage
fi

for arg in "$@"; do
    case "$arg" in
        --mode=solo)
            MODE="solo"
            ;;
        --mode=full)
            MODE="full"
            ;;
        --help|-h)
            usage
            ;;
    esac
done

TARGET_DIR="$(cd "${TARGET_DIR}" 2>/dev/null && pwd || echo "${TARGET_DIR}")"

if [ ! -d "${TARGET_DIR}" ]; then
    log_warn "目标目录不存在，正在自动创建: ${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
fi

log_info "==> 开始向目标项目注入 AI-Native 研发套件..."
log_info "    来源代码仓: ${SOURCE_ROOT}"
log_info "    目标工程路径: ${TARGET_DIR}"
log_info "    安装模式: [${MODE}]"

# 2. 基础目录初始化
mkdir -p "${TARGET_DIR}/scripts"
mkdir -p "${TARGET_DIR}/tasks"
mkdir -p "${TARGET_DIR}/configs"

# 3. 部署双阶段审查与通用脚本
log_info "--> 部署通用脚本..."
cp "${SOURCE_ROOT}/scripts/audit-diffs.sh" "${TARGET_DIR}/scripts/"
chmod +x "${TARGET_DIR}/scripts/audit-diffs.sh"

# 4. 根据模式分流安装
if [ "${MODE}" = "full" ] || [ "${MODE}" = "solo" ]; then
    log_info "--> 部署 Solo 版 Git Worktree 调度器与 LiteLLM 服务管理脚本..."
    cp "${SOURCE_ROOT}/scripts/solo-worktree.sh" "${TARGET_DIR}/scripts/"
    chmod +x "${TARGET_DIR}/scripts/solo-worktree.sh"
    cp "${SOURCE_ROOT}/scripts/litellm-service.sh" "${TARGET_DIR}/scripts/"
    chmod +x "${TARGET_DIR}/scripts/litellm-service.sh"
    
    mkdir -p "${TARGET_DIR}/configs"
    cp "${SOURCE_ROOT}/configs/litellm.yaml" "${TARGET_DIR}/configs/"
    cp "${SOURCE_ROOT}/configs/.aider.conf.yml" "${TARGET_DIR}/configs/"
    cp "${SOURCE_ROOT}/configs/docker-compose.yml" "${TARGET_DIR}/configs/"
fi

if [ "${MODE}" = "full" ]; then
    log_info "--> 部署方案一: 主控状态机调度器 (supervisor.py)..."
    cp "${SOURCE_ROOT}/scripts/supervisor.py" "${TARGET_DIR}/scripts/"
    chmod +x "${TARGET_DIR}/scripts/supervisor.py"

    log_info "--> 部署方案一: MCP 服务矩阵 (mcp_servers/)..."
    mkdir -p "${TARGET_DIR}/mcp_servers"
    cp -r "${SOURCE_ROOT}/mcp_servers/." "${TARGET_DIR}/mcp_servers/"
    chmod +x "${TARGET_DIR}/mcp_servers/"*.py

    log_info "--> 部署任务契约规范模板 (tasks/template.md)..."
    cp "${SOURCE_ROOT}/tasks/template.md" "${TARGET_DIR}/tasks/"

    log_info "--> 部署 MCP 客户端配置文件 (configs/mcp.json)..."
    cp "${SOURCE_ROOT}/configs/mcp.json" "${TARGET_DIR}/configs/"
    log_info "--> 部署落地实操指南 (docs/SUPERVISOR_GUIDE.md, docs/LITELLM_GUIDE.md)..."
    mkdir -p "${TARGET_DIR}/docs"
    cp "${SOURCE_ROOT}/docs/SUPERVISOR_GUIDE.md" "${TARGET_DIR}/docs/"
    cp "${SOURCE_ROOT}/docs/LITELLM_GUIDE.md" "${TARGET_DIR}/docs/"

    log_info "--> 部署自动化验证测试套件 (tests/test_ai_native_suite.py)..."
    mkdir -p "${TARGET_DIR}/tests"
    cp "${SOURCE_ROOT}/tests/test_ai_native_suite.py" "${TARGET_DIR}/tests/"
fi

# 5. 自动追加 .gitignore 规则
GITIGNORE_FILE="${TARGET_DIR}/.gitignore"
log_info "--> 检查并更新 .gitignore 安全规则..."
touch "${GITIGNORE_FILE}"

append_ignore_if_missing() {
    local rule="$1"
    if ! grep -qxF "${rule}" "${GITIGNORE_FILE}" 2>/dev/null; then
        echo "${rule}" >> "${GITIGNORE_FILE}"
        log_info "    + 添加忽略规则: ${rule}"
    fi
}

append_ignore_if_missing ".audit/"
append_ignore_if_missing "circuit_breaker_*.json"
append_ignore_if_missing "*.db"
append_ignore_if_missing "__pycache__/"
append_ignore_if_missing ".litellm/"

# 6. 环境快速自检
log_info "--> 执行运行环境自检..."
if command -v python3 >/dev/null 2>&1; then
    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_success "检测到 Python 运行环境: v${PY_VER}"
else
    log_warn "未检测到系统 python3，请确保已安装 Python 3.8+ 环境！"
fi

if git -C "${TARGET_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_success "目标目录为合法的 Git 仓库。"
else
    log_warn "目标目录尚未初始化 Git 仓库，建议在目标目录执行: git init"
fi

log_success "🎉 部署完成！"
echo ""
echo "================================================================================"
echo "🎯 下一步操作指引:"
echo "--------------------------------------------------------------------------------"
if [ "${MODE}" = "full" ]; then
    echo "1. 启动方案一状态机调度任务:"
    echo "   cd ${TARGET_DIR}"
    echo "   python3 scripts/supervisor.py create --task-id 101-demo --title \"示例特性\" --test-cmd \"pytest\""
    echo "   python3 scripts/supervisor.py step --task-id 101-demo"
    echo ""
    echo "2. 挂载 MCP 服务到 Claude Code / Cursor:"
    echo "   配置文件路径: ${TARGET_DIR}/configs/mcp.json"
    echo ""
    echo "3. 查看落地实操指南:"
    echo "   📖 状态机指南: ${TARGET_DIR}/docs/SUPERVISOR_GUIDE.md"
    echo "   📖 LiteLLM 网关: ${TARGET_DIR}/docs/LITELLM_GUIDE.md"
fi
echo "4. 启动 Solo 版 Worktree 多任务并行车间:"
echo "   cd ${TARGET_DIR}"
echo "   ./scripts/solo-worktree.sh start 101-demo \"pytest\""
echo "================================================================================"
