#!/usr/bin/env bash
# ==============================================================================
# scripts/install.sh - AI-Native 全生命周期研发套件一键安装部署脚本
# 
# 用法:
#   ./scripts/install.sh /path/to/my-project
#   ./scripts/install.sh /path/to/my-project                   # 默认轻量安装 Solo 个人版 (集中收敛于 .10x)
#   ./scripts/install.sh /path/to/my-project --mode=full       # 全量安装状态机调度器与 MCP 矩阵
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
  $0 <目标工程路径> [--mode=full|solo] [--dest=.10x]

参数说明:
  目标工程路径   待接入 AI-Native 研发能力的外部项目根目录
  --mode=solo    轻量安装：仅安装 Solo Worktree 并行调度器与配置 (默认)
  --mode=full    全量安装：主控状态机调度器 + MCP 矩阵服务 + Solo 工作车间
  --dest=<dir>   集中管理目录名称 (默认: .10x，绝不污染源项目原有根目录)

示例:
  $0 /path/to/my-backend-app
  $0 ../another-service --mode=full --dest=.10x
EOF
    exit 1
}

# 1. 参数解析
TARGET_DIR="${1:-}"
MODE="solo"
DEST_NAME=".10x"

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
        --dest=*)
            DEST_NAME="${arg#*=}"
            ;;
        --dir=*)
            DEST_NAME="${arg#*=}"
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

TENX_TARGET="${TARGET_DIR}/${DEST_NAME}"

log_info "==> 开始向目标项目注入 AI-Native 研发套件 (非侵入式集中管理)..."
log_info "    来源代码仓: ${SOURCE_ROOT}"
log_info "    目标工程路径: ${TARGET_DIR}"
log_info "    集中套件目录: ${TENX_TARGET}"
log_info "    安装模式: [${MODE}]"

# 2. 基础集中目录初始化 (所有资产严格收敛于 .10x，不污染目标工程根目录)
mkdir -p "${TENX_TARGET}/bin"
mkdir -p "${TENX_TARGET}/tasks"
mkdir -p "${TENX_TARGET}/configs"
mkdir -p "${TENX_TARGET}/docs"

# 部署统一入口脚本 10x
cp "${SOURCE_ROOT}/scripts/10x" "${TENX_TARGET}/10x"
chmod +x "${TENX_TARGET}/10x"

# 3. 部署通用脚本、智能任务构建器与契约模板 (收敛于 .10x/bin 与 .10x/tasks)
log_info "--> 部署集中通用脚本与智能构建器..."
cp "${SOURCE_ROOT}/scripts/audit-diffs.sh" "${TENX_TARGET}/bin/"
chmod +x "${TENX_TARGET}/bin/audit-diffs.sh"
cp "${SOURCE_ROOT}/scripts/task_builder.py" "${TENX_TARGET}/bin/"
chmod +x "${TENX_TARGET}/bin/task_builder.py"
cp "${SOURCE_ROOT}/tasks/template.md" "${TENX_TARGET}/tasks/"

log_info "--> 部署端到端实操与控制指南文档..."
cp "${SOURCE_ROOT}/docs/PRACTICAL_WORKFLOW_GUIDE.md" "${TENX_TARGET}/docs/"
cp "${SOURCE_ROOT}/docs/SOLO_EDITION_GUIDE.md" "${TENX_TARGET}/docs/"

# 4. 根据模式分流安装
if [ "${MODE}" = "full" ] || [ "${MODE}" = "solo" ]; then
    log_info "--> 部署 Solo 版 Git Worktree 调度器与 LiteLLM 服务管理脚本..."
    cp "${SOURCE_ROOT}/scripts/solo-worktree.sh" "${TENX_TARGET}/bin/"
    chmod +x "${TENX_TARGET}/bin/solo-worktree.sh"
    cp "${SOURCE_ROOT}/scripts/litellm-service.sh" "${TENX_TARGET}/bin/"
    chmod +x "${TENX_TARGET}/bin/litellm-service.sh"
    
    cp "${SOURCE_ROOT}/configs/litellm.yaml" "${TENX_TARGET}/configs/"
    cp "${SOURCE_ROOT}/configs/.aider.conf.yml" "${TENX_TARGET}/configs/"
    cp "${SOURCE_ROOT}/configs/docker-compose.yml" "${TENX_TARGET}/configs/"
fi

if [ "${MODE}" = "full" ]; then
    log_info "--> 部署方案一: 主控状态机调度器 (supervisor.py)..."
    cp "${SOURCE_ROOT}/scripts/supervisor.py" "${TENX_TARGET}/bin/"
    chmod +x "${TENX_TARGET}/bin/supervisor.py"

    log_info "--> 部署方案一: MCP 服务矩阵 (mcp_servers/)..."
    mkdir -p "${TENX_TARGET}/mcp_servers"
    cp -r "${SOURCE_ROOT}/mcp_servers/." "${TENX_TARGET}/mcp_servers/"
    chmod +x "${TENX_TARGET}/mcp_servers/"*.py

    log_info "--> 部署 MCP 客户端配置文件 (configs/mcp.json)..."
    sed "s|\"mcp_servers/|\"${DEST_NAME}/mcp_servers/|g" "${SOURCE_ROOT}/configs/mcp.json" > "${TENX_TARGET}/configs/mcp.json"

    log_info "--> 部署状态机与企业级网关指南..."
    cp "${SOURCE_ROOT}/docs/SUPERVISOR_GUIDE.md" "${TENX_TARGET}/docs/"
    cp "${SOURCE_ROOT}/docs/LITELLM_GUIDE.md" "${TENX_TARGET}/docs/"
    [ -f "${SOURCE_ROOT}/docs/ENTERPRISE_EDITION_GUIDE.md" ] && cp "${SOURCE_ROOT}/docs/ENTERPRISE_EDITION_GUIDE.md" "${TENX_TARGET}/docs/"

    log_info "--> 部署自动化验证测试套件 (tests/)..."
    mkdir -p "${TENX_TARGET}/tests"
    cp "${SOURCE_ROOT}/tests/test_ai_native_suite.py" "${TENX_TARGET}/tests/"
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

append_ignore_if_missing "${DEST_NAME}/.litellm/"
append_ignore_if_missing "${DEST_NAME}/tasks/*/.audit/"
append_ignore_if_missing "circuit_breaker_*.json"
append_ignore_if_missing "*.db"
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
echo "🎯 极简实战上手与内容控制指引 (非侵入式集中目录: ${DEST_NAME}/):"
echo "--------------------------------------------------------------------------------"
echo "1. 极速创建任务车间 (零手动写 Markdown，自动注入三大防作弊与负向清单):"
echo "   cd ${TARGET_DIR}"
echo "   ./${DEST_NAME}/10x quick 101-demo \"实现 ETF 溢价率告警\" \"pytest\""
echo "   # 或使用 3 步交互问答向导: ./${DEST_NAME}/10x new"
echo ""
echo "2. 查看当前所有活跃车间与分支合并状态:"
echo "   ./${DEST_NAME}/10x status"
echo ""
echo "3. 可视化查看与交互 (看得清清楚楚):"
echo "   另开终端打开独立工作目录: cursor ../worktrees/101-demo (或 code ../worktrees/101-demo)"
echo ""
echo "4. 反作弊代码审计 (防 AI 偷删单测断言):"
echo "   ./${DEST_NAME}/10x audit 101-demo"
echo "   # 查看生成的 .audit/code.diff (纯业务) 与 .audit/tests.diff (测试用例)"
echo ""
echo "5. 任务完成安全清理 (含未合入主干拦截保护):"
echo "   ./${DEST_NAME}/10x close 101-demo"
echo ""
if [ "${MODE}" = "full" ]; then
    echo "6. 全自动四角色状态机流水线 (可选高级模式):"
    echo "   ./${DEST_NAME}/10x supervisor create --task-id 101-demo --title \"示例特性\" --test-cmd \"pytest\""
    echo "   ./${DEST_NAME}/10x supervisor step --task-id 101-demo"
    echo ""
    echo "7. 挂载 MCP 服务到 Claude Code / Cursor:"
    echo "   配置文件: ${DEST_NAME}/configs/mcp.json"
    echo ""
fi
echo "📖 必读：完整实战与内容控制指南:"
echo "   ${TENX_TARGET}/docs/PRACTICAL_WORKFLOW_GUIDE.md"
echo "================================================================================"
