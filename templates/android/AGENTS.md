# AGENTS.md - Android Project Context & Agent Rules

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

## 三、 Android 验证与质量门禁速查 (Commands Reference)
```bash
# 1. AI 自动化质量门禁（推荐：编译 + Detekt + Lint + 单测 + Roborazzi截图）
./scripts/ai-verify.sh

# 2. 手动执行 Gradle 聚合门禁
./gradlew aiVerify

# 3. 运行本地单元测试 (无需真机)
./gradlew testDebugUnitTest

# 4. 静态代码分析
./gradlew detekt lintDebug

# 5. 抓取与比对 UI 快照
./gradlew recordRoborazziDebug
```
---

## 四、 不可妥协的工程红线 (Hard Invariants)

1. **严禁自动推送远端**：本地可以编译、测试、创建 Commit，但严禁执行 `git push` 或发布 Tag。
2. **禁止篡改断言作弊**：遇单测失败，必须修复业务代码逻辑，严禁删除断言或放宽判定条件。
- **主线程零负载**: 严禁在 Main (UI) 线程执行磁盘 I/O、网络请求或超过 5ms 的计算。
- **MVI 状态机与 Stateless Compose**:
  - 页面必须拆分 `UiState` 数据契约与 `UiIntent` 事件契约。
  - Composable 函数必须为无状态纯组件 `fun XxxContent(state: UiState, onIntent: (UiIntent) -> Unit)`，禁止在 UI 内部直接读写 ViewModel。
- **4 状态黄金 UI 快照**: 页面级修改必须编写继承自 `BaseScreenshotTest` 的测试，在 `screenshots/` 产出 Default、Loading、Error、DarkMode 四张快照。
- **门禁通过方可汇报**: 代码修改后必须自主运行 `./scripts/ai-verify.sh` 并确认输出 `✅ [SUCCESS]`，严禁交付未经验证的代码。
3. **验证命令输出作为完工证据**：代码修改后必须输出真实运行日志证明通过，严禁伪造结果或交付未经验证的代码。

---

## 五、 完工汇报规范 (Definition of Done)
严禁向人类汇报长篇实现代码，只展示机器门禁证据：
1. `./scripts/ai-verify.sh` 运行状态与耗时。
2. 生成的 UI 快照文件路径（`screenshots/*.png`）。
3. 单元测试覆盖的状态机边界情况。
