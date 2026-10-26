#!/usr/bin/env bash
# ==============================================================================
# solo-worktree.sh: 个人超级个体多 Agent 并行物理隔离车间调度脚本
# 用法:
#   ./scripts/solo-worktree.sh start <task-id> [test-command]   # 创建并在独立目录拉起 Aider
#   ./scripts/solo-worktree.sh list                            # 查看当前所有活跃的工作车间
#   ./scripts/solo-worktree.sh close <task-id>                 # 任务完成合入后安全清理 Worktree
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKTREES_BASE="${REPO_ROOT}/../worktrees"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[solo-worktree]${NC} $1"; }
log_success() { echo -e "${GREEN}[solo-worktree]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[solo-worktree]${NC} $1"; }
log_error() { echo -e "${RED}[solo-worktree]${NC} $1" >&2; }

usage() {
    cat <<EOF
个人超级个体 Worktree 并行调度器

使用命令:
  $0 start <task-id> [test-command]   拉起新的工作车间并启动 Aider
  $0 list                            列出当前所有并发车间
  $0 close <task-id>                 安全清理已完成的任务车间

示例:
  $0 start 101-user-jwt "pytest tests/"
  $0 start 102-cache-redis "go test ./..."
  $0 close 101-user-jwt
EOF
    exit 1
}

cmd_start() {
    local task_id="${1:?缺少 task-id 参数}"
    local test_cmd="${2:-}"
    local target_dir="${WORKTREES_BASE}/${task_id}"
    local branch_name="feat/${task_id}"

    if [ -d "${target_dir}" ]; then
        log_warn "工作目录已存在: ${target_dir}，直接切换进入..."
        cd "${target_dir}"
    else
        log_info "正在创建独立 Worktree: ${target_dir} (分支: ${branch_name})..."
        mkdir -p "${WORKTREES_BASE}"
        
        # 检查分支是否已存在
        if git rev-parse --verify "${branch_name}" >/dev/null 2>&1; then
            git worktree add "${target_dir}" "${branch_name}"
        else
            git worktree add -b "${branch_name}" "${target_dir}" HEAD
        fi
        
        # 拷贝/软链接必要的工程规范
        if [ -f "${REPO_ROOT}/tasks/tracker.md" ] && [ -d "${target_dir}/tasks" ]; then
            cp "${REPO_ROOT}/tasks/tracker.md" "${target_dir}/tasks/tracker.md" 2>/dev/null || true
        fi
        
        log_success "独立工作车间创建成功！物理隔离路径: ${target_dir}"
    fi

    cd "${target_dir}"

    # 组装 Aider 命令
    if command -v aider >/dev/null 2>&1; then
        local aider_args=()
        
        # 优先读取 configs/solo/.aider.conf.yml
        if [ -f "${REPO_ROOT}/configs/solo/.aider.conf.yml" ]; then
            aider_args+=("--config" "${REPO_ROOT}/configs/solo/.aider.conf.yml")
        fi

        # 挂载自动单测门禁
        if [ -n "${test_cmd}" ]; then
            log_info "已激活 TDD 自动自愈门禁: [${test_cmd}]"
            aider_args+=("--test-cmd" "${test_cmd}" "--auto-test")
        fi

        log_info "正在启动 Aider (按 Ctrl+D 或 /exit 退出)..."
        aider "${aider_args[@]}"
    else
        log_warn "未检测到已安装的 aider。已为你切入 Worktree 终端环境："
        echo "路径: ${target_dir}"
        echo "你可以手动在此执行 Claude Code, omp 或其他 CLI Agent。"
        ${SHELL:-bash}
    fi
}

cmd_list() {
    log_info "当前活跃的 Git Worktrees:"
    git worktree list
}

cmd_close() {
    local task_id="${1:?缺少 task-id 参数}"
    local target_dir="${WORKTREES_BASE}/${task_id}"

    if [ ! -d "${target_dir}" ]; then
        log_error "未找到目录: ${target_dir}"
        exit 1
    fi

    log_info "正在检查是否有未提交的代码变更..."
    if ! git -C "${target_dir}" diff-index --quiet HEAD --; then
        log_warn "该车间存在未提交的代码修改！"
        read -r -p "是否强制移除? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_info "取消清理。"
            exit 0
        fi
    fi

    log_info "正在安全卸载 Worktree: ${target_dir}..."
    git worktree remove --force "${target_dir}"
    log_success "车间 ${task_id} 已成功注销并清理！"
}

# 路由分发
case "${1:-}" in
    start)
        shift
        cmd_start "$@"
        ;;
    list)
        cmd_list
        ;;
    close)
        shift
        cmd_close "$@"
        ;;
    *)
        usage
        ;;
esac
