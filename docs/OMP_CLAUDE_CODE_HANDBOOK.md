# OMP (oh-my-pi) 与 Claude Code 研发提效方案、全局配置与量化监控手册

> **适用技术栈**：C/C++ 音视频与实时通信（FFmpeg / WebRTC / GStreamer / Android Native）、Golang & Modern C++ 高并发系统与异步 I/O、多语言整洁架构与设计模式（Go / C++ / Java Clean Code）

---

## 一、 核心架构定位与双擎分工策略

oh-my-pi (OMP) 与 Claude Code 共享终端交互、MCP 协议与 Subagent 基础能力，但在底层工程机制上高度互补：

| 技术栈维度 | 核心研发痛点 | OMP (oh-my-pi) 提效职责 | Claude Code 提效职责 |
| :--- | :--- | :--- | :--- |
| **音视频与 RTC Native 栈**<br>（C/C++ / FFmpeg / WebRTC / GStreamer / NDK） | 宏与函数指针层级深、音画同步与编解码状态机复杂、`AVFrame`/`GstBuffer` 引用计数泄漏与 JNI 崩溃难调 | • **LSP 符号直达**：接入 `clangd`（基于 `compile_commands.json`）精准解析结构体、函数指针表与宏展开<br>• **DAP 内存与断点调试**：调用内置 `gdb` / `lldb-dap` 执行 `set_data_breakpoint`（监控引用计数或 PTS 篡改）、`read_memory`（检查 NALU/RTP 裸字节）与 `threads`（排查解复用/解码线程死锁）<br>• **TTSR 引用计数拦截**：流式检测分配函数是否遗漏清理路径 | • **协议与状态机 Plan 拆解**：使用 Plan Mode 梳理 SDP/ICE/RTP/RTCP 协商流转与拥塞控制边界<br>• **样板代码 Skill 化**：将 GObject 插件骨架、FFmpeg 编解码器初始化、JNI 签名绑定封装为全局 `~/.claude/skills/` 资产<br>• **长链路源码归纳**：利用结构化上下文压缩沉淀底层源码手册 |
| **高并发与系统后端栈**<br>（Golang & Modern C++ / 异步 I/O / 消息中间件） | Goroutine 泄漏、Channel 死锁、Data Race 竞态、C++ 裸指针与移动语义生命周期错误、异步回调复杂 | • **Go/C++ 运行时调试**：通过内置 `dlv`（Delve）与 `lldb-dap` 适配器 Attach 进程，拉取全量 Goroutine/OS 线程栈帧与锁状态<br>• **AST/流式实时中断（TTSR）**：在生成流中实时拦截 C++ 裸 `new`/`delete` 或静默丢弃核心错误<br>• **Session Tree 分支压测**：用 `/tree` 切出多个会话分支对比不同无锁队列或 I/O 模型表现 | • **快慢分级门禁（Hooks）**：`PostToolUse` 执行毫秒级语法检查，`Stop` 阶段自动运行 `go test -race`、`golangci-lint`、`clang-tidy` 及 ASan/TSan/UBSan<br>• **三阶段契约式开发**：按“需求边界 → 并发/内存契约 → 增量实现”推进，先锁定接口与锁粒度再写实现代码 |
| **多语言整洁架构栈**<br>（Go / C++ / Java 设计模式与 Clean Code） | 多语言同构实现易发生职责漂移、过度工程抽象、跨语言文件并发编辑易行号错位 | • **YAML Swarm 多语言并发**：通过 `/swarm run` DAG 编排并行启动 Go、C++、Java 三个独立子代理同步实现同一架构模式<br>• **Hashline 哈希锚定编辑**：使用 `@oh-my-pi/hashline` 按内容哈希打补丁，消除并发修改长文件时的行号偏移并省去 60%+ 编辑 Token<br>• **Mnemopi 架构记忆**：在本地 SQLite + 向量库中自动沉淀 Clean Code 偏好与重构范式 | • **对抗性 Clean Code 审查**：配置独立上下文的 Reviewer 子代理，仅输入 Diff 专门挑刺圈复杂度、SOLID 违背与多余抽象<br>• **批量重构扇出（Fan-out）**：使用 `claude -p` 非交互模式配合脚本批量生成多语言边界测试与架构对比表 |

---

## 二、 跨环境可直接复用的全局配置文件清单（避坑修订版）

以下配置文件已针对生产实操中的常见陷阱做了工程化修正：
1. **兼容 C++14/17/20 多标准基线**：避免在锁定 C++14 的音视频/WebRTC 老工程中强推 `std::span` 导致编译报错。
2. **拆分快慢 Hooks 并修复 stdin 解析**：`PostToolUse` 仅跑极速包级检查（修复 Go 单文件同包符号未定义报错），重型 `go test -race` 与 `clang-tidy` 移至 `Stop` 门禁，同时自动写入提效监控埋点。
3. **消除 TTSR 正则误伤**：排除 C++ `= delete;` 禁用拷贝语法、Placement `new(buf)` 以及 Go `defer { _ = conn.Close() }()` 的流式误杀，且仅拦截 `tool` 调用参数而非解释性 `text`。

### 1. 全局核心护栏：`~/.claude/CLAUDE.md`
（Claude Code 与 OMP 均会自动读取此文件；保持在 200 字级别以防注意力衰减）

```markdown
# 全局技术栈与整洁架构护栏 (Global Tech-Stack Guardrails)

## 1. C / 音视频与 RTC Native (FFmpeg / GStreamer / WebRTC / NDK)
- **生命周期配对**：分配 `AVPacket`、`AVFrame`、`AVFormatContext`、`GstBuffer`、`GstCaps`、`GstElement` 或 JNI 局部引用后，必须在同一函数内立即编写对应的 `av_packet_unref`、`gst_buffer_unref` 或 `DeleteLocalRef` 清理分支（优先使用 `goto fail;` 集中清理或 C++ RAII 智能指针自定义 Deleter 包装）。
- **时基与内存对齐**：处理 PTS/DTS 必须显式调用 `av_rescale_q` 转换 `time_base`；处理 YUV/PCM 裸数据必须遵守 `linesize` 步长对齐，严禁假设紧凑内存布局而直接 `memcpy(width * height)`。

## 2. Modern C++ (兼容 C++14 / C++17 / C++20)
- **标准与内存所有权**：严格遵循项目 `CMakeLists.txt` 指定的 C++ 标准；严格执行 RAII 与 Rule of Zero/Five，严禁业务层裸 `new`/`delete`、`malloc`/`free` 及 C 风格强转；资源独占使用 `std::unique_ptr`（若标准 ≥ C++17/20 则只读切片优先用 `std::string_view` / `std::span`）。
- **并发与异步**：跨线程回调必须显式校验生命周期（`std::weak_ptr` 或取消令牌），严禁在异步 Lambda 中隐式按引用捕获局部栈变量 `[&]`。

## 3. Golang 高并发与分布式后端
- **协程生命周期**：严禁启动无退出通道或未绑定 `context.Context` 的 `go func()`；所有 Channel 必须明确唯一关闭方（Sender closes），防止向已关闭 Channel 发送数据或 Goroutine 泄漏。
- **并发安全与错误处理**：共享状态必须显式声明 `sync.Mutex` / `atomic` 保护边界；严禁静默忽略业务 error，错误向上传递必须使用 `fmt.Errorf("...: %w", err)` 保留上下文。

## 4. Clean Code 与设计模式准则
- **克制抽象**：严禁修改任务范围外的代码；单函数圈复杂度 ≤ 10，缩进嵌套 ≤ 3 层（优先使用卫语句 Early Return）；在出现 3 次以上重复前，严禁提前创建过度泛化的 Helper 或基类。
```

### 2. Claude Code 快慢分级门禁与自动监控埋点：`~/.claude/settings.json`
（通过 `PostToolUse` 执行极速静态语法校验，通过 `Stop` 在回合结束时执行重型并发竞态/Tidy 检测，并将通过率自动记入 `~/.claude/metrics/hook-events.jsonl`）

```json
{
  "permissions": {
    "allow": [
      "Bash(go test *)",
      "Bash(go vet *)",
      "Bash(golangci-lint *)",
      "Bash(cmake *)",
      "Bash(ctest *)",
      "Bash(clang-tidy *)",
      "Bash(git status)",
      "Bash(git diff *)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(jq -r \".tool_input.file_path // empty\" 2>/dev/null); [ -z \"$FILE\" ] && exit 0; mkdir -p ~/.claude/metrics; START=$(date +%s); STATUS=\"pass\"; case \"$FILE\" in *.go) PKG_DIR=$(dirname \"$FILE\"); go vet \"./$PKG_DIR\" || STATUS=\"fail\" ;; *.c|*.cc|*.cpp|*.h|*.hpp) if [ -f compile_commands.json ]; then clang-tidy -p . --quiet \"$FILE\" || STATUS=\"fail\"; fi ;; esac; COST=$(($(date +%s) - START)); printf \"{\\\"ts\\\":\\\"%s\\\",\\\"stage\\\":\\\"PostToolUse\\\",\\\"file\\\":\\\"%s\\\",\\\"status\\\":\\\"%s\\\",\\\"duration_s\\\":%d}\\n\" \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \"$FILE\" \"$STATUS\" \"$COST\" >> ~/.claude/metrics/hook-events.jsonl; [ \"$STATUS\" = \"pass\" ]'"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'CHANGED=$(git diff --name-only HEAD 2>/dev/null); [ -z \"$CHANGED\" ] && exit 0; mkdir -p ~/.claude/metrics; START=$(date +%s); STATUS=\"pass\"; if echo \"$CHANGED\" | grep -qE \"\\.go$\"; then golangci-lint run ./... && go test -race ./... || STATUS=\"fail\"; fi; if echo \"$CHANGED\" | grep -qE \"\\.(c|cc|cpp)$\" && [ -d build ]; then ctest --test-dir build --output-on-failure || STATUS=\"fail\"; fi; COST=$(($(date +%s) - START)); printf \"{\\\"ts\\\":\\\"%s\\\",\\\"stage\\\":\\\"StopGate\\\",\\\"file\\\":\\\"batch\\\",\\\"status\\\":\\\"%s\\\",\\\"duration_s\\\":%d}\\n\" \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \"$STATUS\" \"$COST\" >> ~/.claude/metrics/hook-events.jsonl; [ \"$STATUS\" = \"pass\" ]'"
          }
        ]
      }
    ]
  }
}
```

### 3. 对抗性 Clean Code 审查子代理：`~/.claude/agents/clean-code-reviewer.md`
（在独立干净上下文中审查代码，避免主 Agent 对自己刚写出的代码产生确认偏误）

```markdown
---
name: clean-code-reviewer
description: 针对 C/C++、Golang、Java 与音视频代码的独立架构、并发安全与整洁代码审查专家
tools: Read, Grep, Glob, Bash
model: opus
---

你是一名严苛的系统架构师与音视频/高并发代码审查专家。仅基于当前的 `git diff` 与目标契约进行独立挑刺，只报告影响正确性、并发安全、内存生命周期或严重违背 Clean Code 的缺陷：

1. **音视频与 Native 安全**：检查是否存在未释放的 `AVFrame`/`AVPacket`/`GstBuffer`、未处理的 `AVERROR(EAGAIN)` / `AVERROR_EOF`、错误的 `time_base` 换算或非对齐内存访问（未按 `linesize` 逐行拷贝）。
2. **Golang & C++ 并发安全**：检查是否存在 Goroutine 泄漏、Channel 死锁、锁粒度过大、C++ 悬垂引用（尤其是异步回调捕获）或违反 RAII 的裸资源分配。
3. **整洁架构与模式地道性**：检查是否存在职责混杂、圈复杂度过高（>10）、不必要的防御性分支、修改任务范围外代码或违背目标语言惯用法的生硬设计模式移植。

输出格式：按 `[致命缺陷 / 并发与内存风险 / 架构坏味道]` 分级列出具体 `文件路径:行号`、触发崩溃/竞态的输入场景与最小修复补丁建议。
```

### 4. OMP 5 角色模型路由配置：`~/.omp/agent/models.yml`
（利用 OMP 角色路由机制分流高阶推理与高频编码任务，降低约 40% API 成本）

```yaml
roles:
  plan:
    model: claude-opus-4-6
    description: 负责音视频协议状态机梳理、高并发系统架构设计、WBS 模块拆解与接口契约定义
  slow:
    model: claude-opus-4-6
    description: 负责结合 DAP 调试栈帧排查 C/C++ 内存越界、音画同步漂移与 Go 分布式死锁
  default:
    model: claude-sonnet-4-6
    description: 负责日常 Modern C++、Golang、Java 核心模块编码、设计模式实现与单元测试编写
  smol:
    model: deepseek-v4-flash
    description: 负责子代理批量扫描 FFmpeg/GStreamer/WebRTC 头文件、宏定义检索与日志初步过滤
  commit:
    model: deepseek-v4-flash
    description: 负责生成符合 Conventional Commits 规范的提交说明与技术手册索引更新
  fallback:
    - provider: openrouter
      model: anthropic/claude-sonnet-4-6
```

### 5. OMP TTSR 流式实时中断规则（防误伤精修版）：`~/.omp/rules/tech-stack-ttsr.md`
（仅针对 `tool` 代码写入流拦截，排除了 C++ `= delete;`、Placement `new` 与 Go `defer _ = xxx.Close()` 的误报）

```markdown
---
name: cpp-no-raw-new-delete
description: 严禁在 Modern C++ 业务代码中直接赋值裸 new 或调用裸 delete 语句，强制使用智能指针或容器
scope:
  paths: ["**/*.cpp", "**/*.cc", "**/*.hpp"]
  targets: ["tool"]
condition: "(?:=\\s*new\\s+[A-Za-z_][A-Za-z0-9_:<>]*\\s*\\(|^\\s*delete\\s+(?:\\[\\]\\s*)?[a-zA-Z_][a-zA-Z0-9_>-]*\\s*;)"
interruptMode: true
---
检测到 C++ 代码中使用了裸 `= new Type(...)` 或裸 `delete ptr;` 语句（注：`= delete;` 禁用函数声明与 Placement `new(buf)` 不受影响）。请立即改用 `std::make_unique`、`std::make_shared` 或栈上 RAII 包装器管理生命周期。

---
name: go-no-silent-error-drop
description: 阻止 Golang 中直接用 `_ = fn()` 静默丢弃非 Close 函数的错误返回值
scope:
  paths: ["**/*.go"]
  targets: ["tool"]
condition: "^\\s*_\\s*=\\s*[a-zA-Z0-9_.]+\\([^)]*\\)\\s*$"
interruptMode: true
---
检测到独立语句 `_ = fn()` 静默丢弃返回值或错误。请显式接收并处理 `err`（若是 `defer` 中忽略 `Close()`，请显式写注释说明或交由命名错误处理）。
```

### 6. OMP 原生 DAP 调试器配置：`~/.omp/dap.json`

```json
{
  "adapters": {
    "lldb-dap": {
      "command": "lldb-dap",
      "args": [],
      "languages": ["c", "cpp", "rust"],
      "fileTypes": [".c", ".cc", ".cpp", ".h", ".hpp"],
      "rootMarkers": ["compile_commands.json", "CMakeLists.txt", "Makefile", "configure"],
      "launchDefaults": {
        "request": "launch",
        "stopOnEntry": false
      }
    },
    "dlv": {
      "command": "dlv",
      "args": ["dap"],
      "connectMode": "socket",
      "acceptsDirectoryProgram": true,
      "languages": ["go"],
      "fileTypes": [".go"],
      "rootMarkers": ["go.mod", "go.work"]
    }
  }
}
```

### 7. OMP 多语言设计模式 / 跨栈同构流水线：`~/.omp/swarm/multi-lang-pattern.yaml`

```yaml
name: multi-language-architecture-pipeline
agents:
  architect:
    role: plan
    prompt: |
      明确目标架构模式或核心组件的统一领域模型、接口契约、并发安全边界与异常测试用例，输出到 SPEC.md。
  go_impl:
    role: default
    depends_on: [architect]
    prompt: |
      基于 SPEC.md，使用地道 Golang 范式（接口组合、Functional Options、Context 并发管控）完成实现并运行 `go test -race ./...`。
  cpp_impl:
    role: default
    depends_on: [architect]
    prompt: |
      基于 SPEC.md，遵循工程 CMakeLists.txt 指定的 C++ 标准（RAII、智能指针、移动语义）完成实现并通过 ASan/UBSan 单测。
  java_impl:
    role: default
    depends_on: [architect]
    prompt: |
      基于 SPEC.md，使用地道现代 Java 范式（Record、Sealed Classes、泛型与并发包）完成实现并通过 JUnit 测试。
  reviewer_and_docs:
    role: slow
    depends_on: [go_impl, cpp_impl, java_impl]
    prompt: |
      对比 Go、Modern C++、Java 三端实现的内存模型、派发开销与工程取舍，使用 Hashline 更新跨语言对比文档并执行 Clean Code 终审。
```

---

## 三、 高频实战提效工作流（SOP）

### 1. C/C++ 音视频与底层源码精读工作流
1. 在任意 C/C++ 源码目录先执行 `bear -- make` 或 `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .` 生成 `compile_commands.json`。
2. 启动 `omp`，让 Agent 通过内置 `lsp` 工具追踪结构体与函数指针引用，自动将核心调用链沉淀至 Mnemopi 本地 SQLite 向量记忆库。

### 2. Native 崩溃、内存篡改与高并发死锁排障工作流
1. 在 `omp` 中直接下发指令：
   > “使用 `debug` 工具启动目标程序，在核心处理函数设置条件断点；若发生字段异常篡改，调用 `data_breakpoint_info` 与 `set_data_breakpoint` 设置内存写观察点（Watchpoint），触发后输出 `stack_trace`、`threads` 与 `read_memory` 分析根因。”

### 3. 复杂系统模块三阶段契约开发工作流
1. **阶段一（需求反问与契约锁定）**：在 Claude Code 中开启 Plan Mode，要求使用 `AskUserQuestion` 访谈线程模型、锁边界、错误恢复与性能指标，生成 `SPEC.md`。
2. **阶段二（分步实现与自动门禁）**：执行 `/clear` 清空探索噪声，基于 `SPEC.md` 逐模块编码，`PostToolUse` 实时校验语法，`Stop` Hook 自动执行 `clang-tidy` / `go test -race` / `ctest`。
3. **阶段三（独立上下文对抗审查）**：提交前调用 `clean-code-reviewer` 子代理（或运行 `./scripts/audit-diffs.sh`）对 Diff 进行独立挑刺。

---

## 四、 提效怎么监控？—— 零侵入自动化度量体系与落地工具

很多团队制定了指标表格，但最后沦为“填表汇报”，原因在于需要人工计时或手动统计。要让提效监控真正运转起来，必须遵循**“零人工填表、全链路从 Hook 与 Git 历史自动采集”**的原则。

### 1. 指标分层与自动化数据源映射

| 技术栈维度 | 核心量化指标 | 自动采集数据源（零人工介入） | 目标基线与预期提效收益 |
| :--- | :--- | :--- | :--- |
| **工程质量门禁**<br>（Go / C++ / Native） | **1. Hook 门禁一次通过率**<br>(First-Pass Gate Rate) | `~/.claude/metrics/hook-events.jsonl`<br>（由 `settings.json` 中的 `PostToolUse` 与 `Stop` Hook 自动打点） | 依靠 TTSR 拦截与 `CLAUDE.md` 护栏，`PostToolUse` 一次通过率 ≥ 90%，`Stop` 门禁一次通过率 ≥ 85% |
| **并发与内存安全**<br>（音视频 / 高并发） | **2. 内存泄漏与竞态逃逸率**<br>(Sanitizer / Race Escape) | Git 主干 CI 流水线（ASan / TSan / `go test -race` 失败次数）对比本地 `StopGate` 拦截次数 | 依靠本地 `StopGate` 强制拦截，主干分支 Memory Leak & Data Race 逃逸数保持为 **0** |
| **交付吞吐与质量**<br>（全栈通用） | **3. AI 协同提交占比与 48h 返工率**<br>(AI Commit Ratio & Churn) | `git log` 解析含 `Co-Authored-By:` 标记的提交行数，以及该提交涉及文件在 48 小时内被 `fix:` 提交覆写的行比例 | AI 协同有效留存代码占比 60%–75%+；48h 紧跟修复返工率（Churn Rate）控制在 **< 10%** |
| **排障与定位效率**<br>（音视频 / Native） | **4. 单次任务交互轮次与耗时**<br>(Turns & Duration per Task) | 解析 `~/.claude/projects/` 会话 JSONL 日志中的起止时间戳、Tool 调用次数与重试次数 | 消除“加日志—重编译”循环，Native 崩溃/死锁排障平均耗时缩短 45%–60%，核心排障对话 ≤ 5 轮 |
| **成本与补丁精度**<br>（OMP + Claude Code） | **5. 补丁命中率与 Token 成本**<br>(Edit Hit Rate & Cost) | 统计 `Edit` / `Hashline` 工具调用成功次数 vs 报错重试次数；按模型角色统计输入/输出 Token | 补丁一次命中率 ≥ 98%；启用 OMP 5 角色路由后单功能点综合 API 成本下降 35%–45% |

---

### 2. 三层自动监控落地机制（开箱即用）

本仓库已配套提供 [`scripts/ai-metrics.sh`](../scripts/ai-metrics.sh) 脚本，无需额外部署服务端即可在本地或 CI 中一键输出提效监控看板：

#### 第一层：Hook 门禁探针（实时采集一次通过率与拦截耗时）
只要启用了本文第二部分的 `~/.claude/settings.json`，每次 Agent 修改代码或结束回合时，都会在 `~/.claude/metrics/hook-events.jsonl` 追加一行结构化记录：
```json
{"ts":"2026-10-24T08:15:22Z","stage":"PostToolUse","file":"pkg/rtc/jitter.go","status":"pass","duration_s":1}
{"ts":"2026-10-24T08:16:05Z","stage":"StopGate","file":"batch","status":"fail","duration_s":6}
```
* **它能回答什么问题？**
  * Agent 写出的 C++/Go 代码是不是经常连编译、`clang-tidy` 或 `go test -race` 都过不了？（如果 `StopGate` 一次通过率低于 70%，说明 `CLAUDE.md` 护栏需要补充高频报错规则）。
  * 本地 Hook 拦截了多少次原本会逃逸到主干 CI 的并发 Race 或内存问题？

#### 第二层：Git 提交溯源与 48 小时代码返工率（衡量“真提效”还是“制造垃圾代码”）
单纯统计“AI 写了多少行代码”毫无意义——如果 AI 写了 1000 行，第二天人工花 4 小时重写了 800 行，那是负提效。
`scripts/ai-metrics.sh` 会自动扫描 Git 历史：
1. **AI 协同出码占比**：统计带有 `Co-Authored-By: Claude`（或 OMP 提交标记）的 Commit 净增删行数占总迭代代码量的比例。
2. **近期修复返工比（Fix-to-Feat Ratio）**：统计近期 Commit 中 `fix:` / `revert:` 提交占总提交的比例，以及 AI 提交修改过的文件在随后的提交中被紧急修补的频次。

#### 第三层：本地会话日志（JSONL）解析（监控交互轮次与编辑命中率）
Claude Code 默认将每次会话保存在 `~/.claude/projects/<project-slug>/*.jsonl`。通过扫描会话日志中的 `tool_use` 与 `tool_result`：
* 自动计算 **`Edit` 补丁一次命中率**（是否存在 `old_string not found` 反复重试耗费 Token）。
* 自动识别 **超过 15 轮仍未结束的“泥潭会话”**（提示开发者应及时 `/clear` 或切换为三阶段契约模式）。

### 3. 日常监控运行方式

```bash
# 查看当前仓库与本机的 AI 研发提效监控看板（默认统计最近 7 天）
./scripts/ai-metrics.sh report

# 指定统计最近 30 天的数据
./scripts/ai-metrics.sh report --days 30

# 手动在自定义脚本或 CI 中记录一次门禁结果
./scripts/ai-metrics.sh record-hook StopGate batch pass 4
```
