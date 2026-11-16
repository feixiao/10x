#!/usr/bin/env python3
"""
Agent Driver SPI: 工具无关单兵自治驱动标准参考实现
展示如何将 Aider、omp (Oh My Pi) 及原生简易 ReAct 引擎封装为统一的无状态无头驱动。
"""

import os
import sys
import subprocess
import shutil
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, Any, Optional

@dataclass
class AgentResult:
    """标准化单兵执行产物"""
    task_id: str
    driver_name: str
    status: str             # "SUCCESS" | "FAILED" | "TIMEOUT" | "TOOL_NOT_FOUND"
    exit_code: int
    git_diff: str
    stderr_summary: str
    token_usage: Dict[str, Any] = field(default_factory=dict)

class BaseAgentDriver(ABC):
    """单兵 Agent 统一驱动抽象基类"""

    def __init__(self, workspace_path: str, gateway_url: str = "http://localhost:4000"):
        self.workspace_path = os.path.abspath(workspace_path)
        self.gateway_url = gateway_url

    @abstractmethod
    def get_driver_name(self) -> str:
        """驱动器标识名称"""
        pass

    @abstractmethod
    def health_check(self) -> bool:
        """检查底层 CLI 工具或依赖是否存在"""
        pass

    @abstractmethod
    def execute(
        self,
        task_id: str,
        spec_content: str,
        test_cmd: str,
        timeout_seconds: int = 300
    ) -> AgentResult:
        """以无头 (Headless) 模式执行单兵闭环任务"""
        pass

    def collect_git_diff(self) -> str:
        """收集当前工作区的代码改动"""
        try:
            res = subprocess.run(
                ["git", "diff", "HEAD"],
                cwd=self.workspace_path,
                capture_output=True,
                text=True,
                timeout=10
            )
            return res.stdout
        except Exception as e:
            return f"Error collecting diff: {e}"

    def sanitize_stderr(self, raw_stderr: str, max_chars: int = 2000) -> str:
        """提纯过滤错误日志，截断超长堆栈，阻断上下文污染"""
        if not raw_stderr:
            return ""
        lines = [line for line in raw_stderr.splitlines() if line.strip()]
        # 仅保留关键倒序堆栈
        tail_lines = lines[-30:] if len(lines) > 30 else lines
        result = "\n".join(tail_lines)
        return result[-max_chars:] if len(result) > max_chars else result


class AiderDriver(BaseAgentDriver):
    """Aider 驱动器实现：通过非交互式参数驱动"""

    def get_driver_name(self) -> str:
        return "aider"

    def health_check(self) -> bool:
        return shutil.which("aider") is not None

    def execute(
        self,
        task_id: str,
        spec_content: str,
        test_cmd: str,
        timeout_seconds: int = 300
    ) -> AgentResult:
        if not self.health_check():
            return AgentResult(
                task_id=task_id,
                driver_name=self.get_driver_name(),
                status="TOOL_NOT_FOUND",
                exit_code=-1,
                git_diff="",
                stderr_summary="Aider CLI is not installed or not in PATH."
            )

        prompt = f"TASK SPECIFICATION:\n{spec_content}\n\nPlease implement the requirements and ensure tests pass."
        cmd = [
            "aider",
            "--yes",
            "--no-git",
            "--no-auto-commits",
            f"--test-cmd={test_cmd}",
            "--auto-test",
            "--message", prompt
        ]

        env = os.environ.copy()
        env["OPENAI_API_BASE"] = f"{self.gateway_url}/v1"

        try:
            process = subprocess.run(
                cmd,
                cwd=self.workspace_path,
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
                env=env
            )
            diff = self.collect_git_diff()
            status = "SUCCESS" if process.returncode == 0 else "FAILED"
            return AgentResult(
                task_id=task_id,
                driver_name=self.get_driver_name(),
                status=status,
                exit_code=process.returncode,
                git_diff=diff,
                stderr_summary=self.sanitize_stderr(process.stderr)
            )
        except subprocess.TimeoutExpired:
            return AgentResult(
                task_id=task_id,
                driver_name=self.get_driver_name(),
                status="TIMEOUT",
                exit_code=-1,
                git_diff=self.collect_git_diff(),
                stderr_summary=f"Task timed out after {timeout_seconds}s"
            )


class OmpDriver(BaseAgentDriver):
    """Oh My Pi (omp) 驱动器实现：通过无头/非交互配置驱动"""

    def get_driver_name(self) -> str:
        return "omp"

    def health_check(self) -> bool:
        return shutil.which("omp") is not None

    def execute(
        self,
        task_id: str,
        spec_content: str,
        test_cmd: str,
        timeout_seconds: int = 300
    ) -> AgentResult:
        if not self.health_check():
            return AgentResult(
                task_id=task_id,
                driver_name=self.get_driver_name(),
                status="TOOL_NOT_FOUND",
                exit_code=-1,
                git_diff="",
                stderr_summary="omp CLI is not installed or not in PATH."
            )

        # 针对 omp 封装非交互式命令行参数 (利用 -p/--print 模式与 --no-session)
        cmd = [
            "omp",
            "-p",                          # Non-interactive mode (print and exit)
            "--mode=text",                 # 纯文本流输出，避免 ANSI 转义污染
            "--no-session",                # 保持无状态 (ephemeral)
            "--no-pty",                    # 禁用交互式伪终端
            f"TASK SPEC:\n{spec_content}\n\nTEST COMMAND: {test_cmd}"
        ]

        env = os.environ.copy()
        env["OPENAI_BASE_URL"] = f"{self.gateway_url}/v1"

        try:
            process = subprocess.run(
                cmd,
                cwd=self.workspace_path,
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
                env=env
            )
            diff = self.collect_git_diff()
            status = "SUCCESS" if process.returncode == 0 else "FAILED"
            return AgentResult(
                task_id=task_id,
                driver_name=self.get_driver_name(),
                status=status,
                exit_code=process.returncode,
                git_diff=diff,
                stderr_summary=self.sanitize_stderr(process.stderr)
            )
        except subprocess.TimeoutExpired:
            return AgentResult(
                task_id=task_id,
                driver_name=self.get_driver_name(),
                status="TIMEOUT",
                exit_code=-1,
                git_diff=self.collect_git_diff(),
                stderr_summary=f"Task timed out after {timeout_seconds}s"
            )


class NativePythonDriver(BaseAgentDriver):
    """轻量原生 Python 驱动：零外部第三方 CLI 依赖的自闭环 ReAct 实现范式"""

    def get_driver_name(self) -> str:
        return "native-python"

    def health_check(self) -> bool:
        return True  # 内置原生支持

    def execute(
        self,
        task_id: str,
        spec_content: str,
        test_cmd: str,
        timeout_seconds: int = 300
    ) -> AgentResult:
        """
        示例性模拟极简原生自愈逻辑：
        1. 读取 spec
        2. 运行单测捕获报错
        3. 调用 Gateway 模型生成修改补丁并落盘
        4. 重跑单测验证
        """
        # 此处展示驱动层如何自主完成无工具绑定的轻量闭环
        diff = self.collect_git_diff()
        return AgentResult(
            task_id=task_id,
            driver_name=self.get_driver_name(),
            status="SUCCESS",
            exit_code=0,
            git_diff=diff,
            stderr_summary="",
            token_usage={"prompt_tokens": 1200, "completion_tokens": 150, "cost_usd": 0.002}
        )


class AgentDriverFactory:
    """驱动器工厂：根据配置秒级热切换底层引擎"""

    DRIVERS = {
        "aider": AiderDriver,
        "omp": OmpDriver,
        "native": NativePythonDriver,
    }

    @classmethod
    def create(cls, driver_name: str, workspace_path: str, gateway_url: str = "http://localhost:4000") -> BaseAgentDriver:
        driver_cls = cls.DRIVERS.get(driver_name.lower())
        if not driver_cls:
            raise ValueError(f"Unknown driver: {driver_name}. Available: {list(cls.DRIVERS.keys())}")
        return driver_cls(workspace_path=workspace_path, gateway_url=gateway_url)


if __name__ == "__main__":
    print("=== Agent Driver SPI Standard Check ===")
    factory = AgentDriverFactory()
    for name in ["aider", "omp", "native"]:
        driver = factory.create(name, workspace_path=".")
        is_ready = driver.health_check()
        print(f"Driver [{name:6s}]: {'[AVAILABLE]' if is_ready else '[NOT INSTALLED]'}")
