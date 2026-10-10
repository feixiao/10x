# Claude / omp / Pi 统一规则体系与工程实践

本文档定义了一套跨 Agent（Claude Code、omp、Pi 及主流编码 Agent）通用的指令规范与执行标准，目标是**消除模型幻觉、防止非必要代码重构、建立以实测证据为准的交付闭环**。

---

## 1. 为什么能统一？（原理与发现机制）

不同 Agent 工具在上下文加载机制上已经收敛出兼容链条：

| 工具 | 原生优先路径 | 兼容路径 | 规则生效范围 |
| :--- | :--- | :--- | :--- |
| **Claude Code** | `.claude/CLAUDE.md`, `CLAUDE.md` | 无 | 会话加载为上下文提示 |
| **omp / pi** | `.omp/AGENTS.md`, `.omp/RULES.md` | `AGENTS.md`, `CLAUDE.md`, `.agent/AGENTS.md` | `AGENTS.md` 为上下文；`RULES.md` 为强约束 Sticky Rules |
| **通用生态 (Codex/Cursor等)** | `AGENTS.md` | `.cursorrules`, `.windsurfrules` | 会话注入与规则索引 |

### 统一落地策略（单源真理 Single Source of Truth）
- **核心文件**：在仓库根目录维护一份标准 **`AGENTS.md`** 作为通用规则主干。
- **软链接映射**：
  - `CLAUDE.md -> AGENTS.md`：无缝覆盖 Claude Code。
  - `.omp/AGENTS.md -> ../AGENTS.md`（或直接使用根目录 `AGENTS.md`）：覆盖 omp 和 pi。

---

## 2. 统一规则模板（标准 `AGENTS.md`）

将以下结构固化在项目的 `AGENTS.md` 中：

```markdown
# AGENTS.md - Project Context & Agent Contract

## 1. 架构与运行环境 (Architecture & Stack)
- 语言与运行时版本（例：Python 3.11+, Go 1.22+, C++17, Node.js 22 LTS）
- 关键模块分布与依赖关系
- 核心约定（如：模块导出方式、错误类型定义体系）

## 2. 命令速查 (Commands Reference)
- 构建: `<build-command>`
- 快速测试 / 单测: `<fast-test-command>`
- 全量测试与覆盖率: `<full-test-command>`
- 静态分析与 Lint: `<lint-or-typecheck-command>`

## 3. 强约束行为准则 (Hard Constraints)
- **先读后写 (Locate Before Modifying)**：
  - 严禁盲猜文件路径或符号定义。修改前必须通过 grep/read/LSP 查阅现有代码与调用方。
- **精准微创编辑 (Surgical Edits)**：
  - 只修改与任务相关的代码行。严禁无故大面积重排格式、格式化无关代码或重写整个文件。
- **禁止篡改断言 (Never Tamper Assertions)**：
  - 测试用例失败时，必须修复业务代码逻辑错误，严禁放宽或删除断言来制造“假性通过”。
- **禁止占位符交付 (No Placeholders)**：
  - 严禁交付 `TODO: implement later`、空实现、fake mock 或未经测试的脚手架。

## 4. 交付定义与验证闭环 (Definition of Done)
每个任务完成前，必须满足以下 4 步交付检验：
1. **定位分析**：明确受影响文件清单及改动理由。
2. **实施变更**：保证类型安全与代码风格一致。
3. **真实验证 (CRITICAL)**：
   - 必须在控制台真实运行构建与测试命令，以实际终端输出作为证据。
   - 针对 Bug：先复现失败，再修复，最后证明通过。
   - 若无可自动化测试，必须运行 throwaway 脚本或 CLI 命令，打印行为结果。
4. **清理现场**：清理临时调试代码、测试日志及无用依赖。
```

---

## 3. 在多语言项目中的应用范例

以本仓库的 `agent-lab`（涵盖 C++、Go、Python）为例：

### 3.1 跨语言公共要求
- 保持各语言 CLI 行为、错误退出码与输出格式一致。
- 遵循统一的编码与验证周期：`修改代码` → `编译/检查` → `跑单测` → `跑 CLI 真实样本验收`。

### 3.2 语言特定命令契约
- **C++ (`agent-lab/cpp`)**
  - 构建：`cmake -S agent-lab/cpp -B agent-lab/cpp/build && cmake --build agent-lab/cpp/build`
  - 测试：`ctest --test-dir agent-lab/cpp/build --output-on-failure`
  - 验收：`agent-lab/cpp/build/expense-report agent-lab/cpp/sample.txt`
- **Go (`agent-lab/go`)**
  - 编译与单测：`cd agent-lab/go && go test -v ./... && go build -o /tmp/expense-report-go .`
  - 验收：`/tmp/expense-report-go agent-lab/go/sample.txt`
- **Python (`agent-lab/python`)**
  - 单测：`python3 -m unittest discover -s agent-lab/python -v`
  - 验收：`python3 agent-lab/python/main.py agent-lab/python/sample.txt`

---

## 4. 各工具运行推荐指令

| 任务场景 | Claude Code 推荐命令 | omp / pi 推荐命令 |
| :--- | :--- | :--- |
| **交互式开发** | `claude` | `omp` 或 `pi` |
| **带上下文启动** | `claude "完成需求并跑通测试"` | `omp "完成需求并跑通测试"` |
| **非交互/批处理模式** | `claude -p "检查代码规范"` | `omp -p "检查代码规范"` |
| **代码评审 (Git Diff)** | `git diff \| claude -p "Review"` | `git diff \| omp -p "Review"` |
| **会话恢复** | `claude --resume` | `omp --continue` 或 `omp -r <id>` |
