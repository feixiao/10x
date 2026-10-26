# AI-Native 个人超级个体落地方案 (Solo Edition)

> **定位**：面向独立开发者与架构师的“一人研发团队”实战方案。作为终态目标蓝图（[`ai_native.md`](../ai_native.md)）的**第一阶段实操落地**，利用 **Aider + LiteLLM + 本地 LMStudio + Git Worktree**，实现多任务物理并行、TDD 单测自愈与本地化算力分流。

---

## 一、 核心架构拓扑

```mermaid
graph TD
    User[你: 人类架构师] -->|1. 任务契约 tasks/template.md| Dispatcher[scripts/solo-worktree.sh 调度器]
    
    subgraph 本地并发工作车间
        Dispatcher -->|创建独立分支与物理目录| WT1[Worktree A: feat/101-auth]
        Dispatcher -->|创建独立分支与物理目录| WT2[Worktree B: fix/102-cache]
        
        WT1 -->|Aider 实例 A| SessionA[Aider --architect]
        WT2 -->|Aider 实例 B| SessionB[Aider --architect]
        
        SessionA -->|--test-cmd 自动跑测| GateA[本地单测自愈闭环]
        SessionB -->|--test-cmd 自动跑测| GateB[本地单测自愈闭环]
    end

    SessionA & SessionB -->|OpenAI 协议统一访问| LiteLLM[LiteLLM Proxy 本地网关 :4000]
    
    subgraph 混合算力底座 (目标约 8:2 分流)
        LiteLLM -->|架构拆解 / --architect (目标约 20% 流量)| Magpie[本地 Magpie 网关 :3425/v1<br/>Claude Sonnet 5.5 / GPT-6 Luna / Gemini 3.8]
        LiteLLM -->|样板代码 / --editor-model (目标约 80% 流量)| LMStudio[本地 LMStudio: :1234/v1<br/>Qwen3.8 / Gemma4]
    end

    GateA & GateB -->|通过单测后合入主干| Audit[audit-diffs.sh 双阶段防作弊审查]
    Audit -->|人类 5 分钟复核放行| Main[Main 主干代码]
```

---

## 二、 环境准备

### 1. 安装核心工具链
```bash
# 1. 安装核心 Agent 与模型网关
uv tool install aider-chat
uv tool install 'litellm[proxy]'

# 2. 本地推理底座 (LMStudio)
# 启动 LMStudio，加载本地模型 (如 Qwen3.8 / Gemma)，开启本地服务端口 :1234
```

### 2. 启动算力网关 (LiteLLM)
使用仓库中预配置的 [`configs/solo/litellm.yaml`](../configs/solo/litellm.yaml)。

> 💡 **免 Key 认证说明**：云端重推理模型通过本地 **Magpie 网关**（`:3425/v1`）统一代理与会话保持，**无需在环境变量中配置任何云端 API Key**；日常代码改写由 **LMStudio**（`:1234/v1`）提供 0 边际成本算力。

```bash
# 一键启动本地多模型代理网关
litellm --config configs/solo/litellm.yaml --port 4000
```
*提示：网关启动后，所有请求均通过 `http://localhost:4000/v1` 统一路由，自动完成云端重推理与本地低边际成本模型分流。*

---

## 三、 日常研发标准作业程序 (SOP)

### 步骤 1：立项与定义任务契约（人类出题）
不要直接口头和 AI 聊天。先复制 `tasks/template.md` 并在主分支定义不可篡改的契约卡，例如 `tasks/101-jwt-auth.md`：
```markdown
# 任务目标: 实现基于 RS256 的 JWT 鉴权中间件
- 验收命令: pytest tests/test_auth.py -v
- 负向边界: 严禁修改已有的用户模型数据表结构
- 错误规范: 任何 Token 失效场景必须返回统一的 401 JSON 错误体
```

### 步骤 2：一键拉起独立并行车间
在终端运行本套件封装的调度脚本：
```bash
# 语法: ./scripts/solo-worktree.sh start <任务ID> [单测命令]
./scripts/solo-worktree.sh start 101-jwt-auth "pytest tests/test_auth.py -v"
```
**加固机制**：
1. 自动在 `../worktrees/101-jwt-auth` 创建物理隔离目录与 `feat/101-jwt-auth` 分支；
2. **自动跨目录同步任务卡**：自动拷贝主分支刚创建的 `tasks/101-jwt-auth.md`，杜绝未提交文件在 Worktree 中找不到的问题；
3. 自动挂载 `configs/solo/.aider.conf.yml` 启用双模型架构师模式；
4. 绑定单测命令，激活 Aider 失败自动修复机制。

### 步骤 3：Aider 自动化编码与单测自愈
在拉起的 Aider 会话中输入：
```text
/add tasks/101-jwt-auth.md
请严格根据上述契约实现 JWT 中间件，并补齐单测直至全绿。
```
* **Architect (Claude 3.7 / R1)**：给出架构设计和伪代码方案，等待人类确认；
* **Editor (本地 Qwen2.5-Coder)**：落地代码并自动运行 `pytest`；若单测报错，自动抓取 Traceback 尝试微调自愈，直至全绿。

### 步骤 4：审查与状态面板
开发过程中或完成后，随时查看全局车间状态：
```bash
# 查看所有并发车间、分支与修改状态
./scripts/solo-worktree.sh status

# 执行双阶段反作弊代码审查
./scripts/solo-worktree.sh audit 101-jwt-auth
```
* **阶段一 (代码审查)**：检查 `.audit/code.diff`，审查业务逻辑、异常处理与边界；
* **阶段二 (反作弊核对)**：检查 `.audit/tests.diff`，重点排查 Agent 是否有放宽断言、删除既有测试的作弊行为。

### 步骤 5：安全合入与注销清理
```bash
# 1. 切回主干并合入代码
git checkout main
git merge feat/101-jwt-auth

# 2. 安全清理已完成的 Worktree
./scripts/solo-worktree.sh close 101-jwt-auth
```
**注销安全防御**：
* 脚本会自动检查车间是否存在**未提交修改（含未跟踪文件）**；
* 脚本会自动校验分支是否已**真正合并入主干**，若未合并会强制弹出黄色警告并展示未合并提交，防止误删工作成果。

---

## 四、 个人版常见隐患与防护守则

| 场景 | 常见隐患 | 个人版防护策略 |
| :--- | :--- | :--- |
| **显存过载 / 调度排队** | 同时开多个本地大模型推理导致系统卡顿 | 多个 Worktree 共享同一个 LiteLLM 网关与 LMStudio 进程，由后端连接池排队处理。 |
| **单测假性通过** | Agent 修不好逻辑时反向把测试断言改成恒真 | 严格依赖 `scripts/audit-diffs.sh`。测试用例文件物理切分单独审查，严禁测试代码与业务代码混在一起漏审。 |
| **Worktree 误删** | 未提交或未合入代码在注销时被删 | `scripts/solo-worktree.sh close` 内置未提交文件扫描与 `branch --merged` 主干合并状态核验防御。 |
