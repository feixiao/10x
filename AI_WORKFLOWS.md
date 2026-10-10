# 现成 AI 研发工作流：证据与选型

资料核对：2026-10-10。本文区分三类信息：**研究实证**只支持原研究条件下的结果；**产品文档**只说明工具当前提供什么能力；**工作建议**是据此提出的工程选择，尚无本项目的提效实测。目标仓库的测试与交付要求优先。

## 已有结果说明了什么

- [GitHub Copilot 受控实验](https://arxiv.org/abs/2302.06590)：限定的 JavaScript HTTP 服务任务中，AI 组完成速度快 55.8%。这支持边界明确任务中的提效可能性，不代表复杂既有代码库。
- [Microsoft 等三项现场实验](https://www.microsoft.com/en-us/research/publication/the-effects-of-generative-ai-on-high-skilled-work-evidence-from-three-field-experiments-with-software-developers/)：合并 4,867 名开发者，获得代码补全助手的一组完成任务数增加 26.08%（标准误 10.3%）。研究的是代码补全工具，不是多 Agent 编码。
- [METR 2025 随机实验](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/)：16 位熟悉大型开源仓库的开发者在 246 项真实任务上，使用当时工具平均耗时增加 19%。[2026 年更新](https://metr.org/blog/2026-02-24-uplift-update/)的后续样本出现提速迹象：原参与者子集估计耗时下降 18%，新招募者估计下降 4%，但两组区间均包括无效果；研究者特别指出样本选择和并行 Agent 计时问题，不能据此宣称稳定提速。

**证据边界**：这些研究的工具、任务、人员及统计口径各不相同。当前没有可直接套用到个人项目的“多 Agent 一定比单 Agent 快 X%”结论；下文的工具选择是待具体任务验证的建议，不是研究直接证明的最佳配置。

## 现成做法如何选

### 默认建议：一个编码 Agent + 可运行的验收

对小改、明确 bug、单模块功能，直接使用 Pi 或 Claude Code：给出目标、正常与失败例子、相关代码和项目测试命令；让 Agent 实现并运行局部测试，再运行项目规定的集成或 CI 检查。最后查看真实命令结果与 diff。Claude Code 的[最佳实践](https://code.claude.com/docs/en/best-practices)优先强调给 Agent 测试、构建或可观察行为，让结果可以被核验。Pi 基础版是轻量单 Agent 环境，可按相同工作协议使用；其基础发行版[未内置子 Agent](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md)，需要扩展或另开会话才有更复杂的编排。

### 需要第二视角：子 Agent 做调查或独立审查

当代码搜索、日志分析或测试设计会占用大量上下文时，让 [Claude Code 子 Agent](https://code.claude.com/docs/en/sub-agents)只负责该项，给主会话返回证据和结论。实现后用内置 [`/code-review`](https://code.claude.com/docs/en/commands) 审 diff，用 [`/verify`](https://code.claude.com/docs/en/commands) 运行应用观察行为；项目 CI 继续作为合并前的确定性门槛。审查者只报告有证据的正确性缺口，不把风格建议算成验收失败。

### 有独立模块或大量重复修改：并行工作

- 大规模、可拆成独立单位的迁移：Claude Code 内置 [`/batch`](https://code.claude.com/docs/en/commands) 会先研究仓库并展示拆分计划，批准后在独立 worktree 中分派 5–30 个任务，子 Agent 分别实现与运行测试。集成版本仍需项目全量检查。
- 需要成员互相讨论的跨层功能、相互质疑的故障假设：[Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)有主会话、成员、共享任务和通信；目前仍是实验能力，默认关闭，且只在交互会话中生成团队。给每个成员明确文件所有权与接口契约；同时写同一文件或高度依赖前置结果时，改为顺序执行。
- 需要隔离的并行会话：[Claude Code worktrees](https://code.claude.com/docs/en/common-workflows#run-parallel-sessions-with-worktrees)允许不同会话在不同 checkout 修改；它解决文件碰撞问题，本身不保证集成后的功能正确。
- 已有 PR 的 CI 失败与审查意见：Claude Code 的 [`/autofix-pr`](https://code.claude.com/docs/en/commands) 可在具备 GitHub CLI 和云会话权限的环境中监控并推送修复。采用前先按项目规则确认自动修复和远端写入边界。

## Skill 与 Agent 安装判断

参考 [推荐 Skills](https://github.com/feixiao/ai/blob/main/ClaudeCode/RECOMMENDED_SKILLS.md) 和 [推荐 Agents](https://github.com/feixiao/ai/blob/main/ClaudeCode/RECOMMENDED_AGENTS.md) 核对本机：Claude Code 2.1.286 的 `claude plugin list` 显示**没有已安装插件**；`~/.claude/agents/` 已有 11 个角色文件，其中包括代码审查、软件架构、前后端、DevOps 和应用安全；Pi 1.1.0 的 `pi list` 显示没有扩展包。市场目录中存在插件源码不等于已经安装启用。

这些清单是覆盖工程、产品与投资场景的候选目录，**不是本项目必装清单**。Claude Code 当前已有内置 `/code-review`、`/verify`、`/batch` 和子 Agent；完成代码审查、运行验证、并行迁移无需先安装同名第三方插件。已有角色文件也不代表自动增加测试能力：能否通过验收仍由目标项目的测试与 CI 决定。[planning-with-files](https://github.com/OthmanAdi/planning-with-files#the-3-file-pattern)是另一类能力：用计划、发现、进度三文件维持长任务执行状态；它不自动证明任务完成，也不负责多 Agent 集成。本机没有安装该第三方包，Pi 的适用方式见 [Pi 指南](./PI_WORKFLOWS.md#可选planning-with-files-插件)。

按真实需求补充即可：反复需要严格的调试或测试方法时再评估 `superpowers`；跨会话长任务频繁丢失执行状态时再评估 `planning-with-files`；经常进行前端设计、MCP 服务开发或特定领域工作时，再核对对应插件的维护状态、实际功能与权限范围。Pi 的扩展和 Claude Code 插件互不通用，不能把 Claude 的安装命令照搬到 Pi。安装前先确认内置命令与已有角色能否完成任务，再对单一候选做小范围验证；本次研究没有安装任何插件或改动全局 Agent 配置。

## 推荐的研发交付门槛

1. 任务开始前先确定可观察的成功与失败场景、改动边界、依赖顺序和验证命令；多阶段任务经审阅后可用三文件模式保存计划和状态，再分派 Agent。
2. Agent 完成局部任务后运行对应单测，反馈原始失败及处理过程；子 Agent 的“已经通过”文字不作为证据。
3. 并行工作整合后，在同一个待合并版本上运行集成测试、构建和 CI；不同 worktree 各自通过单测不等于组合通过。
4. 独立审查 diff 是否满足需求、遗漏边界或越界改动；协议、媒体、并发与性能结论补真实环境或负载的验证。
5. 记录总耗时、人工审查和返工、缺陷以及工具费用。只在已有任务数据暴露出瓶颈时，再升级到多 Agent 或自动化。

这份指南给出**证据分层后的选型建议**。若要判断某种组合是否适合自己的仓库，可用少量真实任务验证流程、记录全流程成本；[教学练习](./STEP_BY_STEP.md)只检验 plan → 并行执行 → 集成验收的操作链路，不是性能基准。
