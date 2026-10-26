#!/usr/bin/env python3
# ==============================================================================
# tests/test_ai_native_suite.py - 方案一与方案二核心自动化测试套件
# 
# 覆盖场景:
# 1. Supervisor 状态机正常流转闭环 (INIT -> COMPLETED)
# 2. Supervisor 熔断机制 (连续 3 次失败自动挂起与快照保存、人工解除)
# 3. Biz Inspector MCP: 只读查询与多语句/高危 SQL 严格拦截
# 4. Infra DevOps MCP: 参数安全白名单与生产发布授权令牌门禁
# ==============================================================================

import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))
sys.path.insert(0, str(REPO_ROOT / "mcp_servers"))

from supervisor import Supervisor, State, TaskContext
from biz_inspector import create_biz_mcp_server, BizInspectorService
from infra_devops import create_infra_mcp_server, InfraDevOpsService


class TestSupervisorStateMachine(unittest.TestCase):
    def setUp(self):
        self.supervisor = Supervisor(repo_root=REPO_ROOT)
        self.test_task_id = "test-ci-task-001"
        self.task_dir = self.supervisor._task_dir(self.test_task_id)

    def tearDown(self):
        # 清理测试任务目录与测试 worktree
        if self.task_dir.exists():
            shutil.rmtree(self.task_dir)
        test_wt = REPO_ROOT.parent / "worktrees" / self.test_task_id
        if test_wt.exists():
            subprocess.run(["git", "worktree", "remove", "--force", str(test_wt)], cwd=REPO_ROOT, capture_output=True)
        subprocess.run(["git", "branch", "-D", f"feat/{self.test_task_id}"], cwd=REPO_ROOT, capture_output=True)

    def test_happy_path_lifecycle(self):
        """测试全流程正常闭环"""
        ctx = self.supervisor.create_task(
            task_id=self.test_task_id,
            title="测试 CI 鉴权功能",
            description="编写安全测试",
            test_cmd="true",
            max_retries=3
        )
        self.assertEqual(ctx.state, State.INIT)

        # 推进到 COMPLETED (simulated & auto_approve)
        for _ in range(10):
            if ctx.state == State.COMPLETED:
                break
            ctx = self.supervisor.run_step(ctx, auto_approve=True, simulated=True)

        self.assertEqual(ctx.state, State.COMPLETED)
        self.assertTrue(ctx.human_approved_plan)
        self.assertTrue(ctx.human_approved_deploy)

    def test_circuit_breaker_trigger(self):
        """测试连续失败 3 次触发熔断器挂起与生成快照"""
        ctx = self.supervisor.create_task(
            task_id=self.test_task_id,
            title="故意失败的任务",
            description="测试熔断器",
            test_cmd="false",  # 命令必定返回非0
            max_retries=3
        )
        # 流转到 CODING
        ctx = self.supervisor.run_step(ctx, auto_approve=True, simulated=True) # PLANNING
        ctx = self.supervisor.run_step(ctx, auto_approve=True, simulated=True) # PLAN_APPROVAL -> CODING
        self.assertEqual(ctx.state, State.CODING)

        # 循环测试：CODING -> TESTING -> CODING -> TESTING ... 直到触发熔断
        for _ in range(10):
            if ctx.state == State.CIRCUIT_BREAKER_BLOCKED:
                break
            ctx = self.supervisor.run_step(ctx, auto_approve=True, simulated=False)

        self.assertEqual(ctx.state, State.CIRCUIT_BREAKER_BLOCKED)
        self.assertEqual(ctx.retry_count, 3)

        # 检查是否生成了快照文件
        snapshots = list(self.task_dir.glob("circuit_breaker_*.json"))
        self.assertTrue(len(snapshots) > 0, "熔断快照文件未生成！")

        # 测试人工解除熔断
        unblocked_ctx = self.supervisor.unblock_task(self.test_task_id)
        self.assertEqual(unblocked_ctx.state, State.CODING)
        self.assertEqual(unblocked_ctx.retry_count, 0)


class TestMCPServers(unittest.TestCase):
    def setUp(self):
        self.biz_server = create_biz_mcp_server()
        self.infra_server = create_infra_mcp_server()

    def test_biz_readonly_sql_protection(self):
        """测试业务只读从库的防注入与防篡改能力"""
        # 1. 正常查询
        normal_res = self.biz_server.tool_handlers["query_readonly_db"]("SELECT id, username FROM users")
        self.assertTrue(normal_res["success"])
        self.assertIn("LIMIT 50", normal_res["executed_sql"])
        self.assertEqual(len(normal_res["rows"]), 2)

        # 2. 恶意 DROP TABLE 拦截
        drop_res = self.biz_server.tool_handlers["query_readonly_db"]("DROP TABLE users")
        self.assertFalse(drop_res["success"])
        self.assertIn("安全拦截", drop_res["error"])

        # 3. 堆叠多语句分号注入拦截
        stacked_res = self.biz_server.tool_handlers["query_readonly_db"]("SELECT 1; DELETE FROM users")
        self.assertFalse(stacked_res["success"])
        self.assertIn("分号", stacked_res["error"])

    def test_infra_devops_guardrails(self):
        """测试运维 MCP 的命令注入防护与生产发布令牌"""
        # 1. 命令注入拦截
        inject_res = self.infra_server.tool_handlers["fetch_container_logs"]("app; cat /etc/passwd")
        self.assertFalse(inject_res["success"])
        self.assertIn("安全拦截", inject_res["error"])

        # 2. 生产发布无令牌拦截
        no_token_res = self.infra_server.tool_handlers["trigger_deploy"]("production", "")
        self.assertFalse(no_token_res["success"])
        self.assertIn("令牌", no_token_res["error"])

        # 3. 生产发布带合法令牌放行
        valid_res = self.infra_server.tool_handlers["trigger_deploy"]("production", "CONFIRM-PROD-20261026-OK")
        self.assertTrue(valid_res["success"])
        self.assertEqual(valid_res["status"], "triggered")


if __name__ == "__main__":
    unittest.main()
