# Go 工程 AI Agent 研发套件

这是一个专为 **Go 独立工程**量身定制的 AI Agent 研发底盘。拷贝到你的 Go 工程中即可开箱即用。

## 快速接入
```bash
# 拷贝到你的 Go 工程
cp -R templates/go/. /path/to/my-go-project/

# 进入工程并初始化环境
cd /path/to/my-go-project
bash scripts/setup-ai-env.sh
```

## 资产说明
- `AGENTS.md`: 纯 Go 规则与命令速查
- `roles/`: 五大专职角色 (主控、工兵、盲审官、记账员、支持顾问)
- `skills/`:
  - `internal-codemap`: Go 模块入口与 Target 树
  - `project-develop`: Go 研发规范与单测门禁
  - `project-autopilot`: 主从隔离自动驾驶
  - `internal-audit`: Go 双阶段代码盲审防线
  - `project-support`: 只读答疑
- `scripts/`:
  - `setup-ai-env.sh`: 软链接与环境检查
  - `audit-diffs.sh`: 物理切分 code.diff 与 tests.diff
- `tasks/`:
  - `tracker.md`: 任务调度流水线
  - `templates/topic-template.md`: Go 任务卡模版
