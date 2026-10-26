#!/usr/bin/env bash
# ==============================================================================
# scripts/audit-diffs.sh - 代码与单测物理隔离双阶段反作弊拆分脚本
# 用途: 生成双阶段审查集合 A (code.diff + stat.txt) 与集合 B (tests.diff + message.txt)
# ==============================================================================
set -euo pipefail

TARGET="${1:-HEAD~1..HEAD}"
OUTPUT_DIR="${2:-.audit}"

mkdir -p "$OUTPUT_DIR"

echo "==> [audit-diffs] 分析目标: ${TARGET}"
echo "==> [audit-diffs] 输出目录: ${OUTPUT_DIR}"

# 1. 提取提交说明 / 变更意图说明 (message.txt)
if [[ "$TARGET" =~ \.\. ]]; then
    git log "$TARGET" --pretty=format:"commit %h%nAuthor: %an%nDate:   %ad%n%n    %s%n%b" > "${OUTPUT_DIR}/message.txt" 2>/dev/null || true
else
    git log -1 "$TARGET" --pretty=format:"commit %h%nAuthor: %an%nDate:   %ad%n%n    %s%n%b" > "${OUTPUT_DIR}/message.txt" 2>/dev/null || true
fi

if [[ ! -s "${OUTPUT_DIR}/message.txt" ]]; then
    echo "工作区暂无已提交 Message，记录当前分支状态:" > "${OUTPUT_DIR}/message.txt"
    git status -s >> "${OUTPUT_DIR}/message.txt" || true
fi

# 2. 提取变更文件统计 (stat.txt)
git diff "$TARGET" --stat > "${OUTPUT_DIR}/stat.txt" 2>/dev/null || git diff HEAD --stat > "${OUTPUT_DIR}/stat.txt"

# 3. 提取所有变更文件列表
CHANGED_FILES=$(git diff "$TARGET" --name-only 2>/dev/null || git diff HEAD --name-only)

if [[ -z "$CHANGED_FILES" ]]; then
    echo "⚠️  [audit-diffs] 未检测到任何文件变更！"
    : > "${OUTPUT_DIR}/code.diff"
    : > "${OUTPUT_DIR}/tests.diff"
    exit 0
fi

TEST_FILES=()
CODE_FILES=()

# 4. 精确分类测试文件与业务文件
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" =~ (test_|_test\.|Test\.(kt|java|ts|js|jsx|tsx)$|\.spec\.(ts|js)$|tests/|test/|androidTest/|testdata/|conftest\.py|gtest) ]]; then
        TEST_FILES+=("$file")
    else
        CODE_FILES+=("$file")
    fi
done <<< "$CHANGED_FILES"

# 5. 生成纯业务代码变更集合 A (code.diff) - 剔除所有测试
if [[ ${#CODE_FILES[@]} -gt 0 ]]; then
    git diff "$TARGET" -- "${CODE_FILES[@]}" > "${OUTPUT_DIR}/code.diff" 2>/dev/null || git diff HEAD -- "${CODE_FILES[@]}" > "${OUTPUT_DIR}/code.diff"
else
    : > "${OUTPUT_DIR}/code.diff"
fi

# 6. 生成测试变更集合 B (tests.diff)
if [[ ${#TEST_FILES[@]} -gt 0 ]]; then
    git diff "$TARGET" -- "${TEST_FILES[@]}" > "${OUTPUT_DIR}/tests.diff" 2>/dev/null || git diff HEAD -- "${TEST_FILES[@]}" > "${OUTPUT_DIR}/tests.diff"
else
    : > "${OUTPUT_DIR}/tests.diff"
fi

echo "==> [audit-diffs] 分类完成:"
echo "    - 业务代码文件数: ${#CODE_FILES[@]} (写入 ${OUTPUT_DIR}/code.diff)"
echo "    - 测试代码文件数: ${#TEST_FILES[@]} (写入 ${OUTPUT_DIR}/tests.diff)"
echo "    - 结构变更统计: (写入 ${OUTPUT_DIR}/stat.txt)"
echo "    - 提交说明文本: (写入 ${OUTPUT_DIR}/message.txt)"
echo "==> [audit-diffs] 双阶段反作弊代码与测试物理隔离就绪！"
