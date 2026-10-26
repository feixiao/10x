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

## 三、 Android 验证与动态质量门禁速查 (Commands Reference)
```bash
# 1. AI 自动化质量门禁（默认 auto：根据 git diff 智能分流 UI 或 Native 门禁）
./scripts/ai-verify.sh

# 2. 原生 C++/NDK 专属门禁（跳过 UI 渲染与 Detekt，秒级验证）
./scripts/ai-verify.sh --focus=native

# 3. 业务与 UI 专属门禁（Detekt + Lint + 状态机单测 + Roborazzi 快照）
./scripts/ai-verify.sh --focus=ui

# 4. 双层全量门禁（Native 编译测试 + UI 门禁）
./scripts/ai-verify.sh --focus=dual

# 5. 本地 C++ 独立单测与 ASan 内存检测 (若已构建 host CMake)
ctest --test-dir build_native --output-on-failure
```
---

## 四、 不可妥协的工程红线 (Hard Invariants)

1. **严禁自动推送远端**：本地可以编译、测试、创建 Commit，但严禁执行 `git push` 或发布 Tag。
2. **禁止篡改断言作弊**：遇单测失败，必须修复业务代码逻辑，严禁删除断言或放宽判定条件。
3. **UI 与业务层红线**:
   - **主线程零负载**: 严禁在 Main (UI) 线程执行磁盘 I/O、网络请求或超过 5ms 的计算。
   - **MVI 状态机与 Stateless Compose**:
     - 页面必须拆分 `UiState` 数据契约与 `UiIntent` 事件契约。
     - Composable 函数必须为无状态纯组件 `fun XxxContent(state: UiState, onIntent: (UiIntent) -> Unit)`，禁止在 UI 内部直接读写 ViewModel。
   - **4 状态黄金 UI 快照**: 页面级修改必须编写继承自 `BaseScreenshotTest` 的测试，在 `screenshots/` 产出 Default、Loading、Error、DarkMode 四张快照。
4. **C++ / NDK / JNI 原生层红线**:
   - **RAII 与内存安全**: 堆内存必须由智能指针或 RAII 容器管理；**严禁裸指针（Raw Pointer）跨线程或跨异步事件传递**。
   - **JNIEnv 线程绑定**: `JNIEnv*` 严禁跨线程缓存或传递，跨线程必须通过 `JavaVM->AttachCurrentThread` 取得并配对 Detach。
   - **JNI 局部引用释放**: 循环体或频繁调用处必须显式调用 `env->DeleteLocalRef()`，防范 512 局部引用表溢出。
   - **JNI 异常隔离屏障**: 调用 Java 后必须检查 `env->ExceptionCheck()`；C++ 异常严禁穿越 JNI 泄露至 JVM，必须在 JNI 边界 catch-all 并安全转译。
5. **门禁通过方可汇报**: 代码修改后必须自主运行 `./scripts/ai-verify.sh`（或指定 `--focus`）并确认输出 `✅ [SUCCESS]`，严禁交付未经验证的代码。

---

## 五、 完工汇报规范 (Definition of Done)
严禁向人类汇报长篇实现代码，只展示机器门禁证据：
1. `./scripts/ai-verify.sh` 运行状态、执行模式与耗时。
2. **按任务关注点提供对应凭证**：
   - **UI 任务**: 生成的 UI 快照文件路径（`screenshots/*.png`）与状态机覆盖说明。
   - **Native 任务**: C++ 编译与 CTest/GTest 通过日志，及 ASan 内存零泄漏证据。
   - **桥接任务**: 同时提供 Native 测试与 UI 截图双重凭据。
