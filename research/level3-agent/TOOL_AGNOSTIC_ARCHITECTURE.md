# 工具无关（Tool-Agnostic）单兵自治架构设计与规范

> **设计目标**：建立一套类似 Kubernetes CRI（容器运行时接口）的 **Agent 驱动规范（Agent Driver SPI）**。使系统能够将任何具体的终端编码工具（Aider、omp、Claude Code、原生 Python ReAct 脚本）作为**可热插拔的无状态执行引擎**，在完全不修改外层调度、沙盒隔离、反作弊门禁与审计系统的前提下，实现底层 Agent 的秒级替换。

---

## 一、 核心设计哲学：控制反转（Inversion of Control）

传统错误做法是将安全逻辑、分支逻辑、测试自愈逻辑寄生在具体工具内部；
**工具无关架构的核心原则是：将一切“确定性工程约束”彻底剥离并外置。**

```mermaid
flowchart TD
    subgraph 外层确定性基础设施 (100% 工具无关)
        TaskSpec["1. 结构化任务契约 (tasks/<id>/spec.md)"]
        Worktree["2. Git Worktree 独立沙盒 + 只读测试权限 (chmod 555 tests/)"]
        Supervisor["3. 状态机中枢与断路器 (scripts/supervisor.py)"]
        AuditGate["4. 双阶段反作弊代码审查 (scripts/audit-diffs.sh)"]
        Gateway["5. 统一网关预算控制与全量审计 (LiteLLM Proxy)"]
    end

    subgraph 抽象驱动层 (Agent Driver SPI)
        SPI["BaseAgentDriver (统一抽象接口)"]
        SPI -->|"run()"| D1["AiderDriver"]
        SPI -->|"run()"| D2["OmpDriver (Oh My Pi)"]
        SPI -->|"run()"| D3["ClaudeCodeDriver"]
        SPI -->|"run()"| D4["NativeReActDriver (轻量原生实现)"]
    end

    TaskSpec --> Worktree
    Worktree --> Supervisor
    Supervisor --> SPI
    D1 -.->|生成统一 Git Patch| AuditGate
    D2 -.->|生成统一 Git Patch| AuditGate
    D3 -.->|生成统一 Git Patch| AuditGate
    D4 -.->|生成统一 Git Patch| AuditGate
    AuditGate --> Gateway
```

* **底层 Agent 只是一个“纯函数式修补者（Patch Function）”**：
  $$\text{Input: (Workspace, Spec, TestCmd)} \quad\xrightarrow{\quad\text{Agent Driver}\quad}\quad \text{Output: (ExitCode, GitDiff, TokenSpend)}$$
* 无论是 Aider 还是 omp，都只是这个纯函数的底层执行者。

---

## 二、 四大标准化协议（The 4 Invariant Protocols）

要做到工具无关，必须在四个关键接缝处确立严格的接口协议：

### 1. 输入契约协议（Task Specification Protocol）
无论派发给哪款工具，输入必须收敛为磁盘上的标准化 Markdown 契约文件（如本项目的 `tasks/<id>/spec.md`），严禁使用特定工具特有的专用提示词格式：
* **目标描述**：清晰的行为期望与需求背景；
* **验收命令**：确定性的测试指令（如 `pytest tests/test_feature.py`）；
* **负向边界清单（Negative Invariants）**：明确规定严禁修改的生产配置、数据库结构和测试文件。

### 2. 沙盒与权限协议（Sandbox & Permissions Protocol）
工具不能随意访问开发者的整个硬盘，必须在一个被严格受控的环境中执行：
* **Git Worktree 目录沙盒**：所有工具必须在由调度脚本创建的隔离工作树（`../worktrees/<task-id>`）下启动；
* **测试目录物理只读锁定**：在调用任何 Agent 执行前，外层环境调度器自动执行：
  ```bash
  # 强制 tests/ 目录对当前工作区只读，物理封死作弊修改单测
  chmod -R 555 ./tests
  ```
  任务执行完毕或进入审查阶段后，再恢复权限。

### 3. 驱动抽象接口协议（Agent Driver SPI）
所有接入体系的单兵工具，必须实现统一的驱动接口（标准输入输出与退出语义）：
* **配置输入**：工作区路径、契约文件路径、验收命令、超时秒数、最大重试次数；
* **标准调用**：无头（Headless）非交互模式启动；
* **产物归一化输出（Normalized Result Artifact）**：
  - `status`: `SUCCESS` | `FAILED` | `TIMEOUT` | `CIRCUIT_BROKEN`；
  - `diff`: 业务代码的 Git Diff 文本；
  - `stderr`: 提纯后的错误日志片段（过滤后不超过 2000 字符）；
  - `tokens_spent`: 本次运行消耗的 Token 与花费估算。

### 4. 产物与双阶段审查协议（Verification & Slicing Protocol）
任何工具生成的最终产物，必须无条件接受外部统一门禁的盲审：
* 触发 [`scripts/audit-diffs.sh`](file:///Users/fx/wk/github/10x/scripts/audit-diffs.sh)；
* 验证 `tests.diff` 是否存在非法篡改；
* 在脱离 Agent 运行时的干净独立测试环境中重跑全量单元测试。

---

## 三、 工具无关驱动架构的代码化标准

通过 Python 抽象基类统一接入标准（参见配套实现的 [`agent_driver_template.py`](./agent_driver_template.py)）：

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional, Dict, Any

@dataclass
class AgentResult:
    task_id: str
    status: str                 # "SUCCESS" | "FAILED" | "TIMEOUT"
    exit_code: int
    git_diff: str               # 变更的代码 Patch
    stderr_summary: str         # 提纯过滤后的错误日志
    token_usage: Dict[str, Any] # {"prompt_tokens": int, "completion_tokens": int, "cost_usd": float}

class BaseAgentDriver(ABC):
    """工具无关的单兵 Agent 统一驱动基类"""

    def __init__(self, workspace_path: str, model_gateway_url: str):
        self.workspace_path = workspace_path
        self.gateway_url = model_gateway_url

    @abstractmethod
    def run_headless_task(
        self,
        task_id: str,
        spec_content: str,
        test_cmd: str,
        timeout_seconds: int = 300
    ) -> AgentResult:
        """无头执行单兵闭环任务，返回归一化结果"""
        pass

    @abstractmethod
    def health_check(self) -> bool:
        """检查底层工具 CLI 是否已正确安装与配置"""
        pass
```

### 多引擎实现差异对比

| 驱动实现 | 底层调用方式 | 无头（Headless）运行配置方案 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **`AiderDriver`** | `aider --no-git --yes --message "..." --test-cmd "..."` | 原生支持 `--yes` 自动确认，通过参数完全压制交互提示 | 个人与无头流水线基准方案（成熟、极低侵入） |
| **`OmpDriver`** | `omp --headless --non-interactive --prompt-file "..."` | 屏蔽终端富文本颜色与 LSP/DAP 交互，仅输出补丁 | 偏好其内置特定语言补丁算法的高级场景 |
| **`ClaudeCodeDriver`** | `claude -p "..." --dangerously-skip-permissions` | 非交互运行，限制在 Worktree 目录沙盒内 | 复杂跨文件深度推理场景 |
| **`NativeReActDriver`** | 纯 Python 100 行自实现 ReAct 循环脚本 | 直接调用 LiteLLM 接口，读写文件与执行终端命令 | 极简微容器沙盒、零外部重型依赖场景 |

---

## 四、 工具无关架构带来的终极价值

1. **彻底免疫工具淘汰周期（Future-Proof）**：
   - 团队无论今天用 Aider、明天用 omp、后天用最新开源的革命性 Agent，整个顶层的任务卡规范、Git Worktree 并行架构、反作弊 CI 门禁、Supervisor 状态机**不需要改动一行代码**；
2. **基准横向评测（A/B Testing & Benchmarking）**：
   - 可以针对同一个需求任务卡（`tasks/101-demo.md`），通过切换驱动配置分别运行 Aider 和 omp，客观对比两者的执行时间、Token 消耗账单以及单测一次通过率，选出最佳性价比引擎；
3. **安全与权限收敛的统一硬保证**：
   - 安全规则由外部沙盒（Read-only 权限与 Docker）和统一网关（LiteLLM 审计）兜底，即便底层某个开源 Agent 存在代码注入漏洞或作弊幻觉，也无法突破外层防线。
