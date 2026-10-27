#!/usr/bin/env python3
# ==============================================================================
# scripts/task_builder.py - AI-Native 任务契约智能构建器与交互式工作流
#
# 功能:
# 1. 一句话极速生成 (Quick Mode): 无须手动写 Markdown，自动注入三大防作弊与安全负向清单
# 2. 交互式向导构建 (Wizard Mode): 3 步命令行问答，自动探测项目测试框架 (pytest/npm/cargo/go)
# 3. AI 智能边界推导 (AI Mode): 优先借助本地 LiteLLM (:4000) 自动推导边界与验收命令，不可用时无缝降级为确定性标准模板
# ==============================================================================

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Tuple


class TaskBuilder:
    def __init__(self, repo_root: Optional[Path] = None, tenx_dir: Optional[Path] = None):
        script_dir = Path(__file__).resolve().parent
        if repo_root:
            self.repo_root = repo_root
        else:
            cur = script_dir
            found = None
            for p in [cur] + list(cur.parents):
                if (p / ".git").exists():
                    found = p
                    break
            self.repo_root = found or script_dir.parent

        if tenx_dir:
            self.tenx_dir = tenx_dir
        elif (self.repo_root / ".10x").is_dir():
            self.tenx_dir = self.repo_root / ".10x"
        elif script_dir.name in ("bin", "scripts") and script_dir.parent.name.endswith("10x"):
            self.tenx_dir = script_dir.parent
        else:
            self.tenx_dir = self.repo_root

        if (self.tenx_dir / "tasks").exists() or (self.tenx_dir != self.repo_root):
            self.tasks_dir = self.tenx_dir / "tasks"
        else:
            self.tasks_dir = self.repo_root / "tasks"

        self.tasks_dir.mkdir(parents=True, exist_ok=True)
    def detect_test_command(self) -> str:
        """自动根据仓库配置文件与目录结构嗅探测试套件命令"""
        # Python
        if (self.repo_root / "pytest.ini").exists() or (self.repo_root / "conftest.py").exists():
            return "pytest"
        if (self.repo_root / "pyproject.toml").exists():
            return "pytest"
        if (self.repo_root / "tests").is_dir():
            has_py = any((self.repo_root / "tests").glob("*.py"))
            if has_py:
                return "pytest"

        # Node / JS / TS
        pkg_json = self.repo_root / "package.json"
        if pkg_json.exists():
            try:
                data = json.loads(pkg_json.read_text(encoding="utf-8"))
                if "scripts" in data and "test" in data["scripts"]:
                    return "npm test"
            except Exception:
                pass

        # Rust
        if (self.repo_root / "Cargo.toml").exists():
            return "cargo test"

        # Go
        if (self.repo_root / "go.mod").exists():
            return "go test ./..."

        return "pytest"

    def try_ai_generate_spec(self, title: str, desc: str, test_cmd: str) -> Optional[str]:
        """尝试调用本地 LiteLLM 网关 (:4000) 自动推导架构边界与细化契约"""
        gateway_url = "http://127.0.0.1:4000/v1/chat/completions"
        api_key = os.environ.get("OPENAI_API_KEY", "sk-1d307c0eb1dc6106851fe89bd3aff3534757d4aa0d9fcc954b89461fe8e507a5")
        system_prompt = (
            "你是一位资深系统架构师。请根据用户的一句话需求，细化为一份严谨的 Task 任务契约。\n"
            "必须包含四个核心小节：\n"
            "1. ## 1. 业务功能目标 (明确验收范围)\n"
            "2. ## 2. 负向边界与严禁触碰 (Explicit Non-Goals，列出不少于3条绝对严禁改动的非相关逻辑或底线)\n"
            "3. ## 3. 确定性验收单测命令 (Acceptance Commands)\n"
            "4. ## 4. 改动行数预算 (Diff Budget，默认不超过 150 行)\n"
            "直接输出 Markdown 契约正文，不要有任何无关前后缀或闲聊。"
        )
        user_prompt = f"需求标题: {title}\n需求补充说明: {desc}\n推荐单测命令: {test_cmd}"

        payload = {
            "model": "architect-model",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "max_tokens": 1500,
            "temperature": 0.2
        }

        try:
            req = urllib.request.Request(
                gateway_url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=8.0) as resp:
                if resp.status == 200:
                    result = json.loads(resp.read().decode("utf-8"))
                    choices = result.get("choices", [])
                    if choices:
                        return choices[0]["message"]["content"].strip()
        except Exception:
            # 任何网络/超时异常直接降级
            return None

        return None

    def plan_epic(self, title: str, desc: str = "") -> str:
        """针对大需求执行多切片架构拆解 (Epic Slicing)"""
        detected_test = self.detect_test_command()
        cli_prefix = "./.10x/10x" if (self.repo_root / ".10x").is_dir() else "./scripts/solo-worktree.sh"

        print(f"\n=======================================================")
        print(f"🎯 AI 架构师正在分析并拆解大需求: {title}")
        print(f"   (使用本地 architect-model 顶层重推理进行切片规划...)")
        print(f"=======================================================\n")

        gateway_url = "http://127.0.0.1:4000/v1/chat/completions"
        api_key = os.environ.get("OPENAI_API_KEY", "sk-1d307c0eb1dc6106851fe89bd3aff3534757d4aa0d9fcc954b89461fe8e507a5")
        system_prompt = (
            "你是一位资深系统架构总监。用户提出了一个较庞大的软件功能大需求（Epic）。\n"
            "在 AI-Native 与 TDD 规范下，严禁一次性堆叠海量代码，必须将大需求拆解为 2~4 个由浅入深、单个改动 <= 150 行、具备确定性单测验证的独立原子切片 (Task Slices)。\n"
            f"当前工程自动化单测框架为: `{detected_test}`，统一执行入口命令前缀为: `{cli_prefix}`。\n"
            "请直接输出 Markdown 格式的拆解规划，结构必须清晰规范：\n"
            "## 1. 架构拆解思路\n(简述分几步走，各切片依赖关系)\n\n"
            "## 2. 原子任务切片清单 (Task Slices)\n"
            "### 切片 1: <建议task-id，如 101-pay-core> - <切片标题>\n"
            "- **核心目标**: ...\n"
            "- **预期新增/改动文件**: ...\n"
            "- **验收单测命令**: `<单测命令>`\n"
            f"- **一键启动命令**: `{cli_prefix} quick <task-id> \"<简短需求>\" \"<单测命令>\"`\n\n"
            "### 切片 2: ...\n\n"
            "## 3. 推荐交付顺序与操作建议\n"
            "说明先跑哪一个车间、合入主干后再拉起下一个车间。"
        )
        user_prompt = f"大需求标题: {title}\n补充说明: {desc}"
        payload = {
            "model": "architect-model",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "max_tokens": 2048,
            "temperature": 0.2
        }

        content = None
        try:
            req = urllib.request.Request(
                gateway_url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=20.0) as resp:
                if resp.status == 200:
                    result = json.loads(resp.read().decode("utf-8"))
                    choices = result.get("choices", [])
                    if choices:
                        content = choices[0]["message"]["content"].strip()
        except Exception:
            pass

        if not content:
            content = f"""## 1. 架构拆解思路
大需求 `{title}` 建议拆解为 3 个原子切片，分层递进实现：
1. **地基切片**：数据模型、网关抽象接口与状态机（纯 Mock 单元测试）；
2. **渠道适配切片**：微信支付与支付宝具体通道实现；
3. **API 接入切片**：对外 Web 路由端点与异步通知 WebHook。

## 2. 原子任务切片清单 (Task Slices)
### 切片 1: 101-payment-core - 支付核心模型与网关接口
- **核心目标**: 定义统一订单状态机与支付抽象网关接口
- **验收单测命令**: `{detected_test} tests/test_payment_core.py`
- **一键启动命令**: `{cli_prefix} quick 101-payment-core "实现统一支付抽象网关接口与状态机" "{detected_test} tests/test_payment_core.py"`

### 切片 2: 102-payment-channels - 微信支付与支付宝通道适配
- **核心目标**: 实现微信与支付宝的具体加签、验签与下单
- **验收单测命令**: `{detected_test} tests/test_payment_channels.py`
- **一键启动命令**: `{cli_prefix} quick 102-payment-channels "实现微信与支付宝通道适配与验签" "{detected_test} tests/test_payment_channels.py"`

### 切片 3: 103-payment-api - Web API 路由与回调通知端点
- **核心目标**: 暴露下单接口与异步回调通知验签入口
- **验收单测命令**: `{detected_test} tests/test_payment_api.py`
- **一键启动命令**: `{cli_prefix} quick 103-payment-api "暴露支付创建与回调API端点" "{detected_test} tests/test_payment_api.py"`

## 3. 推荐交付顺序与操作建议
从**切片 1**开始启动车间，测试通过并通过 `audit` 后合入主干，再依次推进后续切片。
"""

        print(content)
        plan_file = self.tasks_dir / f"plan-{datetime.now().strftime('%m%d-%H%M')}.md"
        plan_file.write_text(content, encoding="utf-8")
        print(f"\n=======================================================")
        print(f"📄 架构拆解规划已落盘保存至: {plan_file}")
        print(f"👉 复制上述切片 1 的启动命令即可立刻开始第一阶段！")
        print(f"=======================================================\n")
        return content

    def build_deterministic_spec(
        self,
        task_id: str,
        title: str,
        desc: str = "",
        test_cmd: str = "pytest",
        diff_budget: int = 150,
        extra_non_goals: Optional[list] = None
    ) -> str:
        """生成确定性标准安全任务契约"""
        cli_prefix = "./.10x/10x" if (self.repo_root / ".10x").is_dir() else "./scripts/solo-worktree.sh"
        sup_prefix = "./.10x/10x supervisor" if (self.repo_root / ".10x").is_dir() else "python3 scripts/supervisor.py"
        desc_text = desc.strip() if desc.strip() else f"实现 {title} 核心功能并通过测试。"
        non_goals = [
            "❌ 严禁破坏既有数据库表结构与现有模型定义；",
            "❌ 严禁删除、注释或放宽测试用例中现存的断言基线；",
            "❌ 严禁擅自引入重型或未经授权的三方外部依赖包；",
        ]
        if extra_non_goals:
            non_goals.extend(extra_non_goals)

        non_goals_str = "\n".join(f"- {ng}" if not ng.startswith("-") else ng for ng in non_goals)

        content = f"""# 任务契约规范卡: {task_id}

- **Task ID**: `{task_id}`
- **Feature Name**: `{title}`
- **Created At**: `{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}`
- **Owner**: `人类架构师 (Human Architect)`
- **Status**: `PENDING`

---

## 1. 业务目标与需求说明
{desc_text}

---

## 2. 负向边界与严禁触碰清单 (Explicit Non-Goals)
> 明确规定 Agent 绝对严禁违背的系统红线与范围约束：
{non_goals_str}

---

## 3. 确定性自动化验收命令 (Acceptance Commands)
```bash
{test_cmd}
```

---

## 4. 改动行数预算 (Diff Budget)
- **最大总行数限制**: `<= {diff_budget} 行` (新增与修改合计)
- **审查机制**: 单测通过后必须经 `audit-diffs.sh` 物理切分纯业务代码与单测断言。

---

## 5. 快速启动车间
```bash
# 启动工作车间:
{cli_prefix} start {task_id} "{test_cmd}"

# 状态机全生命周期调度:
{sup_prefix} create --task-id {task_id} --title "{title}" --test-cmd "{test_cmd}"
```
"""
        return content

    def create_task_contract(
        self,
        task_id: str,
        title: str,
        desc: str = "",
        test_cmd: Optional[str] = None,
        use_ai: bool = True,
        diff_budget: int = 150
    ) -> Path:
        """主构建入口：创建任务卡并落盘"""
        # 1. 自动探测测试命令
        final_test_cmd = test_cmd or self.detect_test_command()

        # 2. 优先尝试 AI 扩写
        spec_content = None
        if use_ai:
            print(f"--> [task-builder] 正在尝试调用本地模型智能推导架构契约与边界...")
            ai_content = self.try_ai_generate_spec(title, desc, final_test_cmd)
            if ai_content:
                print(f"✅ AI 智能边界推导成功！")
                spec_content = f"""# 任务契约规范卡: {task_id}

- **Task ID**: `{task_id}`
- **Feature Name**: `{title}`
- **Generated By**: `AI Planner (LiteLLM)`
- **Created At**: `{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}`

---

{ai_content}

---

## 5. 快速启动车间
```bash
{"./.10x/10x" if (self.repo_root / ".10x").is_dir() else "./scripts/solo-worktree.sh"} start {task_id} "{final_test_cmd}"
```
"""

        # 3. 若 AI 未开启或降级，使用标准确定性模板
        if not spec_content:
            spec_content = self.build_deterministic_spec(
                task_id=task_id,
                title=title,
                desc=desc,
                test_cmd=final_test_cmd,
                diff_budget=diff_budget
            )

        # 4. 写入根目录 tasks/<task-id>.md 与 tasks/<task-id>/spec.md
        primary_file = self.tasks_dir / f"{task_id}.md"
        primary_file.write_text(spec_content, encoding="utf-8")

        sub_dir = self.tasks_dir / task_id
        sub_dir.mkdir(parents=True, exist_ok=True)
        (sub_dir / "spec.md").write_text(spec_content, encoding="utf-8")

        return primary_file


def run_wizard():
    """交互式 3 步快速向导工作流"""
    builder = TaskBuilder()
    detected_test = builder.detect_test_command()

    print("\n=======================================================")
    print("🚀 AI-Native 任务契约智能构建向导 (Task Wizard)")
    print("=======================================================")

    # 1. 任务 ID
    default_id = f"task-{datetime.now().strftime('%m%d-%H%M')}"
    raw_id = input(f"1. 任务 ID [默认: {default_id}]: ").strip()
    task_id = raw_id if raw_id else default_id

    # 2. 一句话需求
    title = input("2. 一句话需求标题 (如: 实现ETF溢价率超阈值告警): ").strip()
    if not title:
        title = "未命名特性"

    desc = input("   需求补充说明 (可选，直接回车跳过): ").strip()

    # 3. 验收单测命令
    raw_cmd = input(f"3. 自动化验收单测命令 [回车默认: {detected_test}]: ").strip()
    test_cmd = raw_cmd if raw_cmd else detected_test

    # 4. 是否尝试 AI 自动推导
    raw_ai = input("4. 是否启用本地 AI 自动推导边界与契约? [Y/n]: ").strip().lower()
    use_ai = raw_ai not in ("n", "no")

    print("\n正在生成任务规范契约...")
    path = builder.create_task_contract(
        task_id=task_id,
        title=title,
        desc=desc,
        test_cmd=test_cmd,
        use_ai=use_ai
    )

    print(f"\n🎉 契约卡生成成功: {path}")
    print(f"👉 立即启动工作车间: ./scripts/solo-worktree.sh start {task_id} \"{test_cmd}\"")
    return task_id, test_cmd


def main():
    parser = argparse.ArgumentParser(description="AI-Native 任务契约智能构建器")
    subparsers = parser.add_subparsers(dest="command")

    # quick
    p_quick = subparsers.add_parser("quick", help="一句话极速创建契约卡")
    p_quick.add_argument("task_id", help="任务 ID，如 101-demo")
    p_quick.add_argument("title", help="一句话需求描述")
    p_quick.add_argument("test_cmd", nargs="?", default="", help="可选的单测命令，未指定时自动嗅探")
    p_quick.add_argument("--no-ai", action="store_true", help="跳过 AI 智能推导，强制使用静态确定性模板")
    # plan
    p_plan = subparsers.add_parser("plan", help="宏观大需求智能切片架构规划 (Epic Slicing)")
    p_plan.add_argument("title", help="宏观大需求描述，如: '对接支付功能 微信支付和支付宝就好'")
    p_plan.add_argument("desc", nargs="?", default="", help="需求补充说明")

    # wizard
    subparsers.add_parser("wizard", help="进入交互式问答向导")

    args = parser.parse_args()
    builder = TaskBuilder()

    if args.command == "plan":
        builder.plan_epic(args.title, args.desc)
        return
    args = parser.parse_args()
    builder = TaskBuilder()

    if args.command == "quick":
        test_cmd = args.test_cmd if args.test_cmd else builder.detect_test_command()
        use_ai = not args.no_ai
        out_path = builder.create_task_contract(
            task_id=args.task_id,
            title=args.title,
            test_cmd=test_cmd,
            use_ai=use_ai
        )
        print(f"✅ 任务契约生成完毕: {out_path}")
        print(f"   单测命令: `{test_cmd}`")

    elif args.command == "wizard" or args.command is None:
        if sys.stdin.isatty():
            run_wizard()
        else:
            parser.print_help()


if __name__ == "__main__":
    main()
