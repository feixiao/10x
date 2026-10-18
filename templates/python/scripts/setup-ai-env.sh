#!/usr/bin/env bash
# ==============================================================================
# scripts/setup-ai-env.sh - Python 工程 AI Agent 环境一键初始化脚本
# 支持工具: Claude Code / Codex / Kiro / Cursor / omp
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"
echo "==> [setup-ai-env] 正在初始化 Python 工程 AI Agent 环境: ${REPO_ROOT}"

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
fi

# 2. 赋予脚本可执行权限
echo "--> 2. 配置 scripts 权限..."
chmod +x scripts/*.sh 2>/dev/null || true

# 3. 检查编译与测试环境
echo "--> 3. 检查 Python 构建与单测环境..."
if command -v ruff >/dev/null 2>&1; then
    echo "  [Python] 检测到 ruff 已就绪"
else
    echo "  [Python 提示] 建议安装 ruff 加速静态检查: pip install ruff"
fi

# 4. 检查 .gitignore
echo "--> 4. 检查 .gitignore 临时工件屏蔽..."
if [[ -f ".gitignore" ]]; then
    if ! grep -q "^\.audit/" .gitignore; then
        echo ".audit/" >> .gitignore
        echo "  [UPDATED] .gitignore 自动追加: .audit/"
    fi
fi

echo "==> [setup-ai-env] Python 工程初始化完成！所有 Agent 工具已对齐 skills/ 资产。"
