#!/usr/bin/env bash
# ==============================================================================
# ai-metrics.sh — 零侵入 AI 研发提效监控与门禁统计工具 (支持 Claude Code & OMP)
#
# 功能：
#   1. record-hook <stage> <file> <pass|fail> [duration_s]
#      供 ~/.claude/settings.json Hooks 或 CI 脚本调用，写入 JSONL 埋点
#   2. report [--days N]
#      汇总分析：
#      - Git 提交中 AI 协同占比、有效代码行数与 Fix/Revert 返工率
#      - Hook 门禁（PostToolUse / StopGate）一次通过率与拦截次数
#      - 本地 Claude Code 会话的 Edit 补丁一次命中率与长会话预警
# ==============================================================================

set -euo pipefail

METRICS_DIR="${HOME}/.claude/metrics"
HOOK_LOG="${METRICS_DIR}/hook-events.jsonl"
DAYS=7

usage() {
  cat <<EOF
用法:
  $0 report [--days N]                              输出 AI 研发提效监控看板 (默认最近 7 天)
  $0 record-hook <stage> <file> <status> [seconds]  记录一次 Hook 门禁执行结果
EOF
}

record_hook() {
  local stage="${1:-PostToolUse}"
  local file="${2:-unknown}"
  local status="${3:-pass}"
  local duration="${4:-0}"

  mkdir -p "${METRICS_DIR}"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"ts":"%s","stage":"%s","file":"%s","status":"%s","duration_s":%d}\n' \
    "${ts}" "${stage}" "${file}" "${status}" "${duration}" >> "${HOOK_LOG}"
}

generate_report() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days)
        DAYS="${2:-7}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  echo "========================================================================"
  echo " 📊 AI 研发提效与质量门禁监控看板 (统计周期: 最近 ${DAYS} 天)"
  echo "========================================================================"
  echo ""

  # ----------------------------------------------------------------------------
  # 1. Git 提交维度：AI 协同占比与返工/修复率
  # ----------------------------------------------------------------------------
  echo "【一、Git 交付吞吐与质量留存 (当前仓库: $(basename "$(pwd)"))】"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local total_commits ai_commits fix_commits
    total_commits=$(git log --since="${DAYS} days ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
    ai_commits=$(git log --since="${DAYS} days ago" --grep="Co-Authored-By:" -i --oneline 2>/dev/null | wc -l | tr -d ' ')
    fix_commits=$(git log --since="${DAYS} days ago" --grep="^fix\|^revert\|bugfix" -i --oneline 2>/dev/null | wc -l | tr -d ' ')

    local total_added=0 ai_added=0
    total_added=$(git log --since="${DAYS} days ago" --numstat --pretty="" 2>/dev/null | awk '{add+=$1} END {print add+0}')
    ai_added=$(git log --since="${DAYS} days ago" --grep="Co-Authored-By:" -i --numstat --pretty="" 2>/dev/null | awk '{add+=$1} END {print add+0}')

    local commit_ratio="0.0"
    local line_ratio="0.0"
    local fix_ratio="0.0"
    if [[ "${total_commits}" -gt 0 ]]; then
      commit_ratio=$(awk -v a="${ai_commits}" -v t="${total_commits}" 'BEGIN {printf "%.1f", (a/t)*100}')
      fix_ratio=$(awk -v f="${fix_commits}" -v t="${total_commits}" 'BEGIN {printf "%.1f", (f/t)*100}')
    fi
    if [[ "${total_added}" -gt 0 ]]; then
      line_ratio=$(awk -v a="${ai_added}" -v t="${total_added}" 'BEGIN {printf "%.1f", (a/t)*100}')
    fi

    echo "  • 总提交数 (Commits)        : ${total_commits} 次 (其中 AI 协同提交: ${ai_commits} 次, 占比 ${commit_ratio}%)"
    echo "  • 新增代码行数 (Lines Added): ${total_added} 行 (其中 AI 协同新增: ${ai_added} 行, 占比 ${line_ratio}%)"
    echo "  • 修复/回滚提交比 (Fix/All) : ${fix_commits} 次 (${fix_ratio}% — 目标基线: < 15%)"
  else
    echo "  [提示] 当前目录不是 Git 仓库，跳过 Git 交付指标统计。"
  fi
  echo ""

  # ----------------------------------------------------------------------------
  # 2. Hook 确定性门禁维度：一次通过率与缺陷本地拦截数
  # ----------------------------------------------------------------------------
  echo "【二、确定性门禁监控 (PostToolUse & StopGate)】"
  if [[ -f "${HOOK_LOG}" ]]; then
    awk -F'"' '
      /stage/ {
        stage=""; status=""; dur=0;
        for (i=1; i<=NF; i++) {
          if ($i == "stage") stage=$(i+2);
          if ($i == "status") status=$(i+2);
          if ($i == "duration_s") {
            g=$(i+1); gsub(/[^0-9]/, "", g); dur=g+0;
          }
        }
        if (stage != "") {
          total[stage]++;
          if (status == "pass") pass[stage]++;
          else fail[stage]++;
          cost[stage]+=dur;
        }
      }
      END {
        for (s in total) {
          p = pass[s]+0;
          f = fail[s]+0;
          t = total[s];
          rate = (t > 0) ? (p / t) * 100 : 0;
          avg_t = (t > 0) ? (cost[s] / t) : 0;
          printf "  • %-12s : 总触发 %4d 次 | 一次通过 %4d 次 (%5.1f%%) | 本地拦截缺陷 %3d 次 | 平均耗时 %.1fs\n", s, t, p, rate, f, avg_t;
        }
      }
    ' "${HOOK_LOG}"
  else
    echo "  • 尚无门禁埋点记录 (${HOOK_LOG} 未生成)。"
    echo "    启用 ~/.claude/settings.json 中的 Hooks 后，每次代码修改与回合结束将自动记录。"
  fi
  echo ""

  # ----------------------------------------------------------------------------
  # 3. 本地会话日志维度：Edit 补丁命中率与交互健康度
  # ----------------------------------------------------------------------------
  echo "【三、Agent 会话健康度与补丁精度 (扫描本机 ~/.claude/projects)】"
  local proj_slug
  proj_slug="$(pwd | sed 's|/|-|g')"
  local session_dir="${HOME}/.claude/projects/${proj_slug}"

  if [[ -d "${session_dir}" ]]; then
    local session_files
    session_files=$(find "${session_dir}" -maxdepth 1 -name "*.jsonl" -mtime "-${DAYS}" 2>/dev/null | wc -l | tr -d ' ')
    local edit_calls=0
    edit_calls=$(grep -oh '"type":"tool_use"[^}]*"name":"Edit"' "${session_dir}"/*.jsonl 2>/dev/null | wc -l | tr -d ' ' || true)
    local edit_errors=0
    edit_errors=$(grep -oh '[<]tool_use_error[>]String to replace' "${session_dir}"/*.jsonl 2>/dev/null | wc -l | tr -d ' ' || true)

    local hit_rate="100.0"
    if [[ "${edit_calls}" -gt 0 ]]; then
      local success_edits=$((edit_calls > edit_errors ? edit_calls - edit_errors : 0))
      hit_rate=$(awk -v s="${success_edits}" -v t="${edit_calls}" 'BEGIN {printf "%.1f", (s/t)*100}')
    fi

    echo "  • 活跃会话文件数 (${DAYS}天内)  : ${session_files} 个"
    echo "  • Edit 局部补丁调用次数    : ${edit_calls} 次 (估算一次命中率: ${hit_rate}% — 目标基线: ≥ 95%)"
  else
    echo "  • 当前目录尚无匹配的 ~/.claude/projects 会话归档。"
  fi

  echo "========================================================================"
}

cmd="${1:-report}"
shift || true

case "${cmd}" in
  record-hook)
    record_hook "$@"
    ;;
  report)
    generate_report "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
