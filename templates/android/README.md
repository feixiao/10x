# Android 工程 AI Agent 研发套件

这是一个专为 **Android 独立工程**量身定制的 AI Agent 研发底盘。拷贝到你的 Android 工程中即可开箱即用。

## 快速接入
```bash
# 拷贝到你的 Android 工程
cp -R templates/android/. /path/to/my-android-project/
cp -R templates/common/roles /path/to/my-android-project/roles/core
cp docs/CLIENT_ADAPTERS.md /path/to/my-android-project/AI-CLIENT-ADAPTERS.md

# 进入工程并初始化环境
cd /path/to/my-android-project
bash scripts/setup-ai-env.sh
```

## 资产说明
- `AGENTS.md`: 纯 Android 规则与命令速查
- `roles/`: 语言模板提供的自动驾驶流程专用角色
- `roles/core/`: 四个跨客户端共用角色契约
- `skills/`:
  - `internal-codemap`: Android 模块入口与 Target 树
  - `project-develop`: Android 研发规范与单测门禁
  - `project-autopilot`: 主从隔离自动驾驶
  - `internal-audit`: Android 双阶段代码盲审防线
  - `project-support`: 只读答疑
- `config/`:
  - `detekt/detekt.yml`: 静态分析红线（圈复杂度10、方法行数40、Compose 大写命名兼容）
- `quality-gate/`:
  - `libs.versions.toml.snippet`: Detekt, Slack Lint, Roborazzi, Turbine 依赖版本
  - `build.gradle.kts.root.snippet`: 根构建 Detekt 与 `aiVerify` 聚合任务
  - `build.gradle.kts.module.snippet`: 模块端 Slack Lint 与 Robolectric 截图配置
  - `BaseScreenshotTest.kt`: JVM 纯端渲染截图基类（免模拟器，~200ms）
  - `ExampleScreenTest.kt`: 4 状态（Default/Loading/Error/DarkMode）测试范例
- `scripts/`:
  - `setup-ai-env.sh`: 软链接、配置与环境初始化
  - `ai-verify.sh`: AI Agent 自动化质量门禁与自愈检查脚本
  - `audit-diffs.sh`: 物理切分 code.diff 与 tests.diff
- `tasks/`:
  - `tracker.md`: 任务调度流水线
  - `templates/topic-template.md`: Android 任务卡模版

## 动态关注点模式 (Focus Modes)
Android 项目常同时包含 **Kotlin/Compose 业务界面** 与 **C++/NDK 底层原生引擎**。套件提供动态门禁切换，避免底层开发被迫跑 UI 截图，也避免页面改动漏测 Native 编译：

| 模式 | 触发方式 | 门禁内容 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **`auto`** | 默认 (无参数) | 嗅探 `git diff`：仅改 C++ 走 native，仅改 UI 走 ui，跨层修改走 dual | 日常开发零配置首选 |
| **`native`** | `--focus=native` | C++/NDK 编译、ASan 内存安全、Host CTest/GTest（跳过 UI） | 音视频算法、图形引擎、C++ 性能调优 |
| **`ui`** | `--focus=ui` | Detekt、Slack Lint、Turbine 状态机单测、Roborazzi 4 状态截图 | 页面样式、业务逻辑、组件交互开发 |
| **`dual`** | `--focus=dual` | 串行执行 Native 门禁与 UI 全量门禁 | JNI 跨层调用、全量发版前回归 |

**持久化配置**：
- 可以在工程根目录创建 `.ai-focus` 文件（内容写入 `native`、`ui`、`dual` 或 `auto`）。
- 或在任务卡（`tasks/<topic>.md`）中为单个子任务指定 `focus` 属性。

---

## 黑盒交付落地流程

### 场景 A：UI / 业务页面需求 (Vibe Coding)
1. 将 `quality-gate/` 内的 Gradle 配置合并至工程对应的 `build.gradle.kts` 与 `libs.versions.toml`。
2. 运行 `bash scripts/setup-ai-env.sh` 完成 Agent 工具入口挂载。
3. 给 AI 下发需求（契约先行：给出 `UiState` 与 `UiIntent` 字段）。
4. 要求 AI 自主运行 `./scripts/ai-verify.sh --focus=ui`，直到产出 `screenshots/*.png` 后交付。
5. 开发者仅需查看 `screenshots/` 目录下的 PNG 图片确认视觉与交互状态，无需逐行阅读代码。

### 场景 B：C++ / NDK 原生层需求
1. 运行 `bash scripts/setup-ai-env.sh` 完成环境初始化。
2. 给 AI 下发 Native 接口契约与算法需求。
3. 要求 AI 遵循 RAII 与 JNI 异常/引用屏障，运行 `./scripts/ai-verify.sh --focus=native`。
4. AI 交付 CTest/GTest 测试通过日志与 ASan 零泄漏报告作为验收凭据。
