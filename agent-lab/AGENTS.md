# AGENTS.md - agent-lab 规范与统一开发契约

本文件适用于 `omp`、`pi`、`Claude Code` 以及所有主流编码 Agent。在 `agent-lab` 及其子目录开发时必须严格遵守本契约。

---

## 1. 项目概况与架构说明

`agent-lab` 包含三套独立语言实现（C++17、Go 1.22+、Python 3.10+）的费用汇总 CLI 工具（`expense-report`）。
- `starter/{cpp,go,python}`：未实现 `--category` 筛选特性的干净基准代码。
- `{cpp,go,python}`：已实现完整特性的参考实现。
- 业务契约：
  1. CLI 接口：`expense-report [--category CATEGORY] FILE`
  2. 类别过滤按 **ASCII 忽略大小写**（Case-insensitive）比较。
  3. 损坏行（格式错误、解析失败）静默跳过，保证鲁棒性。
  4. 输出格式固定：`count=<N> total=<TOTAL:0.2f>`（浮点保留两位小数）。

---

## 2. 各语言构建、测试与验收命令速查

任何修改必须在本机终端执行对应命令并产生实测证据：

### 2.1 C++ (`agent-lab/cpp`)
- **配置与编译**：
  ```sh
  cmake -S agent-lab/cpp -B agent-lab/cpp/build && cmake --build agent-lab/cpp/build
  ```
- **自动化测试**：
  ```sh
  ctest --test-dir agent-lab/cpp/build --output-on-failure
  ```
- **CLI 样例真实核对**：
  ```sh
  agent-lab/cpp/build/expense-report agent-lab/cpp/sample.txt
  # 预期输出: count=3 total=40.00
  agent-lab/cpp/build/expense-report --category food agent-lab/cpp/sample.txt
  # 预期输出: count=2 total=20.00
  ```

### 2.2 Go (`agent-lab/go`)
- **编译与单测**：
  ```sh
  (cd agent-lab/go && go test -v ./... && go build -o /tmp/expense-report-go .)
  ```
- **CLI 样例真实核对**：
  ```sh
  /tmp/expense-report-go agent-lab/go/sample.txt
  # 预期输出: count=3 total=40.00
  /tmp/expense-report-go --category food agent-lab/go/sample.txt
  # 预期输出: count=2 total=20.00
  ```

### 2.3 Python (`agent-lab/python`)
- **自动化单测**：
  ```sh
  python3 -m unittest discover -s agent-lab/python -v
  ```
- **CLI 样例真实核对**：
  ```sh
  python3 agent-lab/python/main.py agent-lab/python/sample.txt
  # 预期输出: count=3 total=40.00
  python3 agent-lab/python/main.py --category food agent-lab/python/sample.txt
  # 预期输出: count=2 total=20.00
  ```

---

## 3. 强约束工程准则 (Hard Invariants)

1. **先定位后修改 (Locate First)**：
   - 严禁盲猜文件结构。修改前必须先读取源码、现有测试文件和数据输入样例。
2. **微创修改原则 (Surgical Edits)**：
   - 严格仅修改任务相关逻辑。禁止对无关联的代码执行格式化重排，确保 git diff 干净易审查。
3. **真实性验证原则 (Real Verification / Proof of Work)**：
   - 严禁宣称“代码已写完/测试已通过”却不实际运行。交付时必须展示**真实终端输出结果**。
   - 必须通过上述对应的构建、测试与 sample 校验命令。
4. **禁止放宽断言**：
   - 修复 Bug 或测试失败时，只允许修正逻辑漏洞，严禁通过删改或放宽断言让测试虚假通过。
5. **拒绝占位符代码**：
   - 严禁提交带有 `TODO`、`pass` 空实现或伪 mock 的未完成代码。

---

## 4. 交付闭环 (Definition of Done)

所有代码变更在交付前必须在汇报中给出：
- [ ] 受影响文件列表及改动范围概述。
- [ ] 实际执行的构建与测试命令及完整终端输出。
- [ ] 使用 `sample.txt` 进行全量及指定 `--category food` 的 CLI 实测输出证据。
- [ ] `git diff` 检查确认无冗余或意外改动。
