# Pi 版：用现成能力加速研发

核对环境：本机 Pi 1.1.0，`pi list` 显示未安装扩展包。此页是 [通用工具选型与研究证据](./AI_WORKFLOWS.md) 的 Pi 使用版，不涉及开发编排器。具体 CLI 选项以 [Pi 命令行文档](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/cli.md) 和本机 `pi --help` 为准。

## 先用一个 Pi 完成闭环

在**实际代码仓库**运行 `pi`。给它明确的预期行为、至少一个失败场景、允许改动范围，以及仓库已有的单测和集成测试入口；让它自己定位相关实现，修改后运行真实测试，最后报告 diff、命令输出和未覆盖项。Pi 默认提供 `read`、`bash`、`edit`、`write`，支持直接读文件、执行测试和编辑源码。它没有内置的子 Agent 管理或 Agent Teams；一个清楚的任务通常先用一个会话完成。

可直接向交互会话提出：

> 在当前代码仓库修复这个真实问题：{现象与复现}。验收：{正常输入结果}、{错误输入结果}。先定位入口、现有测试和项目规则，再做最小范围修改；运行相关单测、项目规定的回归命令，报告实际输出和 diff。遇到接口契约不明或无法验证的行为先说明。

Pi 的[交互说明](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/usage.md)包括会话续接、查看工具输出与方向调整。不要用模型文字中的“已通过”代替测试命令结果。

## 加第二视角：只读审查

实现者完成后，开启**新的 Pi 会话**检查同一待合并 diff 和验收要求。Pi 的 `--tools` 可以限制新会话只使用读取与搜索工具：

```sh
pi --no-mcp --no-extensions --tools read,grep,find,ls --print "审查当前变更是否遗漏验收条件、负例或权限边界；只报告能从代码证明的问题，附文件位置"
```

这个会话禁用 MCP 与扩展，且没有 `bash`、`edit`、`write`；如需让它看到尚未提交的 diff，可从终端把 diff 经标准输入提供给 `pi --print`。只读审查用于发现遗漏，项目测试和 CI 仍负责可执行门槛。Pi [CLI 文档](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/cli.md)明确支持 `--tools`、标准输入和一次性 `--print` 模式。

## 真正可并行时：多个 Pi 会话

若任务能按独立模块分工，在目标 Git 仓库中为每个编码任务准备独立 worktree，然后分别在对应目录运行 `pi`。主会话先确定接口契约、文件归属及测试命令；各会话仅处理自己的模块、运行局部测试并交付可审查提交。主会话整合改动后，必须在**集成版本**运行跨模块测试、构建和 CI。worktree 解决文件覆盖，不能保证接口或行为兼容。目标仓库至少要有一次提交；本 `10x` 仓库是研究文档，没有应用测试，不能用来证明并行编码的交付效果。

对批量、互不依赖的一次性任务，Pi 还提供 `pi --print` 非交互模式与 `pi --mode json` 事件流，适合由已有 CI 或任务系统调用。依 [Pi CLI 集成说明](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/cli-integration.md)，`--print` 的失败或中止会以非零状态退出；JSON 流里的 Agent 失败不一定令进程退出非零，使用该模式时须检查事件中的结束状态。不要只解析模型最后一句话判断成功。

## 什么时候考虑 Pi 扩展

只有在手动协调多个 worktree 会话反复消耗时间时，才考虑现成扩展或用 Pi 的扩展机制增加调度能力。Pi 基础版[明确不内置子 Agent](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md)，本机当前也没有安装相关包；不能把“让 Pi 自行创建并协调团队”当作已具备的默认能力。[推荐 Skill 与 Agent 清单的本机核对](./AI_WORKFLOWS.md#skill-与-agent-安装判断)针对 Claude Code 的候选插件，不等同于 Pi 的扩展。

**判断是否提效**：沿用 [实验记录](./EXPERIMENT_LOG.md) 的字段，观察一个 Pi、Pi 加只读审查、多个 Pi 会话三个方案各自的交付总耗时、人工审查与返工、通过验收情况和工具成本。已有外部研究的结果与适用边界见 [通用指南](./AI_WORKFLOWS.md)。
