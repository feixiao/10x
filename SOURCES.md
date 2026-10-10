# AI 研发提效：来源与证据边界

资料核对日期：2026-10-10。具体数字与适用方法见 [现成工具与证据](./AI_WORKFLOWS.md)；这里保留用于核对原文的入口。软件功能以实际使用版本为准。

## 效率研究（一手结果）

- [GitHub Copilot 受控实验](https://arxiv.org/abs/2302.06590)：限定 JavaScript HTTP 服务任务；报告完成速度快 55.8%。
- [三项开发者现场实验](https://www.microsoft.com/en-us/research/publication/the-effects-of-generative-ai-on-high-skilled-work-evidence-from-three-field-experiments-with-software-developers/)：合并 4,867 名开发者，报告完成任务数增加 26.08%（标准误 10.3%）；研究对象是代码补全助手。
- [METR 2025 随机实验](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/)：16 位熟悉大型开源仓库的贡献者、246 项任务，使用当时工具的任务耗时增加 19%。
- [METR 2026 更新](https://metr.org/blog/2026-02-24-uplift-update/)：后续样本出现提速迹象；作者指出招募选择偏差、并行 Agent 计时等问题，数据不能确定普遍提速幅度。

这些实验的任务类型、参与者、工具时期和指标不同；不能将数字相加或转用为 Pi、Claude Code 多 Agent 的预期收益。

## 产品能力（官方文档）

- [Pi 基础说明](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md)、[CLI](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/cli.md)、[CLI 集成模式](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/cli-integration.md)：核查基础工具、`--print`、JSON 输出和扩展边界。
- [Claude Code 最佳实践](https://code.claude.com/docs/en/best-practices)、[命令参考](https://code.claude.com/docs/en/commands)、[子 Agent](https://code.claude.com/docs/en/sub-agents)、[Agent Teams](https://code.claude.com/docs/en/agent-teams)：核查验收、审查、并行能力和实验性限制。
- [推荐 Skills](https://github.com/feixiao/ai/blob/main/ClaudeCode/RECOMMENDED_SKILLS.md) 与 [推荐 Agents](https://github.com/feixiao/ai/blob/main/ClaudeCode/RECOMMENDED_AGENTS.md)：用户提供的候选清单；属于选型建议，不是效果实验，也不能代替官方文档确认当前内置能力。

产品文档说明功能及其前提，不提供该工作流对本项目的真实提效结果。研究自己的仓库时保留工具版本、任务背景、实际测试输出、审查与返工时间；未知的验收行为单独标注。
