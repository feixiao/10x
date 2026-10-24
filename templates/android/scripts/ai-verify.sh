#!/usr/bin/env bash
# ==============================================================================
# scripts/ai-verify.sh - AI Agent 自动化质量门禁与自愈检测脚本
# 串联：编译 -> Detekt 静态检查 -> Lint -> 单元测试 -> Roborazzi 截图生成
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$PROJECT_ROOT"

echo "==> [ai-verify] 启动 Android 自动化质量门禁..."
START_TIME=$(date +%s)
mkdir -p build

# 执行 Gradle aiVerify 聚合任务，过滤冗长常规日志，异常时提取关键报错
if ! ./gradlew aiVerify --no-daemon --stacktrace > build/ai-verify.log 2>&1; then
    echo "❌ [FAILED] 门禁检查未通过！关键错误提取如下："
    echo "--------------------------------------------------------"
    if grep -q -E "(e:|w:|FAILURE:|Check failed|Exception)" build/ai-verify.log; then
        grep -E "(e:|w:|FAILURE:|Check failed|Exception)" build/ai-verify.log | head -n 35
    else
        tail -n 40 build/ai-verify.log
    fi
    echo "--------------------------------------------------------"
    echo "💡 提示：请根据上述错误栈修复代码（拆分大函数/处理Compose稳定性/修复测试断言），然后重新执行 ./scripts/ai-verify.sh"
    exit 1
fi

ELAPSED=$(( $(date +%s) - START_TIME ))
echo "✅ [SUCCESS] 门禁全量通过！(耗时: ${ELAPSED}s)"

# 显示生成的截图快照
SCREENSHOT_COUNT=$(find . -path "*/screenshots/*.png" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SCREENSHOT_COUNT" -gt 0 ]]; then
    echo "==> [Screenshots] 最新生成的 UI 验收截图 (共 ${SCREENSHOT_COUNT} 张)："
    find . -path "*/screenshots/*.png" 2>/dev/null | head -n 10
fi
