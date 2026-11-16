# Level 5 Systematized Workflows 方案研究中心

> 本目录聚焦 **Level 5: 系统化工程流（Systematized Workflows）** 的通用落地方案。
> 核心原则：**工具无关（Tool-Agnostic）、渐进式落地、制度化而非口号化**。

---

## 方案索引

| 方案 | 适用对象 | 核心差异 |
| :--- | :--- | :--- |
| **[个人超级个体版 (Solo Practitioner)](./SOLO_PRACTITIONER.md)** | 独立开发者 / 1~2 人小团队 | 零基建起步、4 层渐进式、靠纪律 |
| **[团队协作版 (Team Edition)](./TEAM_EDITION.md)** | 3~30 人产研团队 | CI/CD 自动化门禁、虚拟 Key 预算管控、靠制度 |

---

## 核心差异一览

```
                  个人版                              团队版
                 ═══════                             ═══════

  防作弊        人眼扫一眼                     CI 自动切分 code.diff / tests.diff
               git diff tests/                不可绕过的机器门禁

  防死循环      Ctrl+C 掐掉                    状态机 max_retries=3 + 快照熔断
               或 50 行 Shell 脚本             CI Job 30 分钟超时

  成本控制      自律 + 本地模型                  统一网关 + 虚拟 Key + 月度预算配额
               (自己心里有数就行)               (超额自动阻断)

  工具选择      用最顺手的就行                   每人自由选择，体系层不绑定
               (omp/aider/claude 都行)         (质量全靠 CI 门禁兜底)
```

---

## 共通的"工具无关"底线

无论个人版还是团队版，以下三条铁律不变：

1. **统一输入**：任务卡 (Markdown 契约) 是给 Agent 的唯一输入规范，不依赖任何工具的私有配置格式。
2. **统一产出**：Agent 的产出是标准的 `git diff` / `git commit`，不依赖任何工具的私有输出格式。
3. **统一验收**：以确定性的测试命令（`pytest` / `npm test` / `go test` / `make test`）为验收标准，不依赖任何工具的内部判断。
