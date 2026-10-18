---
name: project-autopilot
description: "原子子任务自动驾驶与 Worktree 隔离调度技能"
---

# project-autopilot - 隔离自动驾驶调度协议

本技能定义主控调度 Agent（Leader Agent）与执行子 Agent（Worker Agent）之间的协同协议，彻底解决长编译日志污染上下文与多任务失忆问题。

## 零、 参与角色与权限契约
- **主控调度官**: 遵循 `roles/master-dispatcher.md`，执行零代码调度与 Worktree 派发。
- **执行工兵**: 遵循 `roles/worker-developer.md`，执行 Test-First 编码与原子 Commit。
- **汇总记账员**: 遵循 `roles/bookkeeper.md`，执行 Commit 事实校验与流水账追加。

## 一、 主控 Agent 铁律 (Zero-Code Discipline)
1. **绝对禁止亲自阅读业务实现代码或编写代码**：主控只读写 `tasks/tracker.md` 与 `tasks/<topic>.md`。
2. **单任务派生**：每次仅提取第一个处于未勾选 `[ ]` 状态的原子子任务（如 `#101`），派生子 Agent 前往指定 Worktree。
3. **熔断保护 (Circuit Breaker)**：若同一个子任务连续 2 次重试均失败，主控必须立即熔断并打上 `[BLOCKED]` 标记，交由人类接管。
