# Android 工程 AI Agent 研发套件

这是一个专为 **Android 独立工程**量身定制的 AI Agent 研发底盘。拷贝到你的 Android 工程中即可开箱即用。

## 快速接入
```bash
# 拷贝到你的 Android 工程
cp -R templates/android/. /path/to/my-android-project/

# 进入工程并初始化环境
cd /path/to/my-android-project
bash scripts/setup-ai-env.sh
```

## 资产说明
- `AGENTS.md`: 纯 Android 规则与命令速查
- `roles/`: 五大专职角色 (主控、工兵、盲审官、记账员、支持顾问)
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

## 黑盒交付（Vibe Coding）落地流程
1. 将 `quality-gate/` 内的 Gradle 配置合并至工程对应的 `build.gradle.kts` 与 `libs.versions.toml`。
2. 运行 `bash scripts/setup-ai-env.sh` 完成 Agent 工具入口挂载。
3. 给 AI 下发需求（契约先行：给出 `UiState` 与 `UiIntent` 字段）。
4. 要求 AI 自主运行 `./scripts/ai-verify.sh`，直到 `BUILD SUCCESSFUL` 且产出 `screenshots/*.png` 后再行交付。
5. 开发者仅需查看 `screenshots/` 目录下的 PNG 图片确认视觉与交互状态，无需逐行阅读代码。
