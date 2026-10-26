# 任务契约规范卡 (Task Spec Contract)

> **使用方式**：复制本文件至 `tasks/<task-id>.md` 或 `tasks/<task-id>/spec.md`，作为人类架构师发给 Agent 的唯一确定性输入契约。

---

## 1. 基础元信息
- **Task ID**: `TASK-101`
- **Feature Name**: `实现 JWT 统一鉴权中间件`
- **Owner**: `人类架构师 (You)`
- **Assigned Agents**: `Planner -> Coder -> QA (Reviewer) -> DevOps`
- **Status**: `PENDING` <!-- PENDING | IN_PROGRESS | BLOCKED | DONE -->

---

## 2. 确定性验收准则 (Acceptance Criteria)
> 必须是确定性的 Shell 命令，严禁主观模糊描述。

```bash
# 1. 核心单元测试（必须全部通过）
pytest tests/test_auth.py -v

# 2. 静态分析与规范校验
ruff check src/auth/
```

---

## 3. 负向边界与非目标 (Explicit Non-Goals)
> 明确列出 Agent 绝对禁止触碰的模块、逻辑与配置。

1. **禁止破坏已有数据库表结构**：严禁修改 `users` 与 `roles` 的现有主键与外键关联；
2. **禁止修改基线测试**：严禁放宽或删除 `tests/test_auth.py` 中既有的异常断言；
3. **禁止引入重型依赖**：仅允许使用已有依赖或轻量标准库，严禁引入未授权的三方库。

---

## 4. 改动行数预算 (Diff Budget)
- **最大变更行数**：`<= 200 行` (新增 + 变更)
- **范围限制**：仅限 `src/auth/` 与 `tests/test_auth.py`

---

## 5. 快速启动指令
```bash
# Solo 模式快速拉起工作车间:
./scripts/solo-worktree.sh start TASK-101 "pytest tests/test_auth.py"

# Supervisor 全生命周期状态机推进:
python3 scripts/supervisor.py create --task-id TASK-101 --title "JWT鉴权中间件" --test-cmd "pytest tests/test_auth.py"
python3 scripts/supervisor.py run --task-id TASK-101
```
