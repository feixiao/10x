# AI-Native 超级个体（One-Person Team）全生命周期研发落地方案 (终态目标蓝图)

> **文档定位**：将传统企业级软件研发团队（产品、架构、全栈开发、QA 测试、DevOps 运维）浓缩为**“1 名人类架构师 + 多 Agent 协同编排 + MCP 工具矩阵 + 混合算力底座”**的工程化实战蓝图。
> 
> **代码对应关系**：
> - 调度中枢与状态机熔断器：[`scripts/supervisor.py`](./scripts/supervisor.py)
> - 业务与运维 MCP 矩阵：[`mcp_servers/biz_inspector.py`](./mcp_servers/biz_inspector.py) 与 [`mcp_servers/infra_devops.py`](./mcp_servers/infra_devops.py)
> - 任务契约规范模板：[`tasks/template.md`](./tasks/template.md)
> - 个人版落地推进（阶段一实操）：[`docs/SOLO_EDITION_GUIDE.md`](./docs/SOLO_EDITION_GUIDE.md) 与 [`scripts/solo-worktree.sh`](./scripts/solo-worktree.sh)

---

## 一、 方案审查与工程化加固（Review & Refinements）

在将架构构想转化为可执行的工程系统时，重点实施四大确定性防护机制：

1. **防死循环与账单爆炸（Circuit Breaker 熔断机制）**
   * **痛点**：Coder Agent 与 QA Agent 自动打回重写时，若遇到环境配置或深层逻辑死结，极易陷入无限报错循环，消耗大量 Token。
   * **加固实现**：在 Supervisor 编排层强制设定 `max_retries = 3`（见 `scripts/supervisor.py`）。连续 3 次单测未通过，自动挂起当前任务并写入 `circuit_breaker_<timestamp>.json` 快照，等待人类架构师介入 `unblock`。
2. **防上下文污染（Context Isolation 上下文物理隔离）**
   * **痛点**：单个 Agent 长会话会导致上下文窗口塞满废弃报错日志，引发模型“注意力稀释”与幻觉。
   * **加固实现**：以磁盘文件（`tasks/<id>/spec.md`、`tasks/<id>/tasks.md`、`git diff`）作为 Agent 之间的**唯一状态传递媒介**。每个子 Agent 唤醒时仅加载干净的目标切片，用完即销毁会话。
3. **防多 Agent 改代码冲突（Git Worktree 物理隔离）**
   * **痛点**：多个 Agent 同时在同一个工作目录修改代码会导致文件锁死或 Git 索引损坏。
   * **加固实现**：利用 `git worktree` 为每个并发执行的任务分配独立的物理文件夹与独立分支，单测全绿并通过双阶段盲审后统一合并回主干。
4. **安全红线硬编码（Deterministic Guardrails）**
   * **痛点**：仅靠 Prompt 叮嘱 Agent “不要删库、不要乱改生产配置”不可靠。
   * **加固实现**：在 MCP Server 代码层实施硬编码拦截（只读连接池 + 禁止多语句分号注入 + 生产发布强制人类确认令牌）。

---

## 二、 核心架构：1 人类总监 + 1 调度中枢 + 4 专职硅基员工

```
                        +-----------------------------------+
                        |     人类架构师 (Tech Lead / You)    |
                        |  需求拍板 · 架构审批 · 生产发布放行  |
                        +-----------------+-----------------+
                                          |
                                          v
                        +-----------------------------------+
                        |   主控调度器 (scripts/supervisor.py)|
                        |  任务拆解 · 状态机流转 · 熔断监控    |
                        +-----------------+-----------------+
                                          |
        +---------------------+-----------+-----------+---------------------+
        |                     |                       |                     |
        v                     v                       v                     v
+---------------+     +---------------+       +---------------+     +---------------+
| 1. 架构 Agent  |     | 2. 研发 Agent  |       | 3. 质量 Agent  |     | 4. 运维 Agent  |
|   (Planner)   |     |    (Coder)    |       | (QA/Reviewer) |     | (DevOps/SRE)  |
+-------+-------+     +-------+-------+       +-------+-------+     +-------+-------+
        |                     |                       |                     |
        +---------------------+-----------+-----------+---------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        MCP 服务矩阵 (Model Context Protocol)                       |
|   [mcp_servers/biz_inspector.py]           [mcp_servers/infra_devops.py]          |
|   - 只读数据库巡检 (防注入/限行)              - 容器错误日志拉取 (防命令注入/截断保护)  |
|   - 业务数据模型 Schema 检视                - 生产发布授权令牌门禁                    |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        混合算力网关 (LiteLLM / 统一路由底座)                        |
|   • 云端重推理模型：Claude 3.7 Sonnet / DeepSeek-R1 (架构设计、核心攻坚)            |
|   • 本地高吞吐模型：LMStudio (Qwen3.8 / Gemma4，样板代码、单测与日志清洗)             |
+-----------------------------------------------------------------------------------+
```

### 角色职责与模型路由矩阵

| 虚拟角色 | 对应岗位职责 | 驱动引擎与模型路由策略 | 输入契约 | 输出交付物与验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| **人类架构师 (You)** | 技术选型、核心把关 | 人类大脑 | 业务痛点、产品直觉 | 需求指令、高危操作 `Y/N` 审批、最终合并确认 |
| **1. 架构与产品 Agent**<br>*(Planner)* | 需求分析、系统设计 | **云端重推理模型**<br>*(Claude Sonnet / DeepSeek-R1)* | 一句话需求 + 现有仓库目录树 | 1. 架构设计文档 (`spec.md`)<br>2. 接口契约<br>3. 原子化任务清单 (`tasks.md`) |
| **2. 全栈研发 Agent**<br>*(Coder)* | 编码实现、迭代优化 | **混合路由 / 本地模型主写**<br>*(云端出核心算法 + 本地模型写样板)* | `tasks.md` 中的单个子任务 | 1. 业务代码实现<br>2. 本地编译通过且无 Linter 报错 |
| **3. 质量门禁 Agent**<br>*(QA / Reviewer)* | 测试覆盖、代码审查 | **本地高吞吐模型 + 脚本门禁**<br>*(低边际成本批量回归)* | `git diff` 增量代码 + `spec.md` | 1. 边界单元测试用例<br>2. 静态安全分析报告<br>3. 双阶段反作弊代码审查报告 |
| **4. 运维发布 Agent**<br>*(DevOps / SRE)* | 部署集成、AIOps 运维 | **轻量化模型 + 专属运维 MCP** | 合入主干的 Release 版本 / 错误日志 | 1. Dockerfile / 配置更新<br>2. 异常日志 RCA 报告<br>3. 待人类确认的发布指令 |

---

## 三、 算力底座与并行开发环境

### 1. 基于 `git worktree` 的多任务物理并行
避免单目录切换分支带来的上下文丢失与编译缓存污染，在本地通过 Worktree 调度物理隔离工作区：
```bash
# 查看当前活跃车间与修改状态
./scripts/solo-worktree.sh status

# 启动新任务并挂载单测自愈
./scripts/solo-worktree.sh start 101-jwt-auth "pytest tests/"
```

### 2. 混合算力分流策略 (Cost & Throughput Balancing)
* **重度思考层 (目标约 20% 请求)**：顶层架构设计、跨多文件重构设计，路由至云端旗舰模型；
* **高频执行层 (目标约 80% 请求)**：样板代码填充、单元测试编写与自愈、万行级日志拉取与清洗，由本地 LMStudio 承接，大幅压降云端 API 依赖。

---

## 四、 已实现的 MCP 服务矩阵 (`mcp_servers/`)

仓库已内置标准化、开箱即用的 Python MCP Stdio 服务（无强制外部三方依赖）：

### 1. `biz-inspector-mcp` (业务只读检视服务)
* **文件路径**：[`mcp_servers/biz_inspector.py`](./mcp_servers/biz_inspector.py)
* **核心工具**：
  * `query_readonly_db(sql_query, max_rows=50)`：强制只读白名单（`SELECT/EXPLAIN/SHOW`），严禁修改关键词（`DROP/DELETE/UPDATE`），禁止分号堆叠注入，自动追加 `LIMIT`；
  * `inspect_schema(table_name)`：检视数据库 DDL 结构；
  * `inspect_redis_keys(pattern, limit)`：抽检缓存键状态。

### 2. `infra-devops-mcp` (远程基础设施运维服务)
* **文件路径**：[`mcp_servers/infra_devops.py`](./mcp_servers/infra_devops.py)
* **核心工具**：
  * `fetch_container_logs(service_name, lines=100)`：服务名白名单校验（禁止非法控制符），非 shell 数组安全执行，8000 字符截断保护；
  * `check_service_status(service_name)`：检查服务健康度与资源占用；
  * `trigger_deploy(environment, confirmation_token)`：生产环境强制要求人类架构师授权令牌（`CONFIRM-PROD-...`），严防 AI 越权发布。

### 3. 客户端注册配置 (`configs/mcp.json`)
可直接挂载至 Claude Desktop、Claude Code 或 Cursor：
```json
{
  "mcpServers": {
    "biz-inspector": {
      "command": "python3",
      "args": ["mcp_servers/biz_inspector.py"]
    },
    "infra-devops": {
      "command": "python3",
      "args": ["mcp_servers/infra_devops.py"]
    }
  }
}
```

---

## 五、 主控调度器 CLI 实操 (`scripts/supervisor.py`)

主控调度器实现了完整的状态机流转与熔断控制：

```bash
# 1. 创建全生命周期任务
python3 scripts/supervisor.py create \
  --task-id TASK-101 \
  --title "JWT统一鉴权" \
  --test-cmd "pytest tests/test_auth.py" \
  --max-retries 3

# 2. 单步推进任务 (可在关键节点审查并按 Y 放行)
python3 scripts/supervisor.py step --task-id TASK-101

# 3. 自动全流程推进 (适合无人值守，遇到熔断或终审自动挂起)
python3 scripts/supervisor.py run --task-id TASK-101

# 4. 查看当前任务阶段、重试次数与流转日志
python3 scripts/supervisor.py status --task-id TASK-101

# 5. 当触发 3 次失败熔断后，人工排查并解除锁定
python3 scripts/supervisor.py unblock --task-id TASK-101
```

---

## 六、 实施路线图与落地进展

- [x] **第一阶段：单兵外骨骼与自愈闭环（已在方案二 Solo Edition 落地）**
  - [x] Git Worktree 物理隔离与状态调度器 (`scripts/solo-worktree.sh`)
  - [x] 双模型混合分流配置 (`configs/solo/litellm.yaml` + `.aider.conf.yml`)
  - [x] 双阶段反作弊代码与测试物理隔离门禁 (`scripts/audit-diffs.sh`)
- [x] **第二阶段：MCP 神经系统与安全护栏（已在本方案落地）**
  - [x] 业务只读排查与防注入 MCP (`mcp_servers/biz_inspector.py`)
  - [x] 远端容器运维与发布令牌 MCP (`mcp_servers/infra_devops.py`)
  - [x] 通用 Stdio 协议基类与客户端挂载配置 (`configs/mcp.json`)
- [x] **第三阶段：多 Agent 自治编排与熔断防护（已在本方案落地）**
  - [x] 主控状态机调度器 (`scripts/supervisor.py`)
  - [x] `Planner -> Coder -> QA -> DevOps` 四角色生命周期流转
  - [x] 连续 3 次失败自动熔断挂起与错误快照机制
  - [x] 全套自动化回归测试套件 (`tests/test_ai_native_suite.py`)
