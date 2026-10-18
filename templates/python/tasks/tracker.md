# tasks/tracker.md - 全局自动驾驶任务索引表

主控 Agent（Leader Agent）通过读写本文件进行全局任务调度。**严禁主控 Agent 越过本表直接介入代码。**

## 一、 全局任务状态机 (Global Task Pipeline)
- `ready`: 任务卡已建立并拆解完毕，等待调度。
- `running`: 正在由主控 Agent 按 Worktree 调度 Worker Agent 推进中。
- `review`: 所有子任务代码均已 Commit，等待双阶段盲审。
- `blocked`: 遇到连续失败或架构分歧，熔断挂起，等待人类介入。
- `done`: 盲审通过且已生成合入就绪分支。

| 任务编号 | 任务主题 (Topic) | 关联卡片文件 | 状态 (Status) | 负责人/执行者 |
| :--- | :--- | :--- | :--- | :--- |
| #001 | 示例功能改造 | `tasks/feat-sample.md` | ready | Agent Autopilot |
