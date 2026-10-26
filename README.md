# 10x：AI-Native 软件研发落地方案矩阵

本项目聚焦于通过现成开源与商用 AI 工具，构建高确定性、低成本且安全合规的 AI-Native 软件工程闭环。

仓库围绕**“终态目标蓝图与主控实现”**及**“个人版 / 企业版落地实操”**展开：

---

## 核心方案导航

| 方案分类 | 定位与核心价值 | 核心技术栈 / 工具矩阵 | 核心资产与落地文档 |
| :--- | :--- | :--- | :--- |
| **1. 终态目标蓝图与实现**<br>*(Blueprint & Engine)* | 1 名人类架构师 + 4 专职 Agent 协同编排 + MCP 矩阵 + 混合算力底座的全生命周期实现 | 主控状态机调度器 + Planner / Coder / QA / DevOps 专职角色 + 熔断保护 + 安全 MCP | 📖 [目标蓝图文档](./ai_native.md)<br>🕹️ 主控调度器 [`scripts/supervisor.py`](./scripts/supervisor.py)<br>🔌 MCP 矩阵 [`mcp_servers/`](./mcp_servers/) |
| **2. 个人落地指南 (阶段一)**<br>*(Solo Edition)* | 单兵多任务物理隔离并行、TDD 单测自愈闭环、本地模型分流降低算力账单 | **Aider + LiteLLM + 本地 Ollama + Git Worktree** | 📖 [Solo Edition 指南](./docs/SOLO_EDITION_GUIDE.md)<br>🛠️ 调度器 [`scripts/solo-worktree.sh`](./scripts/solo-worktree.sh)<br>⚙️ 配置 [`configs/solo/`](./configs/solo/) |
| **3. 企业级安全合规**<br>*(Enterprise Edition)* | 面向产研团队的统一安全审计、容器沙盒权限收敛与 CI 反作弊双阶段质量门禁 | **LiteLLM Proxy (PG 审计) + OpenHands 容器沙盒 + CI 门禁** | 📖 [Enterprise 指南](./docs/ENTERPRISE_EDITION_GUIDE.md)<br>🐳 沙盒部署 [`deploy_openhands.sh`](./deploy_openhands.sh)<br>🛡️ 门禁脚本 [`scripts/audit-diffs.sh`](./scripts/audit-diffs.sh)<br>⚙️ 部署配置 [`configs/enterprise/`](./configs/enterprise/) |

---

## ⚡ 一键接入到你的其他项目

你可以直接使用本项目提供的一键安装脚本，秒级将方案一（Supervisor + MCP 矩阵）或方案二（Solo Worktree）注入到你的任何工程中：

```bash
# 全量安装（主控状态机调度器 + 业务与运维 MCP 矩阵 + Solo 工作车间）
./install.sh /path/to/my-other-project

# 轻量安装（仅安装 Solo 多任务 Worktree 并行调度器）
./install.sh /path/to/my-other-project --mode=solo
```
*脚本会自动复制脚本与配置、配置可执行权限，并在目标项目的 `.gitignore` 中注册安全规则。*

---
## 一、方案概要与快速上手

### 1. 终态目标蓝图与主控实现 (ai_native.md)
* **核心目标**：将传统软件研发团队（产品、架构、开发、测试、运维）浓缩为“1 名人类架构师 + 4 Agent 协同 + MCP 矩阵 + 混合算力底座”。
* **已落地的核心系统**：
  1. **主控状态机调度器 ([`scripts/supervisor.py`](./scripts/supervisor.py))**：
     - 实现 `INIT -> PLANNING -> PLAN_APPROVAL -> CODING -> TESTING -> AUDITING -> DEV_OPS_VERIFY -> DEPLOY_APPROVAL -> COMPLETED` 完整状态机；
     - **熔断机制 (Circuit Breaker)**：单测或构建连续 3 次失败自动熔断挂起，写入 `circuit_breaker_<timestamp>.json` 错误快照，防止死循环与 Token 账单爆炸；
     - **上下文物理隔离**：基于磁盘契约文件（`tasks/<id>/spec.md` 与 `tasks.md`）传递状态。
  2. **MCP 服务矩阵 ([`mcp_servers/`](./mcp_servers/))**：
     - `biz_inspector.py`：强制白名单只读从库巡检、阻断破坏性 DDL/DML 与分号堆叠注入、自动追加 `LIMIT`；
     - `infra_devops.py`：安全参数数组拉取容器错误日志（防命令注入与超长截断）、生产发布必须提供人类架构师授权令牌（`CONFIRM-PROD-...`）。
  3. **客户端挂载配置 ([`configs/mcp.json`](./configs/mcp.json))**：标准 Stdio 协议，可直接接入 Claude Desktop / Claude Code / Cursor。

```bash
# 创建并单步推进一个 AI-Native 任务
python3 scripts/supervisor.py create --task-id TASK-101 --title "JWT鉴权中间件" --test-cmd "pytest tests/"
python3 scripts/supervisor.py step --task-id TASK-101
python3 scripts/supervisor.py status --task-id TASK-101
```

---

### 2. 个人超级个体落地指南 (Solo Edition - 阶段一实操)
* **核心目标**：单人单机（MacBook / Linux 工作站）同时推进多个需求，本地跑日常代码，云端负责顶层架构，兼顾产出与算力成本。
* **工作流拓扑**：
  ```
  人类架构师 (任务契约 tasks/template.md)
          │
          ▼
  scripts/solo-worktree.sh 调度器
    ├── Worktree A (分支 feat/101-auth)  ──> Aider (带 --test-cmd 单测自愈) ──┐
    └── Worktree B (分支 fix/102-cache)  ──> Aider (带 --test-cmd 单测自愈) ──┤
                                                                             ▼
                                                               LiteLLM 本地网关 (:4000)
                                                                     ├── 架构拆解 (约20%流量): 云端旗舰 (Claude/DeepSeek)
                                                                     └── 编写实现 (约80%流量): 本地 Ollama (Qwen2.5-Coder)
  ```
* **开箱即用**：
  ```bash
  # 1. 启动本地混合网关
  litellm --config configs/solo/litellm.yaml --port 4000

  # 2. 一键拉起隔离车间并启动 Aider 自动跑测 (自动跨工作区同步任务卡)
  ./scripts/solo-worktree.sh start 101-auth "pytest tests/"

  # 3. 查看所有并发车间状态
  ./scripts/solo-worktree.sh status

  # 4. 执行反作弊双阶段代码审查
  ./scripts/solo-worktree.sh audit 101-auth

  # 5. 安全注销已合入车间 (内置未提交修改与未合并分支防御)
  ./scripts/solo-worktree.sh close 101-auth
  ```
* **详细落地**：查看 [`docs/SOLO_EDITION_GUIDE.md`](./docs/SOLO_EDITION_GUIDE.md)。

---

### 3. 企业级安全合规落地指南 (Enterprise Edition)
* **核心目标**：解决企业引入 AI 编码后的**代码资产外泄、生产高危越权、测试篡改作弊、团队账单失控**四大核心痛点。
* **三大管控体系**：
  1. **统一模型网关 (LiteLLM Proxy + PostgreSQL 审计)**：统一下发虚拟 Key，团队预算封顶管控，Prompt 与敏感代码脱敏全量录制；
  2. **沙盒容器隔离 (OpenHands Sandbox)**：通过 [`deploy_openhands.sh`](./deploy_openhands.sh) 将 Agent 执行限制在非 root 容器内部，阻断内网横向渗透；
  3. **CI/CD 反作弊双阶段质量门禁**：在 GitHub Actions / GitLab CI 中调用 [`scripts/audit-diffs.sh`](./scripts/audit-diffs.sh)，严格将业务改动（`code.diff`）与单测改动（`tests.diff`）物理切分，严防 Agent 恶意削弱断言。
* **开箱即用**：
  ```bash
  # 启动企业级审计代理与 PostgreSQL 数据库
  cd configs/enterprise
  docker compose -f docker-compose.enterprise.yml up -d
  ```
* **详细落地**：查看 [`docs/ENTERPRISE_EDITION_GUIDE.md`](./docs/ENTERPRISE_EDITION_GUIDE.md)。

---

## 自动化测试与工程验证

仓库内置了针对状态机流转、熔断保护、MCP 服务安全拦截的端到端自动化测试：

```bash
# 运行方案一与方案二核心自动化测试套件
python3 tests/test_ai_native_suite.py
```

---

## 目录结构

```
.
├── README.md                           # 方案矩阵总览与快速导航
├── install.sh                          # 外部工程一键安装快捷入口 (转发至 scripts/install.sh)
├── ai_native.md                        # 方案 1: AI-Native 超级个体全生命周期终态目标蓝图
├── docs/
│   ├── SOLO_EDITION_GUIDE.md           # 方案 2: 个人超级个体落地指南 (Solo Edition)
│   └── ENTERPRISE_EDITION_GUIDE.md     # 方案 3: 企业级安全合规落地指南 (Enterprise Edition)
├── scripts/
│   ├── install.sh                      # 一键注入与部署脚本
│   ├── supervisor.py                   # 方案 1: 主控状态机调度器 (四角色流转 + 熔断保护)
│   ├── solo-worktree.sh                # 方案 2: 个人版多任务 Git Worktree 物理隔离调度器
│   └── audit-diffs.sh                  # 双阶段防测试篡改差异分离脚本 (Solo & CI 通用)
│   ├── mcp_base.py                     # 轻量标准 MCP (Stdio / JSON-RPC 2.0) 协议基类
│   ├── biz_inspector.py                # 业务数据只读巡检 MCP (防注入/防堆叠/强制LIMIT)
│   └── infra_devops.py                 # 基础设施运维 MCP (防命令注入/截断/生产发布令牌)
├── configs/
│   ├── mcp.json                        # MCP 客户端挂载配置文件 (Claude / Cursor / OpenCode)
│   ├── solo/                           # 个人版配套配置
│   │   ├── litellm.yaml                # 混合路由模型映射表 (本地 Ollama + 云端 API)
│   │   └── .aider.conf.yml             # Aider 自动化架构师模式与跑测预设
│   └── enterprise/                     # 企业版配套配置
│       ├── litellm.yaml                # 审计网关与虚拟 Key 配额定义
│       └── docker-compose.enterprise.yml # LiteLLM Proxy + PostgreSQL 全量审计持久化
├── tasks/
│   └── template.md                     # 原子任务契约卡规范模板 (Task Spec Contract)
├── tests/
│   └── test_ai_native_suite.py         # 方案一与方案二自动化验证测试套件
└── deploy_openhands.sh                 # 企业级 OpenHands 容器沙盒一键部署与管理脚本
```
