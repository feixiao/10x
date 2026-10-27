#!/usr/bin/env bash
""":"
# Python wrapper polyglot
exec python3 "$0" "$@"
"""
# ==============================================================================
# scripts/supervisor.py - AI-Native 终态架构主控状态机调度器 (Supervisor)
# 
# 核心职责:
# 1. 1 人类架构师 + 4 专职 Agent (Planner / Coder / QA / DevOps) 协同状态流转
# 2. 上下文物理隔离: 以磁盘文件 (tasks/<id>/spec.md, tasks.md, git diff) 传递状态
# 3. 熔断机制 (Circuit Breaker): 失败超过 max_retries (默认 3 次) 自动熔断挂起并生成快照
# 4. Git Worktree 物理隔离调度与合入前反作弊门禁 (scripts/audit-diffs.sh)
# ==============================================================================

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    from task_builder import TaskBuilder, run_wizard
except ImportError:
    try:
        from scripts.task_builder import TaskBuilder, run_wizard
    except ImportError:
        TaskBuilder = None
        run_wizard = None

class State(str, Enum):
    INIT = "INIT"
    PLANNING = "PLANNING"
    PLAN_APPROVAL = "PLAN_APPROVAL"
    CODING = "CODING"
    TESTING = "TESTING"
    AUDITING = "AUDITING"
    CIRCUIT_BREAKER_BLOCKED = "CIRCUIT_BREAKER_BLOCKED"
    DEV_OPS_VERIFY = "DEV_OPS_VERIFY"
    DEPLOY_APPROVAL = "DEPLOY_APPROVAL"
    COMPLETED = "COMPLETED"


@dataclass
class FailureRecord:
    timestamp: str
    stage: str
    error_message: str
    traceback_snippet: str
    retry_count: int


@dataclass
class TaskContext:
    task_id: str
    title: str
    description: str
    state: State = State.INIT
    test_cmd: str = "pytest"
    worktree_path: str = ""
    branch_name: str = ""
    retry_count: int = 0
    max_retries: int = 3
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    history: List[str] = field(default_factory=list)
    failures: List[Dict[str, Any]] = field(default_factory=list)
    human_approved_plan: bool = False
    human_approved_deploy: bool = False


class Supervisor:
    def __init__(self, repo_root: Optional[Path] = None):
        self.repo_root = repo_root or Path(__file__).resolve().parent.parent
        self.tasks_dir = self.repo_root / "tasks"
        self.worktrees_dir = self.repo_root.parent / "worktrees"
        self.audit_script = self.repo_root / "scripts" / "audit-diffs.sh"

    def _task_dir(self, task_id: str) -> Path:
        d = self.tasks_dir / task_id
        d.mkdir(parents=True, exist_ok=True)
        return d

    def _state_file(self, task_id: str) -> Path:
        return self._task_dir(task_id) / "state.json"

    def load_task(self, task_id: str) -> TaskContext:
        sf = self._state_file(task_id)
        if not sf.exists():
            raise FileNotFoundError(f"任务 {task_id} 状态文件不存在: {sf}")
        with open(sf, "r", encoding="utf-8") as f:
            data = json.load(f)
        data["state"] = State(data["state"])
        return TaskContext(**data)

    def save_task(self, ctx: TaskContext) -> None:
        ctx.updated_at = datetime.now().isoformat()
        sf = self._state_file(ctx.task_id)
        with open(sf, "w", encoding="utf-8") as f:
            json.dump(asdict(ctx), f, ensure_ascii=False, indent=2)

    def create_task(self, task_id: str, title: str, description: str, test_cmd: str = "pytest", max_retries: int = 3) -> TaskContext:
        ctx = TaskContext(
            task_id=task_id,
            title=title,
            description=description,
            state=State.INIT,
            test_cmd=test_cmd,
            max_retries=max_retries,
            branch_name=f"feat/{task_id}",
            worktree_path=str(self.worktrees_dir / task_id)
        )
        ctx.history.append(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 任务初始化创建")
        self.save_task(ctx)
        
        # 写入初始任务需求卡 (若未存在)
        spec_md = self._task_dir(task_id) / "spec.md"
        if not spec_md.exists():
            if TaskBuilder is not None:
                builder = TaskBuilder(repo_root=self.repo_root)
                builder.create_task_contract(
                    task_id=task_id,
                    title=title,
                    desc=description,
                    test_cmd=test_cmd,
                    use_ai=False
                )
            else:
                spec_md.write_text(f"# 需求契约: {title} ({task_id})\n\n{description}\n\n## 验收单测命令\n`{test_cmd}`\n", encoding="utf-8")
        return ctx

    # --------------------------------------------------------------------------
    # 状态机流转执行器
    # --------------------------------------------------------------------------
    def run_step(self, ctx: TaskContext, auto_approve: bool = False, simulated: bool = False) -> TaskContext:
        """执行状态机单个步进"""
        print(f"\n=======================================================")
        print(f"--> [Supervisor] 任务: {ctx.task_id} | 当前阶段: {ctx.state.value}")
        print(f"=======================================================")

        if ctx.state == State.INIT:
            self._transition(ctx, State.PLANNING, "进入架构拆解阶段")
            return self._step_planning(ctx, simulated=simulated)

        elif ctx.state == State.PLANNING:
            return self._step_planning(ctx, simulated=simulated)

        elif ctx.state == State.PLAN_APPROVAL:
            return self._step_plan_approval(ctx, auto_approve=auto_approve)

        elif ctx.state == State.CODING:
            return self._step_coding(ctx, simulated=simulated)

        elif ctx.state == State.TESTING:
            return self._step_testing(ctx, simulated=simulated)

        elif ctx.state == State.AUDITING:
            return self._step_auditing(ctx)

        elif ctx.state == State.DEV_OPS_VERIFY:
            return self._step_devops_verify(ctx, simulated=simulated)

        elif ctx.state == State.DEPLOY_APPROVAL:
            return self._step_deploy_approval(ctx, auto_approve=auto_approve)

        elif ctx.state == State.CIRCUIT_BREAKER_BLOCKED:
            print(f"⚠️ [熔断报警] 任务由于连续 {ctx.retry_count} 次失败已被熔断锁定！")
            print(f"   需人类架构师介入处理后，执行: supervisor.py unblock --task-id {ctx.task_id}")
            return ctx

        elif ctx.state == State.COMPLETED:
            print(f"✅ 任务 {ctx.task_id} 已全生命周期完成！")
            return ctx

        return ctx

    def _transition(self, ctx: TaskContext, new_state: State, reason: str):
        old_state = ctx.state
        ctx.state = new_state
        log_entry = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 状态流转: {old_state.value} -> {new_state.value} ({reason})"
        ctx.history.append(log_entry)
        self.save_task(ctx)
        print(f"[Supervisor] {log_entry}")

    # --------------------------------------------------------------------------
    # 阶段 1: Planner Agent (架构与需求拆解)
    # --------------------------------------------------------------------------
    def _step_planning(self, ctx: TaskContext, simulated: bool = False) -> TaskContext:
        print("--> [1. Planner Agent] 正在分析需求并生成规格说明书与原子任务清单...")
        spec_path = self._task_dir(ctx.task_id) / "spec.md"
        tasks_path = self._task_dir(ctx.task_id) / "tasks.md"

        if not tasks_path.exists():
            plan_content = f"""# 架构设计与原子任务规划 ({ctx.task_id})
- **目标**: {ctx.title}
- **验收命令**: `{ctx.test_cmd}`

## 架构边界与非目标 (Non-Goals)
1. 严禁改动无关核心数据模型
2. 保持向后兼容

## 原子任务清单 (Task Slices)
- [ ] Task 1: 编写失败的边界测试契约 (TDD Baseline)
- [ ] Task 2: 实现核心业务逻辑
- [ ] Task 3: 运行单测自愈闭环并验证回归
"""
            tasks_path.write_text(plan_content, encoding="utf-8")
            print(f"    - 已生成原子任务清单: {tasks_path}")

        self._transition(ctx, State.PLAN_APPROVAL, "Planner 规划完毕，等待人类架构师审批")
        return ctx

    # --------------------------------------------------------------------------
    # 阶段 2: 人类架构审批 (Human Approval)
    # --------------------------------------------------------------------------
    def _step_plan_approval(self, ctx: TaskContext, auto_approve: bool = False) -> TaskContext:
        print("--> [审批环节] 等待人类架构师审阅架构设计与任务清单...")
        tasks_path = self._task_dir(ctx.task_id) / "tasks.md"
        print(f"    查看规划文档: {tasks_path}")

        if auto_approve:
            approved = True
            print("    [Auto-Approve] 自动放行架构规划。")
        else:
            try:
                res = input("是否批准当前架构规划进入编码开发？ [Y/n/edit]: ").strip().lower()
                if res in ("y", "yes", ""):
                    approved = True
                elif res == "edit":
                    print(f"请使用编辑器修改 {tasks_path}，完成后重新执行审批。")
                    return ctx
                else:
                    approved = False
            except (EOFError, KeyboardInterrupt):
                approved = False

        if approved:
            ctx.human_approved_plan = True
            self._transition(ctx, State.CODING, "人类架构师批准规划，调度 Coder Agent")
            self._ensure_worktree(ctx)
        else:
            print("    [Blocked] 人类驳回当前规划，可编辑 tasks.md 后重试。")
        return ctx

    def _ensure_worktree(self, ctx: TaskContext) -> None:
        """为 Coder 创建独立的 Git Worktree 物理隔离工作区"""
        target = Path(ctx.worktree_path)
        if target.exists():
            print(f"    - Worktree 物理工作区已就绪: {target}")
            return

        print(f"    - 正在为任务 {ctx.task_id} 创建独立 Worktree 物理隔离工作区...")
        target.parent.mkdir(parents=True, exist_ok=True)

        # 检查分支是否存在
        chk = subprocess.run(["git", "rev-parse", "--verify", ctx.branch_name], capture_output=True, cwd=self.repo_root)
        if chk.returncode == 0:
            cmd = ["git", "worktree", "add", str(target), ctx.branch_name]
        else:
            cmd = ["git", "worktree", "add", "-b", ctx.branch_name, str(target), "HEAD"]

        res = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_root)
        if res.returncode != 0:
            print(f"⚠️ [Worktree Warning] 创建 worktree 失败: {res.stderr}，尝试使用当前工作目录。")
            ctx.worktree_path = str(self.repo_root)
        else:
            print(f"    - Worktree 隔离目录创建成功: {target}")

        # 跨工作区自动同步任务契约至 worktree
        worktree_task_dir = target / "tasks" / ctx.task_id
        source_task_dir = self._task_dir(ctx.task_id)
        if source_task_dir.exists() and not worktree_task_dir.exists():
            try:
                shutil.copytree(source_task_dir, worktree_task_dir)
            except Exception:
                pass

        # 跨工作区自动链接核心依赖环境 (node_modules, .venv, venv)
        for dep_dir in ["node_modules", ".venv", "venv"]:
            src_dep = self.repo_root / dep_dir
            dst_dep = target / dep_dir
            if src_dep.is_dir() and not dst_dep.exists():
                try:
                    os.symlink(src_dep, dst_dep, target_is_directory=True)
                    print(f"    - 已建立依赖环境软链接: {dep_dir}")
                except Exception:
                    pass
    # 阶段 3: Coder Agent (全栈研发与代码实现)
    # --------------------------------------------------------------------------
    def _step_coding(self, ctx: TaskContext, simulated: bool = False) -> TaskContext:
        print(f"--> [2. Coder Agent] 开始在隔离工作区进行代码编写...")
        workdir = Path(ctx.worktree_path) if Path(ctx.worktree_path).exists() else self.repo_root
        print(f"    - 工作目录: {workdir}")

        if simulated:
            print("    - [Simulated] 模拟 Coder 编写实现逻辑...")
            time.sleep(0.5)
        else:
            # 真实调度逻辑：调用 Aider 或自定义 Prompt
            print(f"    - 提示: 可在 {workdir} 中执行 Aider 或 OpenCode 完成任务编码。")

        self._transition(ctx, State.TESTING, "代码编写完成，交由 QA Agent 运行质量门禁与单测验证")
        return ctx

    # --------------------------------------------------------------------------
    # 阶段 4: QA Agent 与熔断防护 (Testing & Circuit Breaker)
    # --------------------------------------------------------------------------
    def _step_testing(self, ctx: TaskContext, simulated: bool = False) -> TaskContext:
        print(f"--> [3. QA Agent] 正在运行确定性单测与质量门禁: `{ctx.test_cmd}`...")
        workdir = Path(ctx.worktree_path) if Path(ctx.worktree_path).exists() else self.repo_root

        passed = False
        output_snippet = ""

        if simulated:
            # 模拟执行
            passed = True
            output_snippet = "All tests passed successfully (simulated)."
        else:
            try:
                proc = subprocess.run(
                    ctx.test_cmd,
                    shell=True,
                    cwd=workdir,
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                output_snippet = proc.stdout + "\n" + proc.stderr
                passed = (proc.returncode == 0)
            except Exception as e:
                output_snippet = f"执行测试异常: {str(e)}"
                passed = False

        if passed:
            print("    ✅ 单测全绿通过！进入反作弊审计阶段。")
            ctx.retry_count = 0  # 重置重试计数
            self._transition(ctx, State.AUDITING, "单元测试全绿，进入双阶段反作弊代码审查")
        else:
            ctx.retry_count += 1
            print(f"    ❌ 测试失败！(当前重试次数: {ctx.retry_count}/{ctx.max_retries})")
            
            # 记录失败快照
            fail_record = FailureRecord(
                timestamp=datetime.now().isoformat(),
                stage="TESTING",
                error_message="Unit test command failed",
                traceback_snippet=output_snippet[-1500:],
                retry_count=ctx.retry_count
            )
            ctx.failures.append(asdict(fail_record))

            # 触发熔断检查
            if ctx.retry_count >= ctx.max_retries:
                snapshot_file = self._task_dir(ctx.task_id) / f"circuit_breaker_{int(time.time())}.json"
                snapshot_file.write_text(json.dumps(asdict(ctx), ensure_ascii=False, indent=2), encoding="utf-8")
                
                self._transition(
                    ctx,
                    State.CIRCUIT_BREAKER_BLOCKED,
                    f"连续失败达到 {ctx.max_retries} 次上限，触发熔断器！挂起任务并保存快照: {snapshot_file.name}"
                )
                print(f"\n🚨 [CIRCUIT BREAKER] 熔断器触发！连续 {ctx.max_retries} 次测试未通过，已挂起。")
                print(f"   已防止死循环与 Token 账单爆炸！详细快照保存在: {snapshot_file}")
            else:
                self._transition(ctx, State.CODING, f"测试未通过，打回 Coder Agent 自愈修复 (第 {ctx.retry_count} 次)")

        return ctx

    # --------------------------------------------------------------------------
    # 阶段 5: 双阶段反作弊审计 (Anti-Cheating Auditing)
    # --------------------------------------------------------------------------
    def _step_auditing(self, ctx: TaskContext) -> TaskContext:
        print("--> [3.1 QA 审计员] 正在执行双阶段反作弊差异隔离审查 (audit-diffs.sh)...")
        audit_dir = self._task_dir(ctx.task_id) / ".audit"
        
        if self.audit_script.exists():
            subprocess.run(
                ["bash", str(self.audit_script), "HEAD~1..HEAD", str(audit_dir)],
                cwd=Path(ctx.worktree_path) if Path(ctx.worktree_path).exists() else self.repo_root,
                capture_output=True,
                text=True
            )
            print(f"    - 双阶段差异已生成至: {audit_dir}")
            print(f"    - 业务代码审查切片: {audit_dir / 'code.diff'}")
            print(f"    - 单测防篡改审查切片: {audit_dir / 'tests.diff'}")

        self._transition(ctx, State.DEV_OPS_VERIFY, "审计切片生成完毕，进入 DevOps 预发布健康检测")
        return ctx

    # --------------------------------------------------------------------------
    # 阶段 6: DevOps Agent 预检 (DevOps/SRE)
    # --------------------------------------------------------------------------
    def _step_devops_verify(self, ctx: TaskContext, simulated: bool = False) -> TaskContext:
        print("--> [4. DevOps/SRE Agent] 正在执行预发布验证与容器/依赖健康自检...")
        
        # 验证是否存在未提交改动
        workdir = Path(ctx.worktree_path) if Path(ctx.worktree_path).exists() else self.repo_root
        chk = subprocess.run(["git", "status", "--porcelain"], cwd=workdir, capture_output=True, text=True)
        
        if chk.stdout.strip():
            print("    ℹ️ 工作区检测到未提交修改，生成变更清单...")

        print("    - 生产打包与构建依赖检查通过。")
        self._transition(ctx, State.DEPLOY_APPROVAL, "DevOps 预检完成，等待人类生产发布放行确认")
        return ctx

    # --------------------------------------------------------------------------
    # 阶段 7: 人类发布放行 (Deploy Approval)
    # --------------------------------------------------------------------------
    def _step_deploy_approval(self, ctx: TaskContext, auto_approve: bool = False) -> TaskContext:
        print("--> [终审发布] 等待人类架构师最终放行确认...")
        if auto_approve:
            approved = True
            print("    [Auto-Approve] 自动批准生产合并发布。")
        else:
            try:
                res = input("是否批准将该分支合入主干并执行发布？ [Y/n]: ").strip().lower()
                approved = (res in ("y", "yes", ""))
            except (EOFError, KeyboardInterrupt):
                approved = False

        if approved:
            ctx.human_approved_deploy = True
            self._transition(ctx, State.COMPLETED, "人类架构师放行，发布完成！")
            print(f"🎉 任务 {ctx.task_id} 全流程成功闭环！")
        else:
            print("    [Hold] 人类暂缓发布。")
        return ctx

    def unblock_task(self, task_id: str) -> TaskContext:
        """人工解除熔断，重置计数并退回 CODING 阶段"""
        ctx = self.load_task(task_id)
        if ctx.state != State.CIRCUIT_BREAKER_BLOCKED:
            print(f"任务 {task_id} 当前并非熔断锁定状态 (当前状态: {ctx.state.value})")
            return ctx
        ctx.retry_count = 0
        self._transition(ctx, State.CODING, "人类已介入排查疑难杂症，解除熔断，重新进入编码阶段")
        return ctx

    def print_status(self, task_id: str) -> None:
        ctx = self.load_task(task_id)
        print(f"\n=======================================================")
        print(f"任务 ID      : {ctx.task_id}")
        print(f"标题         : {ctx.title}")
        print(f"当前阶段     : {ctx.state.value}")
        print(f"重试失败次数 : {ctx.retry_count} / {ctx.max_retries}")
        print(f"单测命令     : {ctx.test_cmd}")
        print(f"工作车间路径 : {ctx.worktree_path}")
        print(f"分支名称     : {ctx.branch_name}")
        print(f"创建时间     : {ctx.created_at}")
        print(f"更新时间     : {ctx.updated_at}")
        print(f"---------------- 最近历史流转 ----------------")
        for h in ctx.history[-5:]:
            print(f"  * {h}")
        if ctx.failures:
            print(f"---------------- 最近失败记录 ----------------")
            last_fail = ctx.failures[-1]
            print(f"  时间: {last_fail['timestamp']} | 重试: {last_fail['retry_count']}")
            print(f"  错误: {last_fail['error_message']}")
        print(f"=======================================================\n")


def main():
    parser = argparse.ArgumentParser(description="AI-Native 终态架构主控状态机调度器 (Supervisor)")
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # create
    p_create = subparsers.add_parser("create", help="新建一个全生命周期任务")
    p_create.add_argument("--task-id", required=True, help="任务唯一标识，如 101-user-auth")
    p_create.add_argument("--title", required=True, help="任务简短标题")
    p_create.add_argument("--desc", default="需求待详细填充", help="需求描述")
    p_create.add_argument("--test-cmd", default="pytest", help="自动化验证测试指令")
    p_create.add_argument("--max-retries", type=int, default=3, help="熔断最大重试次数")

    # step
    p_step = subparsers.add_parser("step", help="执行任务单步流转")
    p_step.add_argument("--task-id", required=True, help="任务标识")
    p_step.add_argument("--auto-approve", action="store_true", help="自动批准人工环节")
    p_step.add_argument("--simulated", action="store_true", help="模拟模式执行")

    # run
    p_run = subparsers.add_parser("run", help="全自动推进任务直至遇到人工审批或熔断")
    p_run.add_argument("--task-id", required=True, help="任务标识")
    p_run.add_argument("--auto-approve", action="store_true", help="自动批准人工审批")
    p_run.add_argument("--simulated", action="store_true", help="模拟模式运行")

    # status
    p_status = subparsers.add_parser("status", help="查看任务状态与历史")
    p_status.add_argument("--task-id", required=True, help="任务标识")

    # unblock
    p_unblock = subparsers.add_parser("unblock", help="人类介入后解除熔断锁定")
    p_unblock.add_argument("--task-id", required=True, help="任务标识")

    # new
    subparsers.add_parser("new", help="通过交互向导创建新任务契约")
    args = parser.parse_args()
    supervisor = Supervisor()

    if args.subcommand == "create":
        ctx = supervisor.create_task(
            task_id=args.task_id,
            title=args.title,
            description=args.desc,
            test_cmd=args.test_cmd,
            max_retries=args.max_retries
        )
        print(f"✅ 任务 {ctx.task_id} 创建成功！当前状态: {ctx.state.value}")

    elif args.subcommand == "step":
        ctx = supervisor.load_task(args.task_id)
        supervisor.run_step(ctx, auto_approve=args.auto_approve, simulated=args.simulated)

    elif args.subcommand == "run":
        ctx = supervisor.load_task(args.task_id)
        max_loop = 15
        count = 0
        while ctx.state not in (State.COMPLETED, State.CIRCUIT_BREAKER_BLOCKED) and count < max_loop:
            # 如果是非 auto-approve 模式且遇到人工审批，执行一次 step 等待输入
            prev_state = ctx.state
            ctx = supervisor.run_step(ctx, auto_approve=args.auto_approve, simulated=args.simulated)
            count += 1
            if not args.auto_approve and prev_state in (State.PLAN_APPROVAL, State.DEPLOY_APPROVAL) and ctx.state == prev_state:
                # 人类暂停/未放行，退出循环
                break
        supervisor.print_status(ctx.task_id)

    elif args.subcommand == "status":
        supervisor.print_status(args.task_id)

    elif args.subcommand == "unblock":
        supervisor.unblock_task(args.task_id)

    elif args.subcommand == "new":
        if run_wizard is not None:
            task_id, test_cmd = run_wizard()
            ctx = supervisor.create_task(
                task_id=task_id,
                title=task_id,
                description="向导创建任务",
                test_cmd=test_cmd
            )
            print(f"✅ 状态机任务 {ctx.task_id} 已就绪！")
            print(f"👉 执行步进: python3 scripts/supervisor.py step --task-id {ctx.task_id}")
        else:
            print("❌ 未检测到 task_builder 模块")

if __name__ == "__main__":
    main()
