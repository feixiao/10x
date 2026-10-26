# AI-Native 超级个体（One-Person Team）全生命周期研发落地方案

> **文档定位**：将传统企业级软件研发团队（产品、架构、全栈开发、QA 测试、DevOps 运维）浓缩为**“1 名人类架构师 + 多 Agent 协同编排 + MCP 工具矩阵 + 混合算力底座”**的工程化实战蓝图。

---

## 一、 方案审查与工程化加固（Review & Refinements）

在将此前的架构构想转化为可执行的工程方案前，针对“一人成军”在实战中最容易遇到的四个隐性大坑进行了加固升级：

1. **防死循环与账单爆炸（Circuit Breaker 熔断机制）**
   * **痛点**：Coder Agent 与 QA Agent 自动打回重写时，若遇到环境配置或深层逻辑死结，极易陷入无限报错循环，一夜之间烧光云端 Token。
   * **加固方案**：在 Supervisor 编排层强制设定 `max_retries = 3`。连续 3 次单测未通过或编译失败，自动挂起当前分支任务，保存错误上下文快照并向人类发送通知，交由人类介入拍板。
2. **防上下文污染（Context Isolation 上下文隔离）**
   * **痛点**：单个 Agent 从头干到尾会导致上下文窗口塞满废弃的报错日志，引发模型“注意力稀释”和幻觉（越改越乱）。
   * **加固方案**：以本地文件（`specs.md`、`tasks.md`、`git diff`）作为 Agent 之间的**唯一状态传递媒介**。每个子 Agent 唤醒时仅加载干净的系统提示词与当前任务切片，用完即销毁会话。
3. **防多 Agent 改代码冲突（Git Worktree 物理隔离）**
   * **痛点**：多个 Agent 同时在同一个工作目录修改代码会导致文件锁死或 Git 索引损坏。
   * **加固方案**：利用 `git worktree` 为每个并发执行的 Agent 分配独立的物理文件夹与独立分支，测试全绿后统一通过本地 Pull Request 合入主干。
4. **安全红线硬编码（Deterministic Guardrails）**
   * **痛点**：仅靠 Prompt 叮嘱 Agent “不要删库、不要乱改生产配置”不可靠。
   * **加固方案**：在 MCP Server 代码层与本地 Shell 包装层实施硬编码拦截（只读账号隔离 + 高危命令正则黑名单 + 人工按键确认）。

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
                        |   主控调度器 (opencode / Supervisor)|
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
|   [业务库只读巡检 MCP]        [远端容器与日志运维 MCP]        [私有轮子与文档库 MCP]   |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        混合算力网关 (LiteLLM / 统一路由底座)                        |
|   • 云端重推理模型：Claude 3.7/4 Sonnet, DeepSeek-R1 (负责架构设计、核心疑难攻坚)     |
|   • 本地大内存算力：本地常驻高吞吐 MoE / QAT 模型 (负责全量索引、单测生成、日志巡检)    |
+-----------------------------------------------------------------------------------+
```

### 角色职责与模型路由矩阵

| 虚拟角色 | 对应岗位职责 | 驱动引擎与模型路由策略 | 输入契约 | 输出交付物与验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| **人类架构师 (You)** | 技术选型、核心把关 | 人类大脑 | 业务痛点、产品直觉 | 一句话需求指令、高危操作 `Y/N` 审批、最终合并确认 |
| **1. 架构与产品 Agent**<br>*(Planner)* | 需求分析、系统设计 | **云端重推理模型**<br>*(Claude Sonnet / DeepSeek-R1)* | 一句话需求 + 现有仓库目录树 | 1. 架构设计文档 (`docs/spec.md`)<br>2. 接口/数据结构契约<br>3. 原子化任务清单 (`tasks.md`) |
| **2. 全栈研发 Agent**<br>*(Coder)* | 编码实现、迭代优化 | **opencode + 混合路由**<br>*(云端写核心逻辑 + 本地模型写样板)* | `tasks.md` 中的单个子任务 | 1. 符合规范的业务代码<br>2. 本地编译通过且无 Linter 报错 |
| **3. 质量门禁 Agent**<br>*(QA / Reviewer)* | 测试覆盖、代码审查 | **本地大内存常驻模型**<br>*(零 Token 成本无限跑)* | `git diff` 增量代码 + `spec.md` | 1. 边界单元测试用例 (Pytest/Vitest)<br>2. 静态安全与架构合规报告<br>3. 不通过则附带报错堆栈打回 Coder |
| **4. 运维发布 Agent**<br>*(DevOps / SRE)* | 部署集成、AIOps 运维 | **轻量化模型 + 专属运维 MCP** | 合入主干的 Release 版本 / 线上告警 | 1. Dockerfile / Nginx 配置更新<br>2. 线上异常根因分析报告 (RCA)<br>3. 待人类确认的发布/回滚指令 |

---

## 三、 算力底座与并行开发环境配置

### 1. 基于 `git worktree` 的多 Agent 并行车间
避免单目录切换分支带来的上下文丢失与编译缓存污染，在本地建立如下物理目录结构：

```bash
~/workspace/my-enterprise-app/
├── main/                  # 主分支：人类日常检视与生产发布基线
├── worktrees/
│   ├── feat-mcp-server/   # 终端窗口 1：opencode 实例 A 正在开发新模块
│   ├── fix-slow-query/    # 终端窗口 2：opencode 实例 B 正在优化数据库慢查询
│   └── test-coverage/     # 后台守护进程：本地 QA Agent 正在自动补全单测
```

**常用并发调度命令封装（可写入 `.zshrc`）：**
```bash
# 快速拉起一个带独立分支的 Agent 工作车间
new-agent-task() {
    local branch_name=$1
    git worktree add "../worktrees/${branch_name}" -b "${branch_name}"
    cd "../worktrees/${branch_name}" && opencode
}
```

### 2. 软硬件协同的混合模型路由策略
* **重度思考层（占比 20% 流量）**：架构设计、跨多文件重构、并发竞争 Bug 排查，路由至云端旗舰 API。
* **高频执行层（占比 80% 流量）**：利用本地大内存工作站（如 128GB 统一内存设备）常驻高吞吐 MoE 模型（如 Qwen3 系列或 Gemma 4 QAT 量化模型），承担代码库实时 Embedding、全天候单元测试生成、万行级服务器日志清洗脱敏、技术文档与注释同步，实现 **“零边际成本的算力自由”**。

---

## 四、 MCP 服务矩阵设计（给 AI 装上“手和脚”）

对应岗位职责中的 **“设计并开发 MCP 服务，实现 AI 能力与现有业务系统的无缝集成”**，使用 Python `FastMCP` 构建一套标准化的内部服务网关：

### 1. 核心自研 MCP 清单

1. **`biz-inspector-mcp`（业务数据与状态检视服务）**
   * **Resources**：暴露数据库表结构 Schema、核心业务枚举字典。
   * **Tools**：`query_readonly_db`（强制带 `LIMIT` 与超时锁的只读 SQL 执行器）、`inspect_redis_keys`（缓存状态抽检）。
2. **`infra-devops-mcp`（远程基础设施与容器运维服务）**
   * **Tools**：`fetch_container_logs`（拉取远端 Ubuntu 服务器指定 Docker 容器最新 N 行错误日志）、`check_nginx_status`（检查反代与证书状态）、`trigger_deploy`（触发构建发布，强制绑定人工确认钩子）。
3. **`private-wheels-mcp`（个人核心代码资产与文档检索服务）**
   * **Resources**：挂载个人沉淀的底层工具库（如 C++/Python 跨语言绑定模板、通用鉴权中间件、UI 组件库文档），确保 Agent 优先调用既有轮子。

### 2. 自定义 MCP Server 标准代码骨架 (`infra_mcp_server.py`)

```python
from mcp.server.fastmcp import FastMCP
import subprocess
import re

# 初始化企业级内部运维 MCP 服务
mcp = FastMCP("Infra-DevOps-Server")

# 安全护栏：高危 SQL / 命令黑名单
FORBIDDEN_PATTERNS = re.compile(r"\b(rm\s+-rf|drop\s+table|truncate|shutdown|reboot)\b", re.I)

@mcp.tool()
def fetch_service_error_logs(service_name: str, lines: int = 100) -> str:
    """
    拉取远端生产/测试服务器指定容器的最新错误日志，用于 AI 自动根因分析 (RCA)。
    """
    safe_lines = min(max(10, lines), 500)  # 限制单次拉取行数，防止撑爆上下文
    cmd = ["ssh", "ubuntu@prod-server", f"docker logs --tail {safe_lines} {service_name} 2>&1"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        return result.stdout[-8000:]  # 截断保护
    except Exception as e:
        return f"[MCP Error] Failed to fetch logs: {str(e)}"

@mcp.tool()
def execute_readonly_sql(sql_query: str) -> str:
    """
    在只读业务从库上执行数据排查查询。仅允许 SELECT / EXPLAIN 语句。
    """
    cleaned = sql_query.strip()
    if not cleaned.upper().startswith(("SELECT", "EXPLAIN", "SHOW")):
        return "[Security Blocked] 仅允许执行只读查询语句 (SELECT/EXPLAIN/SHOW)！"
    if FORBIDDEN_PATTERNS.search(cleaned):
        return "[Security Blocked] 检测到高危关键字，操作已拦截！"
    
    # 此处对接只读数据库连接池执行查询...
    return f"Executed safely: {cleaned}"

if __name__ == "__main__":
    mcp.run()
```

---

## 五、 最佳实践沉淀：标准化工程资产模板

对应岗位职责中的 **“编写高质量技术文档、总结 AI 融合开发最佳实践、推动团队技术能力提升”**。在一人团队中，所有的规范文档都是写给 Agent 看的**“可执行契约”**。

### 1. 项目根目录宪章模板 (`AGENTS.md` / `CLAUDE.md`)

将该文件置于所有项目的根目录，作为每个 Agent 启动时的必读上下文：

```markdown
# Project Architecture & Agent Guidelines (AGENTS.md)

## 1. 架构与技术栈红线 (Tech Stack Constraints)
- **后端**：Python 3.12+ (FastAPI / Pydantic v2)，包管理强制使用 `uv`，严禁混用 `pip` 或 `poetry`。
- **核心性能模块**：C++20 扩展模块通过 `pybind11` / `nanobind` 暴露接口，修改后必须执行 `pytest tests/cpp_bindings/`。
- **前端/客户端**：TypeScript Strict 模式，禁止出现裸 `any` 类型。
- **部署环境**：Ubuntu 24.04 LTS + Docker Compose + Nginx 反代。

## 2. 编码与架构铁律 (Coding Rules)
- **单一职责与文件体积**：单个代码文件严禁超过 400 行；超过时必须先拆分子模块再继续开发。
- **异常处理**：所有外部 I/O（数据库、网络请求、MCP 调用）必须包含显式超时设置与结构化日志记录（使用 `structlog`）。
- **配置隔离**：严禁在代码中硬编码任何 IP、密钥或端口，统一通过 `pydantic-settings` 从 `.env` 读取。

## 3. 自愈与防呆备忘录 (Pitfalls & Lessons Learned)
> Agent 每次因环境或特定框架特性踩坑被人类纠正后，必须自动在此追加一行记录：
- [2026-04] 修改数据库 Model 后，必须先运行 `alembic revision --autogenerate` 检查迁移脚本，不可直接修改生产表。
- [2026-04] 本地并发测试时需使用独立的 SQLite 内存库或测试 Schema，禁止污染本地开发主库。
```

### 2. 可复用技能包矩阵 (`~/.agent-skills/`)

将高频研发动作沉淀为跨项目复用的标准 Skill 模板：
* **`skill-spec-to-code`**：读取需求简述 $\rightarrow$ 检索 MCP 现有表结构 $\rightarrow$ 生成 `spec.md` 与接口契约 $\rightarrow$ 等待人类审批。
* **`skill-tdd-loop`**：先根据契约编写失败的单元测试 $\rightarrow$ 编写业务实现代码 $\rightarrow$ 循环运行测试直至全绿（上限 3 次）。
* **`skill-auto-doc`**：解析当前分支与 `main` 分支的 `git diff` $\rightarrow$ 自动更新 `README.md`、OpenAPI 文档及 `CHANGELOG.md`。

---

## 六、 一人研发团队的日常标准作业程序 (Daily SOP)

当你把上述体系搭建完毕后，你每天的工作流将从“苦力码农”彻底转变为“研发指挥官”：

1. **早间立会（10 分钟）**
   * 检查昨夜本地后台 QA Agent 跑完的单元测试覆盖率报告与静态扫描 PR。
   * 审阅运维 Agent 生成的线上服务健康巡检日报（流量峰值、慢查询汇总、异常日志聚类）。
2. **需求投喂与架构拍板（30 分钟）**
   * 打开主控终端，向 **Planner Agent** 输入今天要做的 2~3 个新特性或优化项。
   * 审查 Agent 生成的 `spec.md` 与 `tasks.md`，微调数据结构或架构边界，输入 `Approved` 放行。
3. **多线并行自动驾驶（全天后台运行）**
   * 启动 2~3 个 `git worktree` 车间，让 **Coder Agent** 与 **QA Agent** 自动结对编程（写代码 $\rightarrow$ 跑测试 $\rightarrow$ 修报错）。
   * 你只需要专注于最核心的算法设计、业务决策，或者处理触发了 3 次熔断告警的疑难杂症。
4. **晚间验收与一键发布（20 分钟）**
   * 检视各个 Worktree 提交的 Pull Request（重点看核心逻辑与安全边界）。
   * 合并分支，唤醒 **DevOps Agent** 执行预发布验证，在终端按下 `Y` 完成生产环境平滑升级，随后触发 `skill-auto-doc` 自动归档当日技术文档。

---

## 七、 三阶段实施路线图（Checklist）

- [ ] **阶段一：单兵外骨骼武装（Day 1 - Day 7）**
  - [ ] 在主力项目中创建并完善第一版 `AGENTS.md`。
  - [ ] 配置好 `opencode` 终端工作流与 `git worktree` 快捷脚本。
  - [ ] 提炼并固化 3 个最常用的代码生成、单测补全与文档同步 Skill。
- [ ] **阶段二：MCP 神经系统接入（Day 8 - Day 21）**
  - [ ] 使用 `FastMCP` 开发 `biz-inspector-mcp`（打通数据库只读排查）。
  - [ ] 开发 `infra-devops-mcp`（打通远端 Ubuntu 容器日志拉取与状态巡检）。
  - [ ] 验证安全护栏（黑名单正则拦截与写操作人工审批确认）。
- [ ] **阶段三：混合算力与多 Agent 自治闭环（Day 22 - Day 30）**
  - [ ] 部署本地统一模型网关，打通“云端重推理 + 本地大内存常驻模型”的自动分流。
  - [ ] 跑通 `Planner -> Coder -> QA -> DevOps` 的文件驱动状态机闭环与 3 次失败熔断机制。