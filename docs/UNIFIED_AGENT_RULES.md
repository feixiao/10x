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

---

## 5. 进阶提效杠杆（突破研发物理瓶颈）

日常使用 Agent 开发时，时间往往被“漫无目的全库检索”、“盯着屏幕干等生成”、“长任务上下文撑爆遗忘”和“测试跑太慢或返工”吞噬。通过以下 5 个工程杠杆可大幅提效：

### 5.1 快慢分流：轻量只读 Scout 探路，保护主会话上下文
- **痛点**：主力大模型全局 grep 数十个文件或排查巨量日志，消耗大量 Token，且导致主会话后半程上下文臃肿、注意力衰退。
- **方案**：先用轻量/低成本模型（或受限只读会话）做 Scout 检索，仅输出“受影响的 2~3 个文件路径、关键函数名和堆栈行号”；主力模型拿到浓缩上下文后直接对症下药。
- **CLI 范例**：
  ```sh
  # 限制只读工具做调研，结果通过管道传递给主力会话实施
  omp -p --tools read,grep,glob "定位导致 order_timeout 的核心函数与调用链" | omp "根据上述分析修复超时问题"
  ```

### 5.2 物理隔离并行：利用 Git Worktree 消除等待时间
- **痛点**：单会话模式下派发一个需求需等待 2~5 分钟，多任务串行执行造成人肉等候瓶颈。
- **方案**：对于相互独立的模块或特性分支，建立独立的 Git Worktree，在不同终端窗口并行跑不同的 Agent 会话；全部完成后在主分支集中集成回归。
- **CLI 范例**：
  ```sh
  # 建立两个独立工作区
  git worktree add ../wt-auth -b feat/auth
  git worktree add ../wt-pay -b feat/payment

  # 分别在两个终端启动，互不冲突
  cd ../wt-auth && omp "实现 JWT 鉴权模块并跑通测试"
  cd ../wt-pay && omp "实现 Webhook 校验并跑通测试"

  # 完成后在主仓库合并并全量回归
  cd /path/to/main && git merge feat/auth && git merge feat/payment && pnpm test
  ```

### 5.3 资产固化：将团队 SOP 沉淀为 Skill，接入 MCP 服务
- **痛点**：每次处理数据库变更、部署、Sentry 告警排查都要重复输入大段背景知识和规程。
- **方案**：
  - **Skill**：在 `.omp/skills/<name>/SKILL.md` 中固化 SOP，使用时一句话唤起（如 `/skill:db-migrate`）。
  - **MCP**：配置本地数据库、API 文档或监控平台只读 MCP 服务，让 Agent 自主拉取真实 schema 或告警堆栈。

### 5.4 极限缩短验证回路（目标 5 秒以内）
- **痛点**：全量测试套件耗时过长（动辄数分钟），导致 Agent 修改-反馈循环极慢。
- **方案**：
  - **精确到单用例**：下达任务时明确提供最快局部测试命令（如 `pnpm vitest run tests/auth.spec.ts -t "should reject expired token"`）。
  - **Throwaway 复现脚本**：复杂 Bug 要求 Agent 先写一个独立的 10 行最小复现脚本证明必死；修复后运行证明必过，最后删掉脚本。

### 5.5 双视角对抗审查：只读 Agent 杜绝假性通过与盲目自信
- **痛点**：实现者 Agent 容易产生“自我强化偏见”（认为自己写的代码必然正确），人工审长 diff 又容易漏看隐蔽边界。
- **方案**：合并前开启无状态只读 Agent 进行对抗性 Review，剥离写权限，专门挑刺。
- **CLI 范例**：
  ```sh
  git diff | omp -p --no-mcp --tools read,grep "以严格资深工程师视角审查当前 diff：
  1. 是否遗漏边缘分支、空指针或并发竞态条件？
  2. 是否改动了原本不该修改的代码？
  3. 如有问题，给出确凿代码依据，不提无意义的格式建议。"
  ```

---

## 6. 提效速查对照表 (Efficiency Cheat Sheet)

| 阶段 | 低效做法 (传统模式) | 高效做法 (推荐模式) | 预期收益 |
| :--- | :--- | :--- | :--- |
| **准备期** | 每次手打大段项目规范与环境背景 | 根目录 `AGENTS.md` + 软链接常识化 | 节省 80% 会话前置输入 |
| **调研期** | 让昂贵主力模型全局漫无目的 grep | 轻量只读 Scout 预摸清关键文件与行号 | 保护主注意力，降低 50% 等待耗时 |
| **执行期** | 串行做一个等一个，人盯屏幕 | 2~3 个 Git Worktrees 并行跑不同分支 | 吞吐量提升 2~3 倍 |
| **验证期** | 每次微调都跑数分钟的全量 CI | 精确到单函数的快测命令 / Throwaway 脚本 | 反馈耗时从分钟级降至秒级 |
| **交付期** | 人工肉眼审数百行代码，容易漏测 | 管道接只读 Agent 对抗性 Review + 运行证明 | 显著降低返工率与漏测率 |
