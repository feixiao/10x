# 10x：研究现成 AI 工具如何加速研发

本项目整理公开研究、工具现有能力和可复用的研发工作方式。目标是缩短**通过验收的交付时间**，同时观察审查、返工、缺陷和工具成本。“10x”是项目名，不是已证明的提效倍数。本仓库是研究文档，不是编码 Agent 或自动化平台。

## 文档与实践指南（docs/ 目录）

### 1. 核心理论与工程规范
- [跨工具实践指南](./docs/AGENT_ENGINEERING_GUIDE.md)：公开实证与证据边界、交付闭环、并行边界、主流工具对比与效果衡量。
- [统一规则与跨工具规范](./docs/UNIFIED_AGENT_RULES.md)：Claude Code、omp 与 Pi 的统一规则架构、契约定义与多语言工程约束。
- [OMP 与 Claude Code 研发提效、全局配置与量化监控手册](./docs/OMP_CLAUDE_CODE_HANDBOOK.md)：面向 C/C++ 音视频、Go 高并发与多语言整洁架构的双擎分工、避坑全局配置（Hooks/TTSR/DAP/Swarm）及零侵入提效监控方案（配套 [`scripts/ai-metrics.sh`](./scripts/ai-metrics.sh)）。
- [无人值守任务规格与验收契约规范 (Task Spec Template)](./docs/TASK_SPEC_TEMPLATE.md)：防范围蔓延、破坏性重构与测试篡改的标准化任务拆解与黄金行为锁模板。
- [24小时 Agent 产出高效审查与验收 SOP](./docs/AGENT_DIFF_REVIEW_GUIDE.md)：15 分钟内快速定位风险、扫描作弊隐患并安全合并无人值守代码的审查流程。

### 2. 动手实战与演练
- [C++、Go、Python 动手实验](./agent-lab/README.md)：本机可构建的三个同规格费用汇总 CLI，用 Agent 完成类别筛选，并运行各语言测试与验收命令。
- [动手练习](./docs/STEP_BY_STEP.md)：从全新 Go 项目开始，先审阅三文件计划，再由两个 Agent 分工开发、单测、集成与独立验收；该练习不测提效。
- [1~2 小时重构实战指南 (omp + planning-with-files)](./docs/REFACTORING_WITH_PLANNING_FILES_GUIDE.md)：基于磁盘状态机与退出门禁（Stop Gate）的单会话自主可控重构落地指南。

### 3. Agent 环境搭建与互联
- [OpenHands 本地部署与使用指南 (配合 LMStudio)](./docs/OPENHANDS_LOCAL_LMSTUDIO_GUIDE.md)：基于 Docker 沙盒环境与本地模型 API 的部署与避坑实践指南。
- **一键部署脚本**: [`deploy_openhands.sh`](./deploy_openhands.sh) — 自动化检测 Docker、初始化 `~/volumes/openhands` 目录、启动 OpenHands 并支持与本地其他 Agent 容器网络互通。
- **OpenClaw 集成 Skill**: [`openclaw-skills/openhands/SKILL.md`](./openclaw-skills/openhands/SKILL.md) — 供 OpenClaw 调用的现成 Skill，实现通过 REST API 调度 OpenHands 容器执行复杂代码工程任务。
- **按语言定制的 AI Agent 研发套件 (Modular Agent Harnesses)**: [templates/](./templates/) 及一键安装脚本 [`scripts/install-harness.sh`](./scripts/install-harness.sh) — 按语言彻底解耦（独立 C++、Go、Python 与 Android 模版），零杂质拷贝，开箱即用。

## 开箱即用：按需拷贝对应语言的 Agent 套件

如果你日常需要维护各种**不同技术栈的独立工程**，不需要把所有语言规则混在一起。**你的项目用什么语言，就只拷贝该语言的纯净模版**：

| 你的工程技术栈 | 对应专属模版目录 | 核心针对性规范 |
| :--- | :--- | :--- |
| **纯 C++ 项目** | [`templates/cpp/`](./templates/cpp/) | CMake/CTest/ASan、RAII 内存安全、智能指针、ccache 缓存复用 |
| **纯 Go 项目** | [`templates/go/`](./templates/go/) | `go test -race`、接口解耦与 Fake 注入、Goroutine 泄漏防范 |
| **纯 Python 项目** | [`templates/python/`](./templates/python/) | `pytest`、`ruff`、`mypy` 静态类型检查、禁止裸 except、pathlib |
| **纯 Android 项目** | [`templates/android/`](./templates/android/) | Gradle 单元测试、Main 线程禁令、JNI LocalRef 释放与异常屏障 |

---

### 1. 拷贝与接入步骤 (以 C++ 项目为例)

#### 方式 A：直接全量复制对应语言模版 (最纯净推荐)
```bash
# 如果你的项目是 C++:
cp -R templates/cpp/. /path/to/my-cpp-project/

# 如果你的项目是 Go:
# cp -R templates/go/. /path/to/my-go-project/

# 进入你的工程，一键初始化环境
cd /path/to/my-cpp-project
bash scripts/setup-ai-env.sh
```

#### 方式 B：使用安装脚本自动化部署
```bash
# 语法: ./scripts/install-harness.sh <cpp|go|python|android> <目标工程路径>
./scripts/install-harness.sh cpp /path/to/my-cpp-project
```

---

### 2. 拷贝进项目后的资产结构 (以纯 C++ 为例，无任何多余语言杂质)

```
my-cpp-project/
├── AGENTS.md                   # 纯 C++ 专用主契约与 CMake/CTest 验证命令
├── CLAUDE.md -> AGENTS.md      # 自动软链接 (Claude Code 免配置识别)
├── roles/                      # 五大专职 Agent 角色定义 (主控、工兵、盲审官、记账员、支持顾问)
├── skills/                     # 纯 C++ 技能库
│   ├── internal-codemap/       # CMake Target 依赖树与 main 入口导航 (无跨语言干扰)
│   ├── project-develop/        # C++ 专向硬约束 (RAII、裸指针跨线程禁令、ASan 门禁)
│   ├── project-autopilot/      # 主从隔离自动驾驶 (零代码主控按 Worktree 调度工兵)
│   ├── internal-audit/         # C++ 专向双阶段盲审防线 (悬垂指针、Double-Free 排查)
│   └── project-support/        # 只读技术支持技能 (严禁修改代码)
├── scripts/
│   ├── setup-ai-env.sh         # 软链接建立与 ccache 缓存自检脚本
│   └── audit-diffs.sh          # 自动分离 C++ 业务代码与单测代码的物理切分脚本
└── tasks/
    ├── tracker.md              # 任务流水线总表
    └── templates/
        └── topic-template.md   # C++ 专向任务卡模版 (#101~#10N)
```

---

### 3. 日常研发使用 SOP（3 步走）

1. **确认/微调入口（仅需 1 分钟）**：
   - 拷贝完成后，打开 `skills/internal-codemap/references/`，按需记录你项目的核心头文件或 CMake Target。
2. **立项与自动驾驶推进**：
   - 复制 `tasks/templates/topic-template.md` 至 `tasks/feat-xxx.md`，在 `tasks/tracker.md` 注册为 `ready`；
   - 启动主控 Agent（如 Claude Code 或 Cursor），让其读取 `tracker.md` 并调度 Worker Agent 在独立 Git Worktree 中完成代码与单测闭环。
3. **合并前双阶段盲审**：
   - 提交人工 Review 前，在目标分支运行：
     ```bash
     ./scripts/audit-diffs.sh origin/main...HEAD .audit
     ```
   - 启动全新会话的独立审查 Agent，加载 `skills/internal-audit` 技能。第一阶段仅给 `.audit/code.diff` 逆向排查语言级内存漏洞与边界；第二阶段追加 `.audit/tests.diff` 与 `.audit/message.txt` 严核测试篡改作弊。
## 当前工作假设（待真实任务验证）

1. 有现成测试、边界清楚的小改：先用一个编码 Agent 完成实现和局部单测，再由项目 CI 和真实行为验收。Pi 或 Claude Code 都可承担。
2. 搜索、日志调查或独立审查占用大量上下文：用只读子 Agent 或独立会话返回证据；让主会话集成决策。
3. 大量独立迁移可考虑 Claude Code `/batch`；需要成员沟通的复杂任务可考虑实验性的 Agent Teams；Pi 基础版不内置子 Agent，多会话并行需独立管理和集成。
4. 并行任务按文件或模块划清归属。各自单测通过后，仍须在**集成版本**运行回归与验收。无法自动判断的协议、并发、媒体与性能结论要有可重复的实测证据。

已有研究既观察到提效，也观察到减速；其任务、人员与工具版本不同，不能直接推算本人的收益。研究数字、来源和限制详见 [跨工具实践指南](./docs/AGENT_ENGINEERING_GUIDE.md)。遇到具体选型争议时，再用少量真实任务记录目标仓库版本、工具与模型、验收结果、准备与等待时间、审查与返工、费用；根据这些数据修订建议。无需先建设新编排器或开展固定周期的实验。
