# AGENTS.md - Go Project Context & Agent Rules

本文档为所有接入本项目的 AI Agent（Claude Code、Codex、Cursor、omp 等）提供单一事实源约束与工作流索引。

---

## 一、 快速架构导航 (Architecture & Navigation)
- **技能库**: `skills/`（通过软链接共享至 `.claude/skills`、`.agents/skills`）
- **代码地图**: `skills/internal-codemap/`（按需查阅当前工程模块入口）
- **任务调度**: `tasks/tracker.md`（主控零代码读写）与 `tasks/` 专题任务卡
- **质量防线**: `skills/internal-audit/` 与 `scripts/audit-diffs.sh`（双阶段盲审）

---

## 二、 五大角色权限隔离矩阵 (Role & Privilege Matrix)

| 角色名称 (Role) | 规范定义 | 允许权限 (Permissions) | 绝对禁止行为 (Hard Prohibitions) |
| :--- | :--- | :--- | :--- |
| **主控调度官** | `roles/master-dispatcher.md` | 调度任务状态机，派生子任务与管理 Worktree | **严禁阅读业务大文件、严禁直接编写或修改任何代码** |
| **执行工兵** | `roles/worker-developer.md` | 隔离 Worktree 内代码/单测读写，执行构建与单测 | **严禁跨任务改无关文件、严禁篡改断言、严禁伪造测试日志** |
| **独立盲审官** | `roles/independent-auditor.md` | 独立会话审查 `code.diff` 与 `tests.diff` | **绝对只读，严禁动手修代码；严禁在 Phase 1 查阅提交说明与测试** |
| **汇总记账员** | `roles/bookkeeper.md` | 校验 Git 提交记录，追加任务流水账表格 | **严禁修改任何代码；严禁伪造不存在的 Git Commit Hash** |
| **只读支持顾问** | `roles/read-only-support.md` | 检索代码地图与文档，响应团队技术咨询 | **绝对只读，严禁任何写操作；严禁泄露内部敏感配置** |

---

## 三、 Go 构建与单测命令速查 (Commands Reference)
```bash
# 1. 竞态检测全量单测 (必须加 -race)
go test -v -race ./...

# 2. 针对指定包运行单测
go test -v -race ./pkg/foo/...

# 3. 静态分析与 Lint
golangci-lint run
```

---

## 四、 不可妥协的工程红线 (Hard Invariants)

1. **严禁自动推送远端**：本地可以编译、测试、创建 Commit，但严禁执行 `git push` 或发布 Tag。
2. **禁止篡改断言作弊**：遇单测失败，必须修复业务代码逻辑，严禁删除断言或放宽判定条件。
- **外部 I/O 隔离**: 所有外部网络、存储调用必须通过 `interface` 解耦，单测强制依赖 Fake/Mock。
- **并发与竞态**: 严禁跨 Goroutine 未加锁读写共享 map/slice；每个 goroutine 必须有基于 Context 或通道的可靠退出条件。
- **循环内 defer**: 严禁在 `for` 循环内直接堆积 `defer`。
3. **验证命令输出作为完工证据**：代码修改后必须输出真实运行日志证明通过，严禁伪造结果或交付未经验证的代码。
