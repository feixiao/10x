#!/usr/bin/env bash
# ==============================================================================
# scripts/install-harness.sh - 一键将指定技术栈的 Agent 研发套件安装到目标工程
# 用法: 
#   ./scripts/install-harness.sh <cpp|go|python|android> <目标工程路径> [focus_mode]
# 示例:
#   ./scripts/install-harness.sh cpp ../my-cpp-project
#   ./scripts/install-harness.sh android ../my-android-app
#   ./scripts/install-harness.sh android ../my-android-app native
# ==============================================================================
set -euo pipefail

TEMPLATES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates" && pwd)"

# 参数解析
LANG_ARG=""
TARGET_DIR=""
FOCUS_OPT=""

if [[ $# -eq 0 ]]; then
    echo "❌ 错误: 参数不足！"
    echo "用法: $0 <cpp|go|python|android> <目标工程路径> [focus_mode]"
    echo "或者: $0 <目标工程路径> (将尝试自动探测语言)"
    echo "示例: $0 android ../my-android-project"
    echo "      $0 android ../my-android-project native"
    exit 1
elif [[ $# -eq 1 ]]; then
    TARGET_DIR="$1"
elif [[ $# -eq 2 ]]; then
    LANG_ARG="$1"
    TARGET_DIR="$2"
else
    LANG_ARG="$1"
    TARGET_DIR="$2"
    FOCUS_OPT="$3"
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "==> 目标目录不存在，自动创建: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# 若未指定语言，尝试自动探测
if [[ -z "$LANG_ARG" ]]; then
    echo "==> 未显式指定语言，正在探测目标工程特征..."
    if [[ -f "$TARGET_DIR/settings.gradle" || -f "$TARGET_DIR/settings.gradle.kts" || -f "$TARGET_DIR/build.gradle" || -f "$TARGET_DIR/build.gradle.kts" ]]; then
        LANG_ARG="android"
    elif [[ -f "$TARGET_DIR/go.mod" ]]; then
        LANG_ARG="go"
    elif [[ -f "$TARGET_DIR/pyproject.toml" || -f "$TARGET_DIR/setup.py" || -f "$TARGET_DIR/requirements.txt" ]]; then
        LANG_ARG="python"
    elif [[ -f "$TARGET_DIR/CMakeLists.txt" ]]; then
        LANG_ARG="cpp"
    else
        echo "❌ 无法自动识别技术栈，请显式指定:"
        echo "   $0 <cpp|go|python|android> $TARGET_DIR"
        exit 1
    fi
    echo "==> 自动识别技术栈为: ${LANG_ARG}"
fi

# 检查模版目录
SRC_DIR="${TEMPLATES_ROOT}/${LANG_ARG}"
if [[ ! -d "$SRC_DIR" ]]; then
    echo "❌ 错误: 不支持的语言或模版不存在: ${LANG_ARG}"
    echo "可用模版: cpp, go, python, android"
    exit 1
fi

echo "==> [install-harness] 选择模版: [${LANG_ARG}] (${SRC_DIR})"
echo "==> [install-harness] 目标工程: ${TARGET_DIR}"

# 1. 安装共用角色契约与语言套件
echo "--> 1. 复制共用角色契约与纯净 ${LANG_ARG} 资产文件..."
mkdir -p "$TARGET_DIR/roles/core"
cp -R "${TEMPLATES_ROOT}/common/roles/." "$TARGET_DIR/roles/core/"
cp -R "${SRC_DIR}/roles" "$TARGET_DIR/"
cp -R "${SRC_DIR}/skills" "$TARGET_DIR/"
cp -R "${SRC_DIR}/scripts" "$TARGET_DIR/"
cp -R "${SRC_DIR}/tasks" "$TARGET_DIR/"
cp "${SRC_DIR}/AGENTS.md" "$TARGET_DIR/"
cp "${SRC_DIR}/README.md" "$TARGET_DIR/AI-HARNESS-GUIDE.md"
[[ -d "${SRC_DIR}/config" ]] && cp -R "${SRC_DIR}/config" "$TARGET_DIR/"
[[ -d "${SRC_DIR}/quality-gate" ]] && cp -R "${SRC_DIR}/quality-gate" "$TARGET_DIR/"
cp "${TEMPLATES_ROOT}/../docs/CLIENT_ADAPTERS.md" "$TARGET_DIR/AI-CLIENT-ADAPTERS.md"

# 2. 在目标工程运行 setup-ai-env.sh 自动建立软链接
echo "--> 2. 触发目标工程环境初始化..."
cd "$TARGET_DIR"
bash scripts/setup-ai-env.sh

# 若指定了特定的关注点模式 (如 native / ui / dual / auto)
if [[ -n "$FOCUS_OPT" && "$LANG_ARG" == "android" ]]; then
    FOCUS_OPT="${FOCUS_OPT#--focus=}"
    echo "$FOCUS_OPT" > "$TARGET_DIR/.ai-focus"
    echo "--> [Focus] 已设置 Android 默认关注点: .ai-focus -> [${FOCUS_OPT}]"
fi

echo "==> [install-harness] 恭喜！${LANG_ARG} Agent 研发套件已成功安装至: $TARGET_DIR"
echo "    - 快速查阅文档: $TARGET_DIR/AI-HARNESS-GUIDE.md"
echo "    - 主契约文件: $TARGET_DIR/AGENTS.md"
if [[ "$LANG_ARG" == "android" ]]; then
    echo "    - 动态门禁验证: ./scripts/ai-verify.sh [--focus=auto|native|ui|dual]"
fi
