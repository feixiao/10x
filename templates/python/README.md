# Python 工程 AI Agent 研发套件

这是一个专为 **Python 独立工程**量身定制的 AI Agent 研发底盘。拷贝到你的 Python 工程中即可开箱即用。

## 快速接入
```bash
# 拷贝到你的 Python 工程
cp -R templates/python/. /path/to/my-python-project/
cp -R templates/common/roles /path/to/my-python-project/roles/core
cp docs/CLIENT_ADAPTERS.md /path/to/my-python-project/AI-CLIENT-ADAPTERS.md

# 进入工程并初始化环境
cd /path/to/my-python-project
bash scripts/setup-ai-env.sh
```

## 资产说明
- `AGENTS.md`: 纯 Python 规则与命令速查
- `roles/`: 语言模板提供的自动驾驶流程专用角色
- `roles/core/`: 四个跨客户端共用角色契约
- `skills/`:
  - `internal-codemap`: Python 模块入口与 Target 树
  - `project-develop`: Python 研发规范与单测门禁
  - `project-autopilot`: 主从隔离自动驾驶
  - `internal-audit`: Python 双阶段代码盲审防线
  - `project-support`: 只读答疑
- `scripts/`:
  - `setup-ai-env.sh`: 软链接与环境检查
  - `audit-diffs.sh`: 物理切分 code.diff 与 tests.diff
- `tasks/`:
  - `tracker.md`: 任务调度流水线
  - `templates/topic-template.md`: Python 任务卡模版
