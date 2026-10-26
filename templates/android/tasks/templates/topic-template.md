# tasks/<topic-name>.md - Android 专题任务卡

## 1. 任务元数据与 Worktree 绑定表
- **主题名称**: <例如: feat-sample>
- **状态**: ready | running | review | blocked | done
- **缺省关注模式**: auto | ui | native | dual

| 目标工程 | 分支名称 | 隔离 Worktree 路径 | 单测/门禁验证命令 |
| :--- | :--- | :--- | :--- |
| **当前项目** | `feat/<topic-name>` | `../worktrees/<topic-name>` | `./scripts/ai-verify.sh` |
---

## 2. 原子子任务清单 (Sequential Execution)
- [ ] **#101** 实现 Repository 数据层逻辑与本地单测
  - **修改目标**: `app/src/main/` 与 `app/src/test/`
  - **必跑命令**: `./gradlew testDebugUnitTest`
- [ ] **#102** <下一个子任务目标>
  - **修改目标**: `...`
  - **必跑命令**: `...`

---

## 3. 提交记账表 (Review Commits Ledger)
| 子任务 | Commit Hash | 提交时间 | 变更摘要 | 盲审状态 |
| :--- | :--- | :--- | :--- | :--- |
| #101 | - | - | - | 待盲审 |
