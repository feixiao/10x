# 10x：AI-Native 软件研发落地方案矩阵

本项目聚焦于通过现成开源与商用 AI 工具，构建高确定性、低成本且安全合规的 AI-Native 软件工程闭环。

仓库围绕**“终态目标蓝图”**与**“双版本落地实操（个人版 / 企业版）”**三大方案展开：

---

## 核心方案导航

| 方案分类 | 定位与核心价值 | 核心技术栈 / 工具矩阵 | 核心资产与落地文档 |
| :--- | :--- | :--- | :--- |
| **1. 终态目标蓝图**<br>*(Blueprint)* | 1 名人类架构师 + 4 专职 Agent 协同编排 + MCP 矩阵 + 混合算力底座的全生命周期蓝图 | 人类架构师 + 调度中枢 + Planner / Coder / QA / DevOps 专职角色 + 熔断机制 | 📖 [目标蓝图文档](./ai_native.md) |
| **2. 个人落地指南**<br>*(Solo Edition)* | 单兵多任务物理隔离并行、TDD 单测自愈闭环、节省 80% 云端算力成本 | **Aider + LiteLLM + 本地 Ollama + Git Worktree** | 📖 [Solo Edition 指南](./docs/SOLO_EDITION_GUIDE.md)<br>🛠️ 调度器 [`scripts/solo-worktree.sh`](./scripts/solo-worktree.sh)<br>⚙️ 配置 [`configs/solo/`](./configs/solo/) |
| **3. 企业级安全合规**<br>*(Enterprise Edition)* | 面向产研团队的统一安全审计、容器沙盒权限收敛与 CI 反作弊双阶段质量门禁 | **LiteLLM Proxy (PG 审计) + OpenHands 容器沙盒 + CI 门禁** | 📖 [Enterprise 指南](./docs/ENTERPRISE_EDITION_GUIDE.md)<br>🐳 沙盒部署 [`deploy_openhands.sh`](./deploy_openhands.sh)<br>🛡️ 门禁脚本 [`scripts/audit-diffs.sh`](./scripts/audit-diffs.sh)<br>⚙️ 部署配置 [`configs/enterprise/`](./configs/enterprise/) |

---

## 一、方案概要

### 1. AI-Native 超级个体全生命周期研发落地方案 (终态目标蓝图)
* **核心目标**：将传统软件研发团队（产品、架构、开发、测试、运维）浓缩为“1 名人类架构师 + 多 Agent 协同 + MCP 矩阵 + 混合算力底座”。
* **四大硬核防线**：
  1. **熔断机制 (Circuit Breaker)**：单测或构建连续 3 次失败强制挂起，通知人类介入，杜绝死循环账单爆炸；
  2. **上下文物理隔离**：禁止单 Agent 滚雪球对话，以磁盘状态契约（`spec.md` / `tasks.md` / `git diff`）为唯一上下文媒介；
  3. **Git Worktree 并发隔离**：多 Agent 分配独立物理目录与分支，避免文件锁冲突与 Git 索引损坏；
  4. **MCP 安全红线**：只读账号巡检 + 运维高危命令正则拦截。
* **详细落地**：查看 [`ai_native.md`](./ai_native.md)。

---

### 2. 个人超级个体落地指南 (Solo Edition)
* **核心目标**：单人单机（MacBook / Linux 工作站）同时推进多个需求，本地跑日常代码，云端负责顶层架构，算力成本节约 80%。
* **工作流拓扑**：
  ```
  人类架构师 (任务契约)
          │
          ▼
  scripts/solo-worktree.sh 调度器
    ├── Worktree A (分支 feat/auth)  ──> Aider (带 --test-cmd 单测自愈) ──┐
    └── Worktree B (分支 fix/cache)  ──> Aider (带 --test-cmd 单测自愈) ──┤
                                                                         ▼
                                                           LiteLLM 本地网关 (:4000)
                                                                 ├── 20% 架构拆解: 云端旗舰 (Claude/DeepSeek)
                                                                 └── 80% 代码实现: 本地 Ollama (Qwen2.5-Coder)
  ```
* **开箱即用**：
  ```bash
  # 1. 启动本地混合网关
  litellm --config configs/solo/litellm.yaml --port 4000

  # 2. 一键拉起隔离车间并启动 Aider 自动跑测
  ./scripts/solo-worktree.sh start feat-auth "pytest tests/"

  # 3. 验收合入前执行反作弊双阶段盲审
  ./scripts/audit-diffs.sh main...HEAD .audit
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

## 目录结构

```
.
├── README.md                           # 方案矩阵总览与快速导航
├── ai_native.md                        # 方案 1: AI-Native 超级个体全生命周期终态目标蓝图
├── docs/
│   ├── SOLO_EDITION_GUIDE.md           # 方案 2: 个人超级个体落地指南 (Solo Edition)
│   └── ENTERPRISE_EDITION_GUIDE.md     # 方案 3: 企业级安全合规落地指南 (Enterprise Edition)
├── configs/
│   ├── solo/                           # 个人版配套配置
│   │   ├── litellm.yaml                # 混合路由模型映射表 (本地 Ollama + 云端 API)
│   │   └── .aider.conf.yml             # Aider 自动化架构师模式与跑测预设
│   └── enterprise/                     # 企业版配套配置
│       ├── litellm.yaml                # 审计网关与虚拟 Key 配额定义
│       └── docker-compose.enterprise.yml # LiteLLM Proxy + PostgreSQL 全量审计持久化
├── scripts/
│   ├── solo-worktree.sh                # 个人版多任务 Git Worktree 物理隔离调度器
│   └── audit-diffs.sh                  # 双阶段防测试篡改差异分离脚本 (Solo & CI 通用)
└── deploy_openhands.sh                 # 企业级 OpenHands 容器沙盒一键部署与管理脚本
```
