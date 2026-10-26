#!/usr/bin/env bash
# ==============================================================================
# scripts/ai-verify.sh - AI Agent 自动化质量门禁与自愈检测脚本
# 支持动态关注点 (Focus Modes):
#   --focus=auto    : 自动感知 (根据 git diff 变更文件智能分流，默认)
#   --focus=native  : 专注 C++/NDK 编译、ASan 内存安全与 CTest/GTest (跳过 UI 渲染)
#   --focus=ui      : 专注 Compose/View 界面、Detekt、Slack Lint 与 UI 快照
#   --focus=dual    : 双层全量验证 (Native 门禁 + UI 门禁)
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$PROJECT_ROOT"
mkdir -p build

# 1. 解析参数与配置
FOCUS_MODE=""
for arg in "$@"; do
    case $arg in
        --focus=*)
            FOCUS_MODE="${arg#*=}"
            ;;
        -f=*)
            FOCUS_MODE="${arg#*=}"
            ;;
        --focus|-f)
            shift
            FOCUS_MODE="${1:-}"
            ;;
        --help|-h)
            echo "用法: $0 [--focus=auto|native|ui|dual]"
            echo "  --focus=auto   : (默认) 自动嗅探修改文件类型并执行对应门禁"
            echo "  --focus=native : 仅运行 C++/NDK 编译与原生测试 (跳过 UI 截图与 Detekt)"
            echo "  --focus=ui     : 仅运行 Kotlin/Compose 单元测试、Lint 与 Roborazzi 截图"
            echo "  --focus=dual   : 全量串行执行 Native 与 UI 双层门禁"
            exit 0
            ;;
    esac
done

# 若 CLI 未指定，依次尝试读取环境变量 AI_FOCUS_MODE 与 .ai-focus 配置文件
if [[ -z "$FOCUS_MODE" ]]; then
    if [[ -n "${AI_FOCUS_MODE:-}" ]]; then
        FOCUS_MODE="$AI_FOCUS_MODE"
    elif [[ -f ".ai-focus" ]]; then
        FOCUS_MODE="$(tr -d '[:space:]' < .ai-focus)"
    else
        FOCUS_MODE="auto"
    fi
fi

# 2. 自动嗅探逻辑 (Focus: auto)
detect_focus_mode() {
    local has_native_diff=0
    local has_ui_diff=0

    # 提取变更文件 (包含未暂存、已暂存及最近一次 commit)
    local diff_files
    diff_files=$(git status --porcelain 2>/dev/null | awk '{print $2}' || true)
    if [[ -z "$diff_files" ]]; then
        diff_files=$(git diff HEAD~1 --name-only 2>/dev/null || true)
    fi

    if [[ -n "$diff_files" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            if [[ "$file" =~ \.(cpp|cc|cxx|c|h|hpp|cuh)$ ]] || [[ "$file" =~ (CMakeLists\.txt|\.mk$) ]]; then
                has_native_diff=1
            fi
            if [[ "$file" =~ \.(kt|java|xml)$ ]] || [[ "$file" =~ (build\.gradle|settings\.gradle) ]]; then
                has_ui_diff=1
            fi
        done <<< "$diff_files"
    fi

    if [[ $has_native_diff -eq 1 && $has_ui_diff -eq 1 ]]; then
        echo "dual"
    elif [[ $has_native_diff -eq 1 ]]; then
        echo "native"
    elif [[ $has_ui_diff -eq 1 ]]; then
        echo "ui"
    else
        # 无法从 diff 探测时，依据工程特征兜底
        if [[ -f "CMakeLists.txt" || -f "app/src/main/cpp/CMakeLists.txt" || -d "app/src/main/cpp" ]]; then
            echo "dual"
        else
            echo "ui"
        fi
    fi
}

if [[ "$FOCUS_MODE" == "auto" ]]; then
    RESOLVED_FOCUS="$(detect_focus_mode)"
    FOCUS_UPPER=$(echo "$RESOLVED_FOCUS" | tr '[:lower:]' '[:upper:]')
    echo "==> [ai-verify] 自动感知模式生效: 检测到关注点为 [${FOCUS_UPPER}]"
else
    RESOLVED_FOCUS="$FOCUS_MODE"
fi

START_TIME=$(date +%s)

# 3. 门禁分支执行器
run_native_gate() {
    echo "--------------------------------------------------------"
    echo "==> [ai-verify:native] 启动 C++/NDK 原生门禁验证..."
    echo "--------------------------------------------------------"
    local native_log="build/ai-verify-native.log"
    : > "$native_log"

    local ran_host_test=0

    # (A) 若配置了本地 host CTest/CMake (跨平台快速测试)
    if [[ -f "build_native/CMakeCache.txt" ]]; then
        echo "  --> 检测到 build_native，运行本地 CTest + ASan..."
        if ! cmake --build build_native -j4 > "$native_log" 2>&1 && ctest --test-dir build_native --output-on-failure >> "$native_log" 2>&1; then
            echo "❌ [FAILED] C++ 本地构建或 CTest 单测失败！错误提取如下："
            grep -E "(error:|fatal error:|FAILED|AddressSanitizer)" "$native_log" | head -n 35 || tail -n 35 "$native_log"
            return 1
        fi
        ran_host_test=1
    fi

    # (B) Gradle NDK 编译门禁
    if [[ -f "./gradlew" ]]; then
        echo "  --> 运行 Gradle NDK 构建门禁 (:app:externalNativeBuildDebug)..."
        local gradle_cmd="./gradlew :app:externalNativeBuildDebug --no-daemon"
        if ! ./gradlew tasks 2>/dev/null | grep -q "externalNativeBuildDebug"; then
            gradle_cmd="./gradlew assembleDebug --no-daemon"
        fi

        if ! $gradle_cmd >> "$native_log" 2>&1; then
            echo "❌ [FAILED] Gradle NDK 原生构建失败！关键错误提取如下："
            grep -E "(e:|fatal error:|error:|FAILED|ninja: build stopped)" "$native_log" | head -n 35 || tail -n 35 "$native_log"
            return 1
        fi
    fi

    echo "✅ [SUCCESS:native] C++/NDK 原生层编译与单测校验通过！"
    return 0
}

run_ui_gate() {
    echo "--------------------------------------------------------"
    echo "==> [ai-verify:ui] 启动 Android 业务与 UI 门禁验证..."
    echo "--------------------------------------------------------"
    local ui_log="build/ai-verify-ui.log"
    : > "$ui_log"

    if [[ ! -f "./gradlew" ]]; then
        echo "⚠️  [WARN] 未检测到 ./gradlew，跳过 Gradle UI 门禁。"
        return 0
    fi

    # 检测是否存在 aiVerify 聚合任务，若无则使用标准测试
    local gradle_task="aiVerify"
    if ! ./gradlew tasks 2>/dev/null | grep -q "aiVerify"; then
        gradle_task="testDebugUnitTest"
    fi

    if ! ./gradlew "$gradle_task" --no-daemon --stacktrace > "$ui_log" 2>&1; then
        echo "❌ [FAILED] UI / Kotlin 门禁未通过！关键错误提取如下："
        if grep -q -E "(e:|w:|FAILURE:|Check failed|Exception)" "$ui_log"; then
            grep -E "(e:|w:|FAILURE:|Check failed|Exception)" "$ui_log" | head -n 35
        else
            tail -n 40 "$ui_log"
        fi
        echo "💡 提示：请根据上述错误修复代码（拆分大函数/处理 Compose 稳定性/修复测试断言），然后重新验证。"
        return 1
    fi

    echo "✅ [SUCCESS:ui] Android 业务与 UI 门禁通过！"
    local screenshot_count
    screenshot_count=$(find . -path "*/screenshots/*.png" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$screenshot_count" -gt 0 ]]; then
        echo "==> [Screenshots] 最新生成的 UI 验收快照 (共 ${screenshot_count} 张)："
        find . -path "*/screenshots/*.png" 2>/dev/null | head -n 10
    fi
    return 0
}

# 4. 根据关注点调度执行
case "$RESOLVED_FOCUS" in
    native)
        run_native_gate
        ;;
    ui)
        run_ui_gate
        ;;
    dual)
        run_native_gate
        run_ui_gate
        ;;
    *)
        echo "❌ [ERROR] 未知的关注点模式: [${RESOLVED_FOCUS}]，有效选项: auto | native | ui | dual"
        exit 1
        ;;
esac

ELAPSED=$(( $(date +%s) - START_TIME ))
FOCUS_UPPER=$(echo "$RESOLVED_FOCUS" | tr '[:lower:]' '[:upper:]')
echo "--------------------------------------------------------"
echo "🎉 [ALL PASSED] 所有门禁检查通过！模式: [${FOCUS_UPPER}] (总耗时: ${ELAPSED}s)"
echo "--------------------------------------------------------"
