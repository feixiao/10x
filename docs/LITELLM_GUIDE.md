# LiteLLM 统一模型网关实战指南 (LiteLLM Guide)

> **定位**：LiteLLM 是 10x 体系中的**统一模型调度与安全控制枢纽**。它将异构模型（云端商业 API、企业内网 vLLM 集群、本地 LMStudio/Ollama、Magpie 本地代理）统一封装为标准协议（兼容 OpenAI `/v1/chat/completions` 与 Anthropic `/v1/messages`），向上为 Aider、OpenHands、Claude Code、OpenCode、omp、Cursor 及自动化脚本提供一致接口，向下实现**混合算力路由、容灾降级、虚拟 Key 预算熔断、Skill 上下文治理与全链路审计**。

---

## 一、 为什么在 AI 工程中引入 LiteLLM？

在多 Agent、多 Skill 与 AI-Native 研发体系中，直接在各个客户端或脚本中直连外部模型提供商（如 Anthropic、OpenAI、DeepSeek 等）会导致以下架构缺陷：

| 痛点场景 | 裸直连 API 的问题 | LiteLLM 统一网关解决方案 |
| :--- | :--- | :--- |
| **客户端协议分裂** | Claude Code 要求 Anthropic Messages API，Aider/OpenCode 要求 OpenAI 协议，字段不兼容。 | **双向协议归一化**：同时支持 OpenAI 与 Anthropic 端点，`drop_params: true` 自动清洗不兼容参数。 |
| **多 Agent 算力成本失控** | 样板代码、单测生成、循环重试全跑昂贵云端旗舰，产生巨额 API 账单。 | **8:2 混合路由**：高难推理走云端（约 20%），代码重构与跑测自愈走本地 0 边际成本算力（约 80%）。 |
| **单点中断与限频** | 遇到厂商 429 (Rate Limit) 或网络 5xx 故障时，正在运行的长会话 Agent 直接崩溃。 | **自动健康检查与故障转移 (Fallbacks)**：毫秒级故障感知并切换至备用模型池。 |
| **企业安全与泄密** | 开发者本地或容器内分散配置裸 API Key，极易误提交或被 Agent 窃取。 | **多租户虚拟 Key (Virtual Keys)**：真实 Key 不出机房，支持团队/任务级额度熔断与秒级撤销。 |
| **Skill 膨胀与黑盒调用** | 挂载多个专业 Skill 后上下文剧增，无法追溯哪位 Agent、哪项 Skill 消耗了多少 Token。 | **全链路 PostgreSQL 审计日志**：持久化 Prompt、Completion、Tool Call、Token、耗时与用户凭据。 |

---

## 二、 核心架构拓扑

```mermaid
graph TD
    subgraph 客户端与 Agent 矩阵 (Clients & Agents)
        Aider[Aider CLI / --architect]
        ClaudeCode[Claude Code CLI / claude]
        OpenCode[OpenCode CLI / TUI]
        OmpAgent[omp 编码助手]
        OpenHands[OpenHands 容器沙盒]
        Cursor[Cursor / VSCode / IDE]
        Supervisor[主控状态机 scripts/supervisor.py]
    end

    Aider & OpenCode & OmpAgent & OpenHands & Cursor & Supervisor -->|OpenAI 协议 :4000/v1| LiteLLMProxy[LiteLLM Proxy 网关服务]
    ClaudeCode -->|Anthropic 协议 :4000/v1/messages| LiteLLMProxy

    subgraph LiteLLM 核心处理管道 (Gateway Pipeline)
        LiteLLMProxy --> Protocol[双向协议转换 & 参数清洗<br>OpenAI / Anthropic / drop_params: true]
        Protocol --> Auth[虚拟 Key 鉴权 & 预算限额<br>max_budget / TPM / RPM 拦截]
        Auth --> SkillGuard[Skill 上下文治理 & PII 脱敏<br>Prompt 截断保护 / 敏感数据过滤]
        SkillGuard --> Router[智能路由 & 负载均衡<br>latency / usage / fallback]
        Router --> AuditHook[异步审计 Hook<br>success/failure_callback]
    end

    subgraph 存储与合规层 (Persistence)
        AuditHook --> Postgres[(PostgreSQL 审计库<br>LiteLLM_SpendLogs / Users)]
        AuditHook -.-> Webhook[Slack / 企业微信 告警]
    end

    subgraph 下游异构算力提供商 (Downstream Providers)
        Router -->|架构拆解 / 顶层重推理 (20% 流量)| Magpie[本地 Magpie 网关 :3425<br>Claude Sonnet / GPT-6 / Gemini]
        Router -->|代码编写 / 单测自愈 (80% 流量)| LMStudio[本地 LMStudio :1234<br>Qwen 2.5 / Gemma 4]
        Router -->|企业私有算力| vLLM[企业内网 GPU 集群 :8000<br>vLLM / Ollama]
        Router -->|商业云端 API| PublicCloud[Anthropic / DeepSeek / OpenAI]
    end
```

---

## 三、 核心能力机制详解

### 1. 协议归一化与双向自适应 (`drop_params: true`)
不同的客户端与底层模型对于 API 规范的定义差异巨大：
- **OpenAI 兼容客户端**（如 Aider、Cursor、OpenCode、omp）使用 `/v1/chat/completions`。
- **Anthropic 专用客户端**（如 Claude Code CLI）默认调用 `/v1/messages` 接口。
- **参数冲突问题**：若向 Anthropic 模型传入 OpenAI 的 `frequency_penalty`，或向推理模型（DeepSeek-R1 / o1）传入自定义 `temperature`，上游提供商会直接抛出 `400 Bad Request`。

**LiteLLM 的自适应解法**：
1. **双协议暴露**：LiteLLM Proxy 同时暴露 `/v1/chat/completions` 和 `/v1/messages`，并在内部透明转换请求体。
2. **自动参数过滤**：
   ```yaml
   litellm_settings:
     drop_params: true  # 自动检测下游提供商不支持的参数并静默剔除，防止客户端报错
     set_verbose: false # 生产环境关闭冗余调试信息
   ```

### 2. 逻辑模型命名与解耦 (Model Aliasing)
在应用层（如 Aider、Supervisor 或 OpenCode）中，硬编码具体的厂商模型名称（如 `anthropic/claude-3-7-sonnet-20250219`）会造成强耦合。通过 LiteLLM 建立**逻辑角色别名**：
```yaml
model_list:
  - model_name: architect-model       # 逻辑模型名（客户端调用该名称）
    litellm_params:
      model: openai/antigravity/claude-sonnet-5-5  # 后端真实模型与协议
      api_base: http://127.0.0.1:3425/v1
  - model_name: coder-model           # 逻辑编码模型
    litellm_params:
      model: openai/qwen3.8-27b-splash
      api_base: http://localhost:1234/v1
```
当需要更换底层提供商（例如从 Claude 切换到 DeepSeek 或自建 vLLM）时，**仅需修改网关 YAML，所有调用端完全无感**。

### 3. 路由策略与故障转移 (Routing & Fallbacks)
LiteLLM 支持多种路由算法与重试熔断机制：
* **延迟路由 (`latency-based-routing`)**：对配置的多个实例进行周期性测速，优先将请求路由到 P95 响应最快的节点。
* **用量均衡 (`usage-based-routing`)**：根据当前并发数与已消耗 Token 分流，防止单个实例被打满限流。
* **故障降级与冷却**：
  ```yaml
  router_settings:
    routing_strategy: latency-based-routing
    num_retries: 2      # 单节点失败重试次数
    timeout: 60         # 接口单次调用超时时长 (秒)
    allowed_fails: 3    # 连续失败 3 次触发熔断冷却
    cooldown_time: 30   # 冷却 30 秒后重新放入候选池
    fallbacks:
      - architect-model: ["architect-model-backup", "architect-model-fast"]
  ```

### 4. 虚拟密钥与预算管控 (Virtual Keys & Budgets)
企业版支持动态生成不暴露真实 Provider Key 的虚拟密钥，并配置严格的限额：
* **预算硬上限 (`max_budget`)**：设置周期内最大消费额度（如 `$50`），达到后自动返回 429 阻断请求。
* **重置周期 (`budget_duration`)**：如 `"30d"`、`"7d"`、`"24h"`。
* **并发与速率限流 (`tpm` / `rpm`)**：限制单个 Key 每分钟的请求次数 (RPM) 或 Token 吞吐量 (TPM)。

### 5. 全链路数据审计入库 (PostgreSQL Logging)
通过开启内置的数据库回调：
```yaml
litellm_settings:
  success_callback: ["postgres"]
  failure_callback: ["postgres"]
```
LiteLLM 会将每次调用的以下关键字段写入 `LiteLLM_SpendLogs` 表：
- `request_id`, `api_key` (虚拟 Key 的哈希索引)
- `model`, `custom_llm_provider`
- `prompt` 与 `completion` 完整上下文（包含 Tool Call 载荷）
- `prompt_tokens`, `completion_tokens`, `total_tokens`, `spend` (美元费用)
- `response_time_ms` 与时间戳

### 6. 常驻后台守护服务管理器 (`scripts/litellm-service.sh`)
为避免每次开发都需要手动在前台维持 `litellm` 终端进程，本工程内置了常驻后台守护服务管理器 [`scripts/litellm-service.sh`](../scripts/litellm-service.sh)：
- 支持后台 Daemon 化（PID 与日志收敛至 `.litellm/` 目录）；
- 支持系统自启安装（macOS `LaunchAgent` / Linux `systemd`）；
- 内置端点探活与健康检查。

```bash
# 启动本地后台常驻网关
./scripts/litellm-service.sh start

# 查看运行状态与 PID
./scripts/litellm-service.sh status

# 实时流式查看网关日志
./scripts/litellm-service.sh logs

# 开机自启动注册 (macOS LaunchAgent / Linux systemd)
./scripts/litellm-service.sh install-daemon
```

### 7. 容器与宿主机跨网络穿透 (`host.docker.internal:host-gateway`)
当 Agent 运行在 Docker 隔离沙盒中（如 OpenHands 或 DevContainer），容器内直接请求 `localhost:4000` 会被路由到容器自身环回网卡，导致 `Connection Refused`。

**穿透方案**：
1. **Linux / macOS 通用参数**：在拉起容器时声明 `--add-host host.docker.internal:host-gateway`；
2. **在 Docker Compose 中配置**：
   ```yaml
   extra_hosts:
     - "host.docker.internal:host-gateway"
   ```
3. **Agent 容器环境变量**：将 API Base 指定为 `http://host.docker.internal:4000/v1`，即可稳定穿透至宿主机或局域网的 LiteLLM。

### 8. 工具调用 (Function Calling / Tool Calling) 协议自适应
当 Agent 或 Skill 需要调用外部工具（如 MCP 服务 `biz_inspector` 或 `infra_devops`）时，不同模型（Anthropic Claude 的 `tools` 规范、OpenAI 的 `tool_choice`、本地 Qwen 的 JSON 工具格式）协议迥异。
LiteLLM 充当了**工具协议垫片**，接收标准的 OpenAI `tools` 参数，自动转换为后端提供商所兼容的格式，并在返回时将 Tool Call 结构反向还原。

---

## 四、 10x 预置模式实战

本工程采用**单一核心配置文件与双运行时形态**：
* **核心配置文件**：[`configs/litellm.yaml`](../configs/litellm.yaml)（已实测校验本机 Magpie 与 LMStudio 算力端点）。
* **核心目标**：实现 **8:2 算力智能分流**（20% 架构拆解走免 Key Magpie 旗舰模型，80% 样板代码生成与跑测自愈走 LMStudio 本地 0 边际成本算力），并内建完整的超时保护与 Fallbacks 容灾链路。

### 运行形态 A：本地守护直通运行 (Solo Daemon)
适合开发者本机日常极速开发，零中间件开销：
```bash
# 方式 1: 通过脚本后台常驻守护运行 (推荐)
./scripts/litellm-service.sh start

# 方式 2: 前台 CLI 运行
litellm --config configs/litellm.yaml --port 4000
```

### 运行形态 B：容器化全量审计持久化 (Enterprise Docker Compose / ~/litellm-gateway)
适合团队生产协作或对本地调用需要进行合规与 Token 计费审计的场景：
```bash
# 启动容器网关与独立 PostgreSQL 16 审计数据库
docker compose -f configs/docker-compose.yml up -d

# 或使用本机已同步配置的官方 LiteLLM Gateway
cd ~/litellm-gateway && docker compose -f docker-compose.quickstart.yml up -d
```

#### Web 管理后台 (LiteLLM Admin UI)
容器服务启动后，通过浏览器访问：
* **URL**：`http://localhost:4000/ui`
* **登录凭证**：配置中设定的 `LITELLM_MASTER_KEY` (见 `~/litellm-gateway/.env`)

在后台界面中，管理员可以：
- **生成团队/个人 Virtual Key**：限制指定模型访问权限、月度预算（如 `$200/月`）与过期时间。
- **实时费用大盘**：按模型、用户、时间维度查看 Token 吞吐与费用趋势。
- **全量调用日志追溯**：检索历史 Prompt 输入与输出，排查安全合规问题。

#### 统一配置结构剖析 (`configs/litellm.yaml`)
```yaml
model_list:
  # 1. 架构师主模型 (Magpie Claude Opus 5.5，实测 1.0s)
  # 容器访问宿主机外部服务必须使用 host.docker.internal
  - model_name: architect-model
    litellm_params:
      model: openai/antigravity/claude-opus-5-5
      api_base: http://host.docker.internal:3425/v1
      api_key: dummy
      max_tokens: 8192
      timeout: 120

  # 备选架构师模型 1 (Magpie Claude Opus 4.6 Thinking，实测 1.9s)
  - model_name: architect-model-backup
    litellm_params:
      model: openai/antigravity/claude-opus-4-6-thinking
      api_base: http://host.docker.internal:3425/v1
      api_key: dummy
      max_tokens: 8192
      timeout: 120

  # 备选架构师模型 2 (GPT-6 Luna，实测 4.5s)
  - model_name: architect-model-fast
    litellm_params:
      model: openai/codex/gpt-6-luna
      api_base: http://host.docker.internal:3425/v1
      api_key: dummy
      max_tokens: 8192
      timeout: 120

  # 2. 本地高频编码模型 (LMStudio Qwen3.8-27B，设定充裕的 300s 超时防断连)
  - model_name: coder-model
    litellm_params:
      model: openai/qwen3.8-27b-splash
      api_base: http://host.docker.internal:1234/v1
      api_key: dummy
      max_tokens: 8192
      timeout: 300

  # 3. 极速响应模型 (Magpie Gemini 3.8 Flash，秒级返回，供样板代码、日志清洗与快速审查)
  - model_name: fast-model
    litellm_params:
      model: openai/antigravity/gemini-3.8-flash
      api_base: http://host.docker.internal:3425/v1
      api_key: dummy
      max_tokens: 8192
      timeout: 60
router_settings:
  routing_strategy: latency-based-routing
  num_retries: 2
  allowed_fails: 2
  cooldown_time: 30
  fallbacks:
    - architect-model: ["architect-model-backup", "architect-model-fast"]
    - coder-model: ["coder-model-backup"]

litellm_settings:
  drop_params: true
  set_verbose: false
```
服务启动后，通过浏览器访问：
* **URL**：`http://localhost:4000/ui`
* **登录凭证**：配置中设定的 `LITELLM_MASTER_KEY`

在后台界面中，管理员可以：
- **生成团队/个人 Virtual Key**：限制指定模型访问权限、月度预算（如 `$200/月`）与过期时间。
- **实时费用大盘**：按模型、用户、时间维度查看 Token 吞吐与费用趋势。
- **调用日志追溯**：检索历史 Prompt 输入与输出，排查安全合规问题。

---

## 五、 Agent 客户端接入方案 (Agent 怎么使用 Gateway)

核心准则：**Agent 客户端严禁直接持有云端服务商裸 Key 或零散端点，必须统一指向 LiteLLM 网关暴露的 `:4000` 端口，并使用逻辑别名（`architect-model` / `coder-model`）实现解耦。**

> 📌 **选型边界说明**：
> - **10x 官方核心主线**：**个人版 (Solo) 仅需使用 Aider**（无需额外部署 OpenCode 等工具），**企业版 (Enterprise) 使用 OpenHands**，**终态状态机使用 Supervisor**。
> - **第三方兼容参考**：若团队成员已有既定习惯使用 Claude Code、OpenCode、omp 或 Cursor，LiteLLM 同样提供标准协议兼容（见 5.2 节，按需选配即可）。

---

### 5.1 10x 官方核心引擎接入（必配主线）

#### 1. Aider 接入 (Solo 个人版唯一官方驱动：双模型架构师 + TDD 自愈)
在项目根目录创建或直接使用已预置的 [`configs/.aider.conf.yml`](../configs/.aider.conf.yml)：
```yaml
openai-api-base: http://localhost:4000/v1
openai-api-key: sk-1d307c0eb1dc6106851fe89bd3aff3534757d4aa0d9fcc954b89461fe8e507a5   # 填入网关 Master Key 或分发的虚拟 Key
```

# 8:2 架构师分流模式
model: openai/coder-model               # 默认代码实现走本地模型
architect-model: openai/architect-model # 顶层架构思考走云端重推理
editor-model: openai/coder-model        # 编辑器操作走本地模型
architect: true
```

或者通过环境变量与命令行快捷拉起：
```bash
export OPENAI_API_BASE="http://localhost:4000/v1"
export OPENAI_API_KEY="sk-enterprise-virtual-key"

aider --model openai/coder-model --architect --editor-model openai/coder-model
```

#### 2. OpenHands 容器沙盒 Agent 接入 (Enterprise 企业版主力驱动)
在企业或自动化评测场景中，OpenHands 在 Docker 沙盒容器中执行自主编码任务。
使用本仓库提供的 [`deploy_openhands.sh`](../deploy_openhands.sh) 部署时，脚本已内置 `--add-host host.docker.internal:host-gateway`：

```bash
# 指定通过宿主机网关接入
export LLM_BASE_URL="http://host.docker.internal:4000/v1"
export LLM_API_KEY="sk-enterprise-virtual-key"
export LLM_MODEL="openai/architect-model"

./deploy_openhands.sh start
```
**加固防御机制**：为 OpenHands 容器单独生成虚拟 Key 并配置 `max_budget: 30`（美元）。一旦自主 Agent 发生执行死循环，消费达到上限时网关自动熔断阻断。

#### 3. Supervisor 主控状态机调度器接入 (全生命周期编排中枢)
在工程终态架构 [`scripts/supervisor.py`](../scripts/supervisor.py) 中，由状态机协调四大专职 Agent 并通过 LiteLLM 实施分级调度：

| 专职 Agent 角色 | 任务阶段 | 网关逻辑模型 | 选型考量 |
| :--- | :--- | :--- | :--- |
| **Planner (架构师)** | `PLANNING` | `architect-model` | 需要极高重推理能力拆解系统设计、边界与 `tasks.md`。 |
| **Coder (研发工程师)** | `CODING` | `coder-model` | 极高调用频次、结合单测不断重试自愈，需要零边际成本与高吞吐。 |
| **QA (质量审计员)** | `TESTING` / `AUDITING` | 本地执行脚本 + `coder-model` | 批量运行静态检查与反作弊切片生成。 |
| **DevOps (运维工程师)** | `DEV_OPS_VERIFY` | `coder-model` + MCP 工具 | 查询只读日志与服务状态自检。 |

---

### 5.2 第三方生态兼容参考（按需选配，Solo 标准工作流无需配置）

> 以下配置仅供团队内习惯使用其他终端/IDE 工具的开发者对接统一网关参考，**标准 Solo 工作流使用 Aider 即可覆盖全部需求**。

#### 4. Claude Code 接入 (`claude` CLI)
Claude Code 原生使用 Anthropic Messages API (`/v1/messages`)。由于 LiteLLM Proxy 原生实现了 Anthropic 协议层，可直接重定向：
```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-enterprise-master-secret-key"
claude
```
或写入 `~/.claude.json`：
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_API_KEY": "sk-enterprise-master-secret-key"
  }
}
```

#### 5. OpenCode 接入 (`opencode` CLI / TUI)
```bash
export OPENAI_BASE_URL="http://localhost:4000/v1"
export OPENAI_API_KEY="sk-dummy-key"
export OPENCODE_MODEL="coder-model"
opencode
```
或配置 `~/.config/opencode/config.json`：
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": "openai",
  "baseURL": "http://localhost:4000/v1",
  "apiKey": "sk-dummy-key",
  "model": "coder-model",
  "architectModel": "architect-model"
}
```

#### 6. omp 接入 (Oh My Prompt CLI)
```bash
omp config set providers.litellm.baseUrl "http://localhost:4000/v1"
omp config set providers.litellm.apiKey "sk-dummy-key"
omp config set defaultModel "coder-model"
```
或配置 `~/.omp/config.json`：
```json
{
  "models": {
    "default": "coder-model",
    "architect": "architect-model"
  },
  "providers": {
    "litellm-gateway": {
      "type": "openai",
      "baseUrl": "http://localhost:4000/v1",
      "apiKey": "sk-dummy-key"
    }
  }
}
```

#### 7. Cursor / IDE 插件接入
在 Cursor 设置面板 (`Settings -> Models -> OpenAI API Key`) 中：
* **Override OpenAI Base URL**：`http://localhost:4000/v1`
* **API Key**：`sk-enterprise-virtual-key`（Solo 版填 `dummy`）
* **Model Name**：输入 `coder-model` 或 `architect-model`。

#### 8. Python SDK 与通用 Agent 框架接入
兼容所有基于标准 OpenAI SDK 构建的自主框架（如 LangChain、CrewAI、AutoGen）：
```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key=os.environ.get("LITELLM_API_KEY", "sk-dummy-key")
)

# 纯流式调用（自动透传 usage 审计块）
response = client.chat.completions.create(
    model="coder-model",
    messages=[
        {"role": "system", "content": "你是一位资深 Python 架构师。"},
        {"role": "user", "content": "请写一个带超时控制的异步重试装饰器。"}
    ],
    temperature=0.2,
    stream=True,
    stream_options={"include_usage": True}
)

for chunk in response:
    if chunk.choices and chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
print()
```

---

## 六、 Skill 体系与 Gateway 协同实战 (Skill 怎么使用)

### 1. Skill 在 10x 体系中的定义与分类
在现代 Agent 架构中，**Skill（技能）** 是赋予 Agent 领域专业能力的可复用资产包。它不是一段孤立的 Prompt，而是集**规范约束、操作 SOP、检查清单与工具定义**于一体的结构化工程单元。

在 10x 中主要包含三类 Skill：
1. **规范与提示词类 Skill (Prompt Skills)**：如 TDD 红绿循环技能、静态代码合规技能；
2. **契约与流程类 Skill (Contract Skills)**：如 [`tasks/template.md`](../tasks/template.md) 任务契约卡、[`scripts/audit-diffs.sh`](../scripts/audit-diffs.sh) 双阶段反作弊审查；
3. **可执行工具类 Skill (Tool & MCP Skills)**：结合 Model Context Protocol 的只读业务巡检 [`mcp_servers/biz_inspector.py`](../mcp_servers/biz_inspector.py) 与运维控制 [`mcp_servers/infra_devops.py`](../mcp_servers/infra_devops.py)。

---

### 2. OpenHands 容器沙盒中的 Skill 挂载与规范

在 [`deploy_openhands.sh`](../deploy_openhands.sh) 部署机制中，系统自动将宿主机 `${VOLUME_BASE}/skills` 目录以只读方式挂载至容器内部 `/home/openhands/.agents/skills:ro`。

#### (1) 目录结构
```
$VOLUME_BASE/skills/
├── tdd-workflow/
│   └── SKILL.md
├── code-review/
│   └── SKILL.md
└── db-inspection/
    └── SKILL.md
```

#### (2) 标准 `SKILL.md` 编写范式
每个 Skill 目录内必须包含 `SKILL.md`，推荐使用包含 Frontmatter 元数据的标准格式：

```markdown
---
name: tdd-healing-workflow
description: 强制执行测试优先(TDD)与测试失败自愈循环技能
trigger: "实现新功能|修复Bug|编写测试"
allowed_tools:
  - bash
  - file_editor
---

# TDD 驱动与自愈技能规范 (TDD Skill)

## 核心原则
1. **测试先行**：在修改任何业务逻辑前，必须先编写针对该需求的断言测试用例，并运行该测试确认其预期失败（Red 阶段）。
2. **最小实现**：仅编写让测试通过的最少业务代码（Green 阶段）。
3. **禁止削弱断言**：严禁在自愈过程中修改、注释已有测试或将其改为恒真断言。

## 执行 SOP
1. 读取任务契约文件 `tasks/<task-id>/spec.md` 获取验收命令；
2. 执行验证命令捕获异常栈；
3. 根据报错信息进行定向修复；
4. 运行 `audit-diffs.sh` 生成自审报告。
```

#### (3) Agent 运行时触发机制
OpenHands 的 Agent Server 在接收到人类任务后，会自动扫描 `/home/openhands/.agents/skills` 目录下的元数据：
- 当用户 Prompt 匹配 `trigger` 规则时，Agent 自动将该 Skill 规范载入 System Prompt 或工作记忆中；
- 随后，**Agent 携带 Skill 上下文向 LiteLLM 网关发起模型调用**。

---

### 3. 本地与 CLI Agent 的 Skill 机制 (Aider / Claude Code / OpenCode / omp)

在无容器沙盒的日常开发环境中，Skill 表现为确定性的规则卡与约束文件：
- **Aider**：将架构规范放入 `.aider.conf.yml`，并将 `tasks/<task-id>/spec.md` 作为契约卡直接加载（`aider --read tasks/101-auth/spec.md`），使 Aider 具备严格的领域边界感知。
- **Claude Code**：在项目根目录使用 `.claude/` 扩展或通过注入提示词载入领域规范。
- **omp**：通过内建的 Skill 指令集与角色模板，将工程知识模块化调用。

---

### 4. Tool-based Skill 经过 Gateway 的协议归一化

当 Skill 包含外部工具调用（如查询只读数据库或检查容器状态）时，架构流转如下：

```
[Agent 运行时] --(加载 Skill 提示词 + MCP 工具元数据)--> [向 LiteLLM 发起调用]
                                                                │
                                                                ▼
                                                    [LiteLLM Proxy 网关]
                                                                │
                 ┌──────────────────────────────────────────────┴──────────────────────────────┐
                 ▼                                                                             ▼
    [下游 A: 云端 Claude 3.7]                                                      [下游 B: 本地 Qwen2.5]
    (转换标准 tools 为 Anthropic JSON)                                            (转换标准 tools 为 OpenAI Tool Calls)
```

LiteLLM 网关在此过程中起到两大关键保障：
1. **格式自动抹平**：无论底层模型是 Claude 还是开源小模型，上层的 Skill 工具声明只需遵循一次标准 OpenAI `tools` 规范。
2. **参数清洗**：`drop_params: true` 保证当切换到底层不支持复杂采样参数的提供商时，带有 Tool Calling 的请求依然能顺利执行。

---

### 5. Skill 与 Gateway 的四大核心联动治理机制

在多 Skill 并存的大型 Agent 系统中，若缺乏网关治理，会导致严重的工程事故。LiteLLM 提供了四重管控：

#### ① 上下文预算与 Token 膨胀控制
- **痛点**：若无节制挂载大量 Skill，Prompt 长度将轻松突破几万 Token，导致严重“注意力稀释 (Attention Dilution)”并大幅增加费用。
- **网关策略**：
  在网关配置中针对逻辑模型设立硬上限：
  ```yaml
  litellm_params:
    max_tokens: 8192
    max_input_tokens: 32000 # 超过该阈值时网关优雅抛出预警，倒逼 Agent 仅挂载必要 Skill
  ```

#### ② 依据 Skill 难度等级进行动态模型分流 (8:2 分流)
不是所有 Skill 都需要顶尖云端模型：
- **重逻辑 Skill**（如 `system-architecture-design`、`vulnerability-audit`）：由 Supervisor 调度路由至 `architect-model`（云端重推理算力）。
- **执行型 Skill**（如 `unit-test-auto-healing`、`code-formatting`、`linter-cleanup`）：由 Supervisor 调度路由至 `coder-model`（本地 0 边际成本算力）。

#### ③ 全量审计入库与 Skill ROI 价值量化
每次携带 Skill 调用的记录均沉淀至 PostgreSQL。通过在请求头中附带元数据标签（`metadata: {"skill": "tdd-healing"}`），可以在网关数据库中按 Skill 聚合分析：
```sql
-- 查询特定 Skill 在过去 7 天内消耗的 Token 与总费用
SELECT 
    metadata->>'skill' AS skill_name,
    COUNT(*) AS total_calls,
    SUM(total_tokens) AS total_tokens_used,
    SUM(spend) AS total_spend_usd,
    AVG(response_time_ms) AS avg_latency_ms
FROM "LiteLLM_SpendLogs"
WHERE metadata->>'skill' IS NOT NULL
GROUP BY metadata->>'skill'
ORDER BY total_spend_usd DESC;
```

#### ④ 敏感词过滤与知识防泄漏 (PII Masking)
当私有业务 Skill 中包含公司内部数据表结构、API 密钥命名习惯或敏感域名时，LiteLLM 的 PII 过滤中间件可在请求出网前进行正则表达式脱敏，确保企业核心资产不出机房。

---

### 6. 端到端实操代码示例：Agent 加载 Skill 经网关执行 Tool Call

以下 Python 脚本完整演示了：**Agent 加载磁盘上的 `SKILL.md`，组合 MCP 工具声明，经由本地 LiteLLM 网关调用 `coder-model`，并触发安全工具调用**：

```python
#!/usr/bin/env python3
import json
import os
from pathlib import Path
from openai import OpenAI

# 1. 初始化标准 OpenAI 客户端，完全指向 LiteLLM 网关 (:4000)
client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key=os.environ.get("LITELLM_API_KEY", "sk-dummy-key")
)

# 2. 读取磁盘上的专业 Skill 资产文件
skill_file = Path("skills/tdd-workflow/SKILL.md")
skill_content = skill_file.read_text(encoding="utf-8") if skill_file.exists() else "执行严格的测试先行规范。"

# 3. 声明工具定义 (与本仓库 biz_inspector / infra_devops 对应)
tools = [
    {
        "type": "function",
        "function": {
            "name": "query_readonly_db",
            "description": "安全执行只读业务 SQL 查询（仅支持 SELECT/EXPLAIN）",
            "parameters": {
                "type": "object",
                "properties": {
                    "sql_query": {"type": "string", "description": "要执行的只读 SQL 语句"}
                },
                "required": ["sql_query"]
            }
        }
    }
]

# 4. 组装携带 Skill 的上下文请求
messages = [
    {"role": "system", "content": f"你是一个专业研发 Agent，必须严格遵循以下技能规范：\n\n{skill_content}"},
    {"role": "user", "content": "请检查当前用户表结构，并为用户登录接口编写一个失败的基准测试用例。"}
]

print("--> [Agent] 正在携带 Skill 规范经由 LiteLLM 网关发起调用...")

response = client.chat.completions.create(
    model="coder-model",  # 经网关智能路由到本地 LMStudio 或云端
    messages=messages,
    tools=tools,
    tool_choice="auto",
    temperature=0.1
)

message = response.choices[0].message

# 5. 处理网关统一标准化返回的 Tool Call
if message.tool_calls:
    print(f"--> [Gateway 返回] 检测到工具调用请求: {len(message.tool_calls)} 个")
    for call in message.tool_calls:
        print(f"    - 函数名: {call.function.name}")
        print(f"    - 参数内容: {call.function.arguments}")
else:
    print("--> [Gateway 返回] 文本回复:")
    print(message.content)
```

---

## 七、 生产调试与运维常用命令

### 1. 服务守护进程管理命令 (`scripts/litellm-service.sh`)
```bash
# 1. 启动常驻后台网关
./scripts/litellm-service.sh start

# 2. 查看网关健康状态与 PID 进程
./scripts/litellm-service.sh status

# 3. 查看实时追加滚动日志
./scripts/litellm-service.sh logs

# 4. 平滑重启网关服务
./scripts/litellm-service.sh restart

# 5. 停止网关服务
./scripts/litellm-service.sh stop

# 6. 一键安装开机自启守护 (macOS LaunchAgent / Linux systemd)
./scripts/litellm-service.sh install-daemon
```

---

### 2. 健康检查与模型列表探活
```bash
# 1. 检查网关运行健康状态
curl http://localhost:4000/health

# 2. 查询当前网关已加载并暴露的逻辑模型列表 (使用 Master Key 或 Virtual Key)
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer sk-enterprise-master-secret-key"
```

---

### 3. 命令行快速冒烟测试

#### 测试 OpenAI 协议端点 (`/v1/chat/completions`)
```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy-key" \
  -d '{
    "model": "coder-model",
    "messages": [{"role": "user", "content": "ping"}],
    "max_tokens": 10
  }'
```

#### 测试 Anthropic 协议端点 (`/v1/messages` - 针对 Claude Code)
```bash
curl http://localhost:4000/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: sk-dummy-key" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "architect-model",
    "messages": [{"role": "user", "content": "ping"}],
    "max_tokens": 10
  }'
```

---

### 4. 排查日志与诊断
当遇到模型调用异常或参数错误时：
```bash
# 启动时开启详细调试输出 (查看每次转发的 Header 与 Body)
litellm --config configs/litellm.yaml --port 4000 --detailed_debug

# Docker 容器环境下查看实时日志
docker logs -f enterprise-litellm-proxy
```

---

### 5. 常见问题排查清单 (Troubleshooting)

| 现象 | 可能原因 | 排查与解决办法 |
| :--- | :--- | :--- |
| **400 Bad Request: `Unknown parameter`** | 上游传递了目标模型不兼容的参数（如 `frequency_penalty` 传给 Claude） | 确认 `litellm_settings` 下已开启 `drop_params: true`。 |
| **Connection Refused (`localhost:1234`)** | 容器内使用 `localhost` 无法访问宿主机服务 | 将 `localhost` 替换为 `host.docker.internal`，或宿主机服务绑定至 `0.0.0.0`。 |
| **Claude Code 报鉴权或接口失败** | 环境变量未正确映射或缺少 Anthropic 协议头 | 确认设置 `ANTHROPIC_BASE_URL="http://localhost:4000"`，LiteLLM 需升级到支持 `/v1/messages` 的新版本。 |
| **流式调用缺少 Token 统计** | 流式传输默认不附带 usage 块 | 客户端请求中开启 `stream_options: {"include_usage": true}`，或在网关 YAML 中全局启用。 |
| **数据库审计无记录** | PostgreSQL 连接配置错误或表未初始化 | 检查 `DATABASE_URL`，观察容器启动日志中 prisma migration 的执行状态。 |
| **429 Too Many Requests (Budget Exceeded)** | 虚拟 Key 触碰预算硬上限或 RPM 上限 | 访问 Web UI (`:4000/ui`) 调高该 Key 的 `max_budget` 或重置周期。 |
| **Skill 挂载后 Agent 响应迟缓或报错** | Skill 文本过大超过后端模型最大 Context 窗口 | 在网关设置 `max_input_tokens`，或精简 `SKILL.md`，按需由 Agent 动态挂载。 |
