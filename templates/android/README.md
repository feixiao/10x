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
- `scripts/`:
  - `setup-ai-env.sh`: 软链接与环境检查
  - `audit-diffs.sh`: 物理切分 code.diff 与 tests.diff
- `tasks/`:
  - `tracker.md`: 任务调度流水线
  - `templates/topic-template.md`: Android 任务卡模版
