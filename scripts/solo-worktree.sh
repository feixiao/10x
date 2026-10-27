#!/usr/bin/env bash
# ==============================================================================
# solo-worktree.sh: 个人超级个体多 Agent 并行物理隔离车间调度脚本 (加固增强版)
# 用法:
#   ./scripts/solo-worktree.sh start <task-id> [test-command]   # 创建并在独立目录拉起 Aider
#   ./scripts/solo-worktree.sh status                          # 查看当前所有活跃车间与状态
#   ./scripts/solo-worktree.sh audit <task-id>                 # 执行双阶段反作弊差异隔离检查
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
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[solo-worktree]${NC} $1"; }
log_success() { echo -e "${GREEN}[solo-worktree]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[solo-worktree]${NC} $1"; }
log_error() { echo -e "${RED}[solo-worktree]${NC} $1" >&2; }

usage() {
    cat <<EOF
个人超级个体 Worktree 并行调度器

使用命令:
  $0 quick <task-id> "<一句话需求>" [test-cmd]   一键极速构建规范契约并拉起工作车间 (推荐)
  $0 new                                     进入命令行 3 步交互向导生成任务
  $0 start <task-id> [test-command] [desc]   拉起工作车间并启动 Aider (自动补齐契约卡)
  $0 status                                  查看当前所有并发车间、分支与修改状态
  $0 audit <task-id>                         对指定任务车间执行双阶段防作弊审查
  $0 close <task-id>                         安全清理已完成的任务车间 (含未合入防御)

示例:
  $0 quick 101-demo "实现 ETF 溢价率告警" "pytest"
  $0 new
  $0 start 101-user-jwt "pytest tests/"
  $0 status
  $0 audit 101-demo
  $0 close 101-demo
EOF
    exit 1
}

cmd_start() {
    local task_id="${1:?缺少 task-id 参数}"
    local test_cmd="${2:-}"
    local target_dir="${WORKTREES_BASE}/${task_id}"
    local branch_name="feat/${task_id}"

    # 0. 自动探活并在未启动时自动拉起常驻后台网关
    if ! curl -s -m 1 "http://127.0.0.1:4000/health" >/dev/null 2>&1; then
        if [ -x "${SCRIPT_DIR}/litellm-service.sh" ]; then
            log_info "检测到 LiteLLM 网关 (:4000) 未在运行，自动在后台拉起常驻服务..."
            "${SCRIPT_DIR}/litellm-service.sh" start >/dev/null 2>&1 || true
        fi
    fi
    if [ -d "${target_dir}" ]; then
        log_warn "工作目录已存在: ${target_dir}，直接切换进入..."
        cd "${target_dir}"
    else
        log_info "正在创建独立 Worktree: ${target_dir} (分支: ${branch_name})..."
        mkdir -p "${WORKTREES_BASE}"
        
        # 1. 检查分支是否已存在并安全创建 worktree
        if git -C "${REPO_ROOT}" rev-parse --verify "${branch_name}" >/dev/null 2>&1; then
            git -C "${REPO_ROOT}" worktree add "${target_dir}" "${branch_name}"
        else
            git -C "${REPO_ROOT}" worktree add -b "${branch_name}" "${target_dir}" HEAD
        fi
        # 2. 检查并跨工作区自动同步任务契约规范卡 (若不存在则自动智能补齐)
        if [ ! -f "${REPO_ROOT}/tasks/${task_id}.md" ] && [ ! -d "${REPO_ROOT}/tasks/${task_id}" ]; then
            if [ -f "${SCRIPT_DIR}/task_builder.py" ]; then
                local default_desc="${3:-实现 ${task_id} 核心功能并通过单测}"
                log_info "未检测到 tasks/${task_id}.md，自动生成标准安全任务契约规范卡..."
                python3 "${SCRIPT_DIR}/task_builder.py" quick "${task_id}" "${default_desc}" "${test_cmd}" --no-ai >/dev/null 2>&1 || true
            fi
        fi

        mkdir -p "${target_dir}/tasks"
        if [ -f "${REPO_ROOT}/tasks/${task_id}.md" ]; then
            cp "${REPO_ROOT}/tasks/${task_id}.md" "${target_dir}/tasks/"
            log_info "已同步任务卡: tasks/${task_id}.md"
        fi
        if [ -d "${REPO_ROOT}/tasks/${task_id}" ]; then
            cp -r "${REPO_ROOT}/tasks/${task_id}" "${target_dir}/tasks/"
            log_info "已同步任务目录: tasks/${task_id}/"
        fi
        # 3. 自动建立核心依赖目录软链接 (node_modules, .venv, venv)
        for dep in node_modules .venv venv; do
            if [ -d "${REPO_ROOT}/${dep}" ] && [ ! -e "${target_dir}/${dep}" ]; then
                ln -s "${REPO_ROOT}/${dep}" "${target_dir}/${dep}" 2>/dev/null || true
                log_info "已建立依赖软链接: ${dep}"
            fi
        done

        log_success "独立工作车间创建成功！物理隔离路径: ${target_dir}"
    fi

    cd "${target_dir}"

    # 3. 组装 Aider 命令
    if command -v aider >/dev/null 2>&1; then
        local aider_args=()
        
        # 优先读取 configs/.aider.conf.yml 或 .aider.conf.yml
        if [ -f "${REPO_ROOT}/configs/.aider.conf.yml" ]; then
            aider_args+=("--config" "${REPO_ROOT}/configs/.aider.conf.yml")
        elif [ -f "${REPO_ROOT}/.aider.conf.yml" ]; then
            aider_args+=("--config" "${REPO_ROOT}/.aider.conf.yml")
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
        echo "分支: ${branch_name}"
        if [ -t 0 ]; then
            ${SHELL:-bash}
        fi
    fi
}

cmd_status() {
    log_info "当前活跃的 Git Worktrees 与状态一览:"
    echo "================================================================================"
    printf "%-20s %-25s %-15s %s\n" "任务 ID" "分支" "未提交变更" "主干合并状态"
    echo "--------------------------------------------------------------------------------"

    local current_main_branch="main"
    if ! git -C "${REPO_ROOT}" rev-parse --verify main >/dev/null 2>&1; then
        current_main_branch="master"
    fi

    # 获取所有 worktree 列表
    local wt_output
    wt_output=$(git -C "${REPO_ROOT}" worktree list --porcelain)

    local cur_path=""
    local cur_branch=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.*) ]]; then
            cur_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.*) ]]; then
            cur_branch="${BASH_REMATCH[1]}"
        elif [[ -z "$line" && -n "$cur_path" ]]; then
            # 仅展示 worktrees/ 目录下的任务车间
            if [[ "$cur_path" == *"/worktrees/"* ]]; then
                local tid
                tid=$(basename "$cur_path")
                
                # 检查未提交修改 (含 untracked)
                local uncommitted="干净 (Clean)"
                local dirty_count
                dirty_count=$(git -C "$cur_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [ "$dirty_count" -gt 0 ]; then
                    uncommitted="${dirty_count} 个修改"
                fi

                # 检查是否已合入主干
                local merged_status="未合并"
                if git -C "${REPO_ROOT}" branch --merged "$current_main_branch" 2>/dev/null | grep -E "(^|\s)${cur_branch}$" >/dev/null 2>&1; then
                    merged_status="已合并"
                fi

                printf "%-20s %-25s %-15s %s\n" "$tid" "$cur_branch" "$uncommitted" "$merged_status"
            fi
            cur_path=""
            cur_branch=""
        fi
    done <<< "$wt_output"
    echo "================================================================================"
}
cmd_quick() {
    local task_id="${1:?缺少 task-id 参数}"
    local title="${2:?缺少需求描述，例如: \"实现 ETF 溢价率告警\"}"
    local test_cmd="${3:-}"
    
    if [ -f "${SCRIPT_DIR}/task_builder.py" ]; then
        log_info "正在极速构建任务规范契约 [${task_id}]..."
        python3 "${SCRIPT_DIR}/task_builder.py" quick "${task_id}" "${title}" "${test_cmd}"
    fi
    cmd_start "${task_id}" "${test_cmd}" "${title}"
}

cmd_new() {
    if [ -f "${SCRIPT_DIR}/task_builder.py" ]; then
        python3 "${SCRIPT_DIR}/task_builder.py" wizard
    else
        log_error "未找到 task_builder.py 脚本"
        exit 1
    fi
}

cmd_audit() {
    local task_id="${1:?缺少 task-id 参数}"
    local target_dir="${WORKTREES_BASE}/${task_id}"
    local audit_script="${REPO_ROOT}/scripts/audit-diffs.sh"

    if [ ! -d "${target_dir}" ]; then
        log_error "未找到目录: ${target_dir}"
        exit 1
    fi

    log_info "正在对任务车间 [${task_id}] 进行双阶段反作弊代码审查..."
    bash "${audit_script}" "main...HEAD" "${target_dir}/.audit"
    log_success "审查报告就绪: 查看 ${target_dir}/.audit/code.diff 与 ${target_dir}/.audit/tests.diff"
}

cmd_close() {
    local task_id="${1:?缺少 task-id 参数}"
    local target_dir="${WORKTREES_BASE}/${task_id}"
    local branch_name="feat/${task_id}"

    if [ ! -d "${target_dir}" ]; then
        log_error "未找到目录: ${target_dir}"
        exit 1
    fi

    # 1. 严格检查工作区未提交改动 (包括追踪文件与新增未跟踪文件)
    local dirty_changes
    dirty_changes=$(git -C "${target_dir}" status --porcelain 2>/dev/null || true)
    if [ -n "${dirty_changes}" ]; then
        log_warn "该车间存在未提交的代码修改："
        echo "${dirty_changes}"
        read -r -p "⚠️ 确认放弃这些未提交的修改并强制清理吗? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            log_info "取消清理。"
            exit 0
        fi
    fi

    # 2. 检查分支是否已被合并至主干
    local current_main="main"
    if ! git -C "${REPO_ROOT}" rev-parse --verify main >/dev/null 2>&1; then
        current_main="master"
    fi

    local is_merged
    is_merged=$(git -C "${REPO_ROOT}" branch --merged "${current_main}" 2>/dev/null | grep -E "(^|\s)${branch_name}$" || true)
    if [ -z "${is_merged}" ]; then
        log_warn "分支 [${branch_name}] 尚未合并到 ${current_main} 主干！"
        local commit_log
        commit_log=$(git -C "${REPO_ROOT}" log "${current_main}..${branch_name}" --oneline -n 3 2>/dev/null || true)
        if [ -n "${commit_log}" ]; then
            echo "未合入提交示例:"
            echo "${commit_log}"
        fi
        read -r -p "⚠️ 分支未合入主干，清理后该分支的工作可能遗失，确认注销 Worktree 吗? [y/N] " confirm_merge
        if [[ ! "$confirm_merge" =~ ^[yY]$ ]]; then
            log_info "取消清理。"
            exit 0
        fi
    fi

    # 3. 安全卸载 worktree
    log_info "正在卸载 Worktree: ${target_dir}..."
    git -C "${REPO_ROOT}" worktree remove --force "${target_dir}"
    log_success "车间 ${task_id} 已安全注销！"
}

case "${1:-}" in
    quick)
        shift
        cmd_quick "$@"
        ;;
    new|wizard)
        shift
        cmd_new "$@"
        ;;
    start)
        shift
        cmd_start "$@"
        ;;
    status|list)
        cmd_status
        ;;
    audit)
        shift
        cmd_audit "$@"
        ;;
    close)
        shift
        cmd_close "$@"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        ;;
esac
