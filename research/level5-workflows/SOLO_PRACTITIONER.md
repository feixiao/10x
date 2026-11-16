# Level 5 通用方案：个人超级个体版 (Solo Practitioner Edition)

> **适用对象**：独立开发者、自由职业者、小型创业团队中的技术个体（1~2 人）。
>
> **设计原则**：
> - **工具无关（Tool-Agnostic）**：不绑定任何特定 Agent CLI，底层可用任何编码 Agent；
> - **零基建起步**：不需要部署数据库、容器集群或专用服务器，单机即可运行；
> - **渐进式生长**：从最小可用闭环起步，按需逐层叠加能力。

---

## 目录

- [一、 心智模型：个人版 Level 5 到底在做什么？](#一-心智模型个人版-level-5-到底在做什么)
- [二、 最小可用闭环（Day 1 即可运行）](#二-最小可用闭环day-1-即可运行)
- [三、 四层渐进式架构](#三-四层渐进式架构)
  - [第一层：结构化契约（Task Contract）](#第一层结构化契约task-contract)
  - [第二层：物理隔离车间（Isolated Workspace）](#第二层物理隔离车间isolated-workspace)
  - [第三层：确定性闭环（Deterministic Loop）](#第三层确定性闭环deterministic-loop)
  - [第四层：混合算力与成本控制](#第四层混合算力与成本控制)
- [四、 日常工作节奏与操作手册](#四-日常工作节奏与操作手册)
- [五、 个人版自检清单](#五-个人版自检清单)

---

## 一、 心智模型：个人版 Level 5 到底在做什么？

Level 3 是"你在电脑前，甩一个任务给 AI，盯着它干完"。
Level 5 是"你定好规则和流程，AI 按你的流水线自动干，你只在关键节点拍板"。

对个人开发者而言，Level 5 的核心价值不是搭一套复杂系统，而是建立一套**可复用的个人研发纪律**：

```
                    ┌─────────────────────────────────────┐
                    │   你的大脑 (架构决策 + 最终审查)      │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │   纸面契约 (Markdown 任务卡)          │
                    │   "做什么、怎么验收、绝对不许碰什么"    │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
     ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
     │  隔离车间 A      │ │  隔离车间 B      │ │  隔离车间 C      │
     │  feat/auth       │ │  fix/cache       │ │  feat/export     │
     │  (独立分支/目录)  │ │  (独立分支/目录)  │ │  (独立分支/目录)  │
     └────────┬────────┘ └────────┬────────┘ └────────┬────────┘
              │                    │                    │
              └────────────────────┼────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │   验收三件套：                        │
                    │   1. 单测全绿？                       │
                    │   2. git diff tests/ 有无篡改？       │
                    │   3. 代码改动合理？                    │
                    └──────────────┬──────────────────────┘
                                   │
                              合入主干 ✅
```

---

## 二、 最小可用闭环（Day 1 即可运行）

不需要安装任何额外软件，不需要写任何脚本。以下是**零基建起步**的极简闭环，你用任何一个编码 Agent 都能执行：

### Step 1：写一张任务卡（30 秒）

在你的项目里创建一个 `tasks/` 目录，新建一个 Markdown 文件：

```markdown
<!-- tasks/101-jwt-auth.md -->
# TASK-101: 实现 JWT 统一鉴权中间件

## 目标
为所有 /api/* 路由添加 JWT Bearer Token 校验中间件。

## 验收命令
pytest tests/test_auth.py -v

## 严禁触碰 (负向清单)
- 不要修改 tests/ 目录下的任何文件
- 不要修改 database/ 目录下的 migration 文件
- 不要引入新的第三方依赖
```

### Step 2：开一个隔离空间（5 秒）

```bash
# 方式 A：最轻量——开个新分支
git checkout -b feat/101-jwt-auth

# 方式 B：更干净——用 worktree 物理隔离（推荐并行多任务时用）
git worktree add ../ws-101 -b feat/101-jwt-auth
cd ../ws-101
```

### Step 3：将任务卡喂给任意 Agent（10 秒）

```bash
# 你用什么工具都行，核心就是把任务卡内容和验收命令告诉它：

# 用 omp：
omp -p "$(cat tasks/101-jwt-auth.md)"

# 用 aider：
aider --message "$(cat tasks/101-jwt-auth.md)" --test-cmd "pytest tests/test_auth.py"

# 用 claude code：
claude -p "$(cat tasks/101-jwt-auth.md)"

# 用任何支持标准输入的 Agent：
cat tasks/101-jwt-auth.md | your-favorite-agent
```

### Step 4：验收（30 秒）

```bash
# 1. 单测有没有通过？
pytest tests/test_auth.py -v

# 2. 它有没有偷改我的单测？
git diff tests/
# 如果输出为空 = 安全；如果有改动 = 仔细看一眼是补充还是作弊

# 3. 业务代码改得合理吗？
git diff src/
# 快速浏览，合理就合入
git checkout main && git merge feat/101-jwt-auth
```

**以上就是个人版 Level 5 的最小可用闭环。没有任何额外工具依赖。**

---

## 三、 四层渐进式架构

在最小闭环用熟之后，可以按需叠加以下能力层。每一层都是独立的，不强制全部采用：

### 第一层：结构化契约（Task Contract）

**要解决的问题**：每次手写任务描述太随意，容易漏验收条件或忘写负向清单。

**做法**：创建一个标准任务卡模板，以后每个新需求都从模板拷贝：

```markdown
<!-- tasks/template.md -->
# TASK-{ID}: {标题}

## 背景与目标
{一段话描述需求背景和期望达成的效果}

## 输入/输出接口契约
- 输入：{参数、请求格式}
- 输出：{返回值、响应格式}

## 验收命令
{确定性的单测或构建命令，如 pytest / npm test / go test ./...}

## 负向清单 (严禁触碰)
- [ ] 不得修改 tests/ 目录下任何文件
- [ ] 不得修改数据库 migration 文件
- [ ] 不得引入未经批准的第三方依赖
- [ ] 不得删除或注释掉任何已有的断言 (assert)

## 预估改动范围
- 新增文件：{列出}
- 修改文件：{列出}
- 预估代码行数：{不超过 N 行}
```

**收益**：让你的每次委派都有一致的质量，Agent 拿到的上下文更精准，输出更稳定。

---

### 第二层：物理隔离车间（Isolated Workspace）

**要解决的问题**：同时推进多个需求时，分支切换容易弄脏工作区。

**做法**：用一个极简的 Shell 函数（放到你的 `.zshrc` / `.bashrc` 里）包装 `git worktree`：

```bash
# 加到你的 ~/.zshrc 或 ~/.bashrc

# 开工：创建隔离车间
work-start() {
  local task_id="$1"
  local branch="feat/${task_id}"
  git worktree add "../ws-${task_id}" -b "${branch}" 2>/dev/null \
    || git worktree add "../ws-${task_id}" "${branch}"
  echo "🔧 车间已就绪: ../ws-${task_id} (分支: ${branch})"
  cd "../ws-${task_id}"
}

# 收工：验收后关闭车间
work-done() {
  local task_id="$1"
  cd "$(git rev-parse --show-toplevel 2>/dev/null || echo ..)"
  git worktree remove "../ws-${task_id}" --force 2>/dev/null
  echo "✅ 车间 ws-${task_id} 已关闭"
}

# 巡检：查看所有活跃车间
work-status() {
  git worktree list
}
```

**使用方式**：

```bash
work-start 101-auth        # 自动创建隔离目录和分支，cd 进去
# ... 在这里跑 Agent ...
work-done 101-auth          # 合入后一键清理
```

---

### 第三层：确定性闭环（Deterministic Loop）

**要解决的问题**：Agent 跑偏了你没注意到；跑了很久才发现浪费了 Token。

**做法**：写一个极简的 Shell 脚本封装"重试+熔断"逻辑（50 行以内，不依赖任何框架）：

```bash
#!/usr/bin/env bash
# run-agent.sh — 通用单兵闭环执行器（工具无关）
set -euo pipefail

TASK_SPEC="$1"        # 任务卡路径，如 tasks/101-auth.md
TEST_CMD="$2"         # 验收命令，如 "pytest tests/test_auth.py"
AGENT_CMD="${3:-omp}"  # 底层 Agent，默认用 omp，随便换
MAX_RETRIES="${4:-3}"  # 最大重试次数

attempt=0
while [ $attempt -lt $MAX_RETRIES ]; do
  attempt=$((attempt + 1))
  echo "━━━ 第 ${attempt}/${MAX_RETRIES} 次尝试 ━━━"

  # 1. 调用 Agent (工具无关：只要能接受文本输入的 CLI 都行)
  $AGENT_CMD -p "$(cat "$TASK_SPEC")" 2>&1 || true

  # 2. 运行验收测试
  if eval "$TEST_CMD" 2>&1; then
    echo "✅ 单测全部通过"

    # 3. 防作弊检查：Agent 是否篡改了测试文件？
    if git diff --name-only | grep -q "^tests/"; then
      echo "⚠️  警告: Agent 修改了 tests/ 目录，请人工审查"
    fi
    echo "🎉 任务完成，请执行 git diff 审查后合入"
    exit 0
  fi

  echo "❌ 第 ${attempt} 次单测未通过"
  if [ $attempt -lt $MAX_RETRIES ]; then
    echo "🔄 回滚脏代码，干净上下文重试..."
    git checkout -- .   # 回滚所有未提交改动
  fi
done

echo "🚨 熔断：连续 ${MAX_RETRIES} 次失败，任务挂起，请人工介入"
# 保存现场快照
git diff > "circuit_break_$(date +%Y%m%d_%H%M%S).patch"
exit 1
```

**使用方式（对任何 Agent 通用）**：

```bash
chmod +x run-agent.sh

# 用 omp 跑：
./run-agent.sh tasks/101-auth.md "pytest tests/test_auth.py" omp

# 换成 aider 跑：
./run-agent.sh tasks/101-auth.md "pytest tests/test_auth.py" aider

# 换成 claude 跑：
./run-agent.sh tasks/101-auth.md "pytest tests/test_auth.py" claude
```

**这 50 行 Shell 脚本浓缩了 Level 5 最核心的三个机制**：
1. 闭环验收（跑测试）；
2. 防作弊检测（检查 `tests/` 是否被改）；
3. 熔断保护（3 次失败自动挂起并保存现场）。

---

### 第四层：混合算力与成本控制

**要解决的问题**：全走云端 API 太贵，全走本地模型又不够聪明。

**做法**：在本地跑一个 LiteLLM 统一代理（单进程、零依赖数据库），让所有 Agent 通过它路由：

```yaml
# litellm-config.yaml — 个人版极简配置

model_list:
  # 重度思考（架构设计、复杂 debug）→ 云端旗舰
  - model_name: "smart"
    litellm_params:
      model: "anthropic/claude-sonnet-4-20250514"
      api_key: "sk-ant-xxx"

  # 日常编码（样板代码、单测、重构）→ 本地高吞吐
  - model_name: "fast"
    litellm_params:
      model: "openai/qwen3-32b"          # 本地 LMStudio / Ollama 暴露的 OpenAI 兼容端口
      api_base: "http://localhost:1234/v1"
      api_key: "not-needed"

  # 兜底降级（云端配额用完时自动切到本地）
  - model_name: "fallback"
    litellm_params:
      model: "openai/gemma-4-27b"
      api_base: "http://localhost:1234/v1"
      api_key: "not-needed"
```

```bash
# 一行启动本地网关
litellm --config litellm-config.yaml --port 4000

# 然后所有 Agent 统一指向本地代理
export OPENAI_API_BASE=http://localhost:4000/v1
export OPENAI_API_KEY=sk-anything  # LiteLLM 本地不校验

# 日常编码用便宜模型
omp --model fast "实现 JWT 鉴权..."

# 遇到复杂架构问题切旗舰
omp --model smart "重新设计分布式缓存架构..."
```

**收益**：80% 日常编码走本地免费模型，20% 核心思考走云端，月度 API 账单可控制在 $10~30 以内。

---

## 四、 日常工作节奏与操作手册

一个成熟的个人版 Level 5 日常工作节奏如下：

```
08:30  写 2~3 张任务卡 (tasks/101.md, tasks/102.md, tasks/103.md)
         ↓
08:40  work-start 101-auth     # 拉起隔离车间 A
       work-start 102-cache    # 拉起隔离车间 B
         ↓
08:45  在车间 A 跑 Agent 处理 auth 任务 (后台)
       在车间 B 跑 Agent 处理 cache 任务 (后台)
       你去做架构思考 / 写文档 / 喝咖啡 ☕
         ↓
09:30  回来验收车间 A：
       - pytest tests/test_auth.py ✅
       - git diff tests/ → 空 (没篡改) ✅
       - git diff src/ → 扫一眼，合理 ✅
       - git checkout main && git merge feat/101-auth
       - work-done 101-auth
         ↓
09:45  回来验收车间 B：
       - pytest tests/test_cache.py ❌ (失败)
       - 看报错，发现是 Redis 连接配置问题
       - 写一行补充说明追加到 tasks/102-cache.md
       - 再跑一轮 Agent（或自己手动改 2 行搞定）
         ↓
10:00  开始处理 tasks/103.md ...
```

---

## 五、 个人版自检清单

用以下清单评估你的个人 Level 5 成熟度：

- [ ] **契约习惯**：每次委派 Agent 之前，是否写了（哪怕很简短的）任务卡，包含验收命令和负向清单？
- [ ] **物理隔离**：是否在独立分支或 Worktree 中运行 Agent，而非在 `main` 分支上直接操作？
- [ ] **验收纪律**：Agent 完成后，是否检查了 `git diff tests/` 确认测试未被篡改？
- [ ] **熔断意识**：Agent 连续跑了 3 轮以上还搞不定时，是否及时人工介入，而非让它继续空转烧钱？
- [ ] **成本感知**：是否知道自己每月在 AI API 上花了多少钱？日常编码是否尽量走本地或廉价模型？
- [ ] **工具灵活**：你是否能在 10 秒内切换到另一个 Agent 工具，而不需要改任何流程或脚本？
