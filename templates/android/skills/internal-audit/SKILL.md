---
name: internal-audit
description: "Android 双阶段代码盲审质量防线 (Phase 1 逻辑盲审 + Phase 2 意图与测试核验)"
---

# internal-audit - Android 双阶段盲审协议

## 零、 绑定角色与权限约束
- **执行角色**: 严格遵循 `roles/independent-auditor.md`。
- **权限红线**: **绝对只读 (Strictly Read-Only)**。严禁亲自动手修代码。

## 一、 盲审流程
1. 运行 `./scripts/audit-diffs.sh <target> .audit`。
2. 阶段一：仅给审计 Agent 提供 `.audit/code.diff`，对照 `references/checklist.md` 逆向推导安全漏洞。
3. 阶段二：追加提供 `.audit/tests.diff` 与 `.audit/message.txt`，核查意图偏差与测试篡改作弊。
