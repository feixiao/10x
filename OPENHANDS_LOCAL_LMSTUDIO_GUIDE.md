# OpenHands 本地部署与使用指南（搭配 LMStudio 本地大模型）

本指南介绍如何在本地 macOS/Linux 环境下部署 **OpenHands**，并将其 LLM 推理后端无缝切换到 **LMStudio** 本地运行的大模型。

---

## 一、 核心架构与网络拓扑

OpenHands 的核心组件运行在 Docker 容器内，而 LMStudio 运行在宿主机上。通信拓扑如下：

```mermaid
graph LR
    subgraph Host [宿主机 (macOS)]
        LMS[LMStudio 本地服务<br/>http://127.0.0.1:1234/v1]
        CodeDir[本地项目源码目录<br/>挂载进沙盒]
    end

    subgraph Docker [Docker 容器层]
        OH[OpenHands 核心系统<br/>ghcr.io/all-hands-ai/openhands]
        Runtime[沙盒执行环境 Container]
    end

    OH -->|通过 host.docker.internal:1234| LMS
    OH -->|Docker Socket 控制| Runtime
    Runtime -->|读写修改| CodeDir
```

---

## 二、 第一步：LMStudio 准备与配置（关键坑点）

OpenHands 对底层模型的**上下文长度**和**工具调用能力（Function Calling / CodeAct）**有极高要求，必须正确配置 LMStudio：

### 1. 推荐模型选型
* **首选推荐**：`Qwen/Qwen2.5-Coder-32B-Instruct-GGUF`（或 `14B`）
  * 目前开源界在 CodeAct、Bash 工具调用和指令遵循上与 OpenAI 格式兼容性最好的本地模型。
* **不推荐**：7B 以下小模型、未对齐的 Base 模型（无法稳定输出 OpenHands 要求的工具调用 JSON/代码块）。

### 2. LMStudio 服务端设置
打开 LMStudio -> 点击左侧双向箭头图标（**Developer / Local Server**）：
1. **加载模型**：选中已下载的 `Qwen2.5-Coder`。
2. **Context Length（上下文长度）**：
   * **必须调大至至少 16,384 (16k)**，推荐 **32,768 (32k)**。
   * *避坑*：LMStudio 默认往往只有 2048 或 4096，OpenHands 跑 2 轮 Bash 就会爆上下文（Context Overflow）。
3. **Server Configurations**：
   * 端口默认为 `1234`。
   * 勾选 **Enable CORS**。
   * 记录右侧面板中的 **Model ID**（例如 `qwen2.5-coder-32b-instruct`，后续配置必须一致）。
4. **启动服务**：点击 **Start Server**，看到终端显示 `Listening on http://localhost:1234` 即可。

---

## 三、 第二步：启动 OpenHands (Docker 部署)

在终端运行以下命令拉取并启动 OpenHands：

### 1. 准备本地工作目录与状态目录
```bash
# 创建保存 OpenHands 会话状态的目录
mkdir -p ~/.openhands-state

# 指定你想让 Agent 操作的代码目录（例如当前项目根目录）
export WORKSPACE_BASE="$HOME/wk/github/10x"
```

### 2. 启动 Docker 容器
```bash
docker run -d \
    --name openhands-app \
    -p 3000:3000 \
    -e SANDBOX_USER_ID=$(id -u) \
    -e WORKSPACE_BASE=$WORKSPACE_BASE \
    -e LLM_BASE_URL="http://host.docker.internal:1234/v1" \
    -e LLM_API_KEY="lm-studio" \
    -e LLM_MODEL="openai/qwen2.5-coder-32b-instruct" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ~/.openhands-state:/.openhands-state \
    -v $WORKSPACE_BASE:/opt/workspace_base \
    --add-host host.docker.internal:host-gateway \
    ghcr.io/all-hands-ai/openhands:latest
```

#### 参数解析（为什么这么配）：
* **`LLM_BASE_URL="http://host.docker.internal:1234/v1"`**：
  * 在 Docker 容器内部访问宿主机的 LMStudio，**绝对不能写 `127.0.0.1`**，必须使用 `host.docker.internal`。
* **`LLM_MODEL="openai/<your-model-id>"`**：
  * OpenHands 底层采用 LiteLLM。对于任何兼容 OpenAI 接口的本地端点，前缀必须加上 `openai/`，后接 LMStudio 中加载的模型标识符。
* **`-v /var/run/docker.sock:/var/run/docker.sock`**：
  * OpenHands 会自动拉起一个独立的 Runtime 容器来安全执行 Agent 的代码与 Bash 命令。

---

## 四、 第三步：Web UI 使用与工作流

1. **访问界面**：
   * 打开浏览器访问：`http://localhost:3000`。
2. **确认/修改模型配置**：
   * 点击左下角 **Settings（齿轮图标）**：
     * **LLM Provider**：选择 `OpenAI`（或 Custom）。
     * **Model**：填写与 LMStudio 一致的名称（如 `qwen2.5-coder-32b-instruct`）。
     * **Base URL**：`http://host.docker.internal:1234/v1`。
     * **API Key**：任意填写（如 `lm-studio`）。
     * 点击 **Save** 并测试连接。
3. **开展重构或编码任务**：
   * 在界面主对话框输入任务，例如：
     > *"请分析当前项目的目录结构，并在 tests/ 目录下添加一个新的自动化测试用例。"*
   * **右侧面板**会实时同步：
     * **Workspace**：源码树预览。
     * **Terminal**：Agent 在隔离沙盒中运行的 Bash 命令输出。
     * **Changes (Diff)**：Agent 每次改动的 Git Diff 审查面板。

---

## 五、 本地大模型跑 OpenHands 的实际局限与防翻车策略

将商业模型（Claude 3.5 Sonnet）降级为本地大模型（LMStudio）跑全自主 Agent 时，会面临以下**物理瓶颈**：

| 现象 / 瓶颈 | 产生原因 | 应对策略 |
| :--- | :--- | :--- |
| **JSON Parse Error / 动作解析失败** | 本地模型有时无法严格遵循 CodeAct 规定的 tool_call 格式 | 在 LMStudio 确保开启 JBNF / Grammars 语法校验（若支持），或降级选用专门微调的 Coder 模型（如 Qwen2.5-Coder）。 |
| **无限单命令打转** | 本地模型推理逻辑链短，遇到一次语法错误反复重试同一种改法 | 界面中随时点击 **Pause（暂停）**，通过右侧 Web 终端人工执行正确命令，再恢复 Agent。 |
| **极度缓慢 (Token/s 低)** | 本地显存带宽受限。OpenHands 每一轮会把系统提示词 + 历史终端日志（数千 Token）全部重新送入 Prefill | 1. 尽量使用量化版本（如 Q4_K_M 或 Q8_0）。<br>2. 限制单次任务规模，一个任务只解决一个原子函数或单文件。 |
| **上下文溢出截断 (Context Limit)** | 本地机器显存有限，上下文无法开到 128k/200k | 定期在对话框打字要求模型：`"请重置记忆，总结目前完成的步骤，开始下一个独立步骤"`。 |

---

## 六、 常用管理命令

```bash
# 查看 OpenHands 运行日志（排查是否成功连上 LMStudio）
docker logs -f openhands-app

# 停止服务
docker stop openhands-app

# 清理并重启
docker rm -f openhands-app
# 重新执行上述 docker run 启动命令
```
