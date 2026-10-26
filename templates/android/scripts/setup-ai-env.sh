#!/usr/bin/env bash
# ==============================================================================
# scripts/setup-ai-env.sh - Android 工程 AI Agent 环境一键初始化脚本
# 支持工具: Claude Code / Codex / Kiro / Cursor / omp
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"
echo "==> [setup-ai-env] 正在初始化 Android 工程 AI Agent 环境: ${REPO_ROOT}"

# 1. 建立各 AI 工具软链接入口 (零配置指向根目录 skills/)
mkdir -p .claude .agents .kiro roles tasks skills scripts

setup_symlink() {
    local target="$1"
    local link="$2"
    if [[ -L "$link" ]]; then
        echo "  [OK] 软链接已存在: $link -> $(readlink "$link")"
    elif [[ -e "$link" ]]; then
        echo "  [WARN] 目标路径已存在实体文件/目录，跳过软链接: $link"
    else
        ln -s "$target" "$link"
        echo "  [CREATED] 建立软链接: $link -> $target"
    fi
}

echo "--> 1. 建立多端 skills 共享软链接..."
setup_symlink "../skills" ".claude/skills"
setup_symlink "../skills" ".agents/skills"
setup_symlink "../skills" ".kiro/skills"

if [[ -f "AGENTS.md" ]]; then
    setup_symlink "AGENTS.md" "CLAUDE.md"
    setup_symlink "AGENTS.md" ".cursorrules"
fi

# 2. 赋予脚本可执行权限
echo "--> 2. 配置 scripts 权限..."
chmod +x scripts/*.sh 2>/dev/null || true

# 3. 检查编译与测试环境 (Kotlin + C++/NDK)
echo "--> 3. 检查 Android 与 Native 构建环境..."
HAS_NATIVE=0
if [[ -f "CMakeLists.txt" || -f "app/src/main/cpp/CMakeLists.txt" || -d "app/src/main/cpp" || -d "cpp" || -d "jni" ]]; then
    HAS_NATIVE=1
    echo "  [Native] 检测到 C++/NDK 源码与构建配置，激活原生门禁能力"
    if command -v cmake >/dev/null 2>&1; then
        echo "  [CMake] $(cmake --version | head -n 1)"
    else
        echo "  [WARN] 本地未找到 cmake 命令，如需本地 host 测试建议安装 cmake"
    fi
    if command -v clang-format >/dev/null 2>&1; then
        echo "  [Clang-Format] $(clang-format --version 2>/dev/null | head -n 1 || echo '已安装')"
    fi
fi

if [[ -f "./gradlew" ]]; then
    echo "  [Android] 检测到 gradlew，默认复用 ~/.gradle 共享缓存"
fi

# 初始化 .ai-focus 默认配置 (若不存在)
if [[ ! -f ".ai-focus" ]]; then
    if [[ $HAS_NATIVE -eq 1 ]]; then
        echo "auto" > .ai-focus
        echo "  [Focus] 自动生成 .ai-focus (默认: auto，支持自动感知 C++ 与 UI 变更)"
    else
        echo "ui" > .ai-focus
        echo "  [Focus] 自动生成 .ai-focus (默认: ui，纯 Android 页面与状态机门禁)"
    fi
fi

# 4. 检查 .gitignore
echo "--> 4. 检查 .gitignore 临时工件屏蔽..."
if [[ -f ".gitignore" ]]; then
    for entry in ".audit/" "build_native/" ".ai-focus"; do
        if ! grep -q "^${entry}" .gitignore; then
            echo "$entry" >> .gitignore
            echo "  [UPDATED] .gitignore 自动追加: $entry"
        fi
    done
fi

echo "==> [setup-ai-env] Android 工程初始化完成！所有 Agent 工具已对齐 skills/ 资产。"
