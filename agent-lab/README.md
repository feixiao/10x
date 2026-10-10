# C++ / Go / Python 编码 Agent 动手实验

三个语言项目都实现同一款费用汇总 CLI；未实现筛选功能的干净起点保存在 `starter/{cpp,go,python}`，已完成的 Agent 结果放在对应语言目录。练习任务是新增可选 `--category CATEGORY` 参数，类别按 ASCII 忽略大小写匹配，并保持原有输出与坏行忽略行为。所有目录都由主仓库统一跟踪。

这是一次流程演练，不是提效基准：三个项目由同一个 Codex CLI（本机版本 0.161.0、同一模型配置）分别完成。跨语言差异同时包含语言、测试框架和构建方式，不能据此归因为语言或 Agent 本身。

## 运行当前版本

在仓库根目录执行：

```sh
cmake -S agent-lab/cpp -B agent-lab/cpp/build
cmake --build agent-lab/cpp/build
ctest --test-dir agent-lab/cpp/build --output-on-failure
agent-lab/cpp/build/expense-report agent-lab/cpp/sample.txt
agent-lab/cpp/build/expense-report --category food agent-lab/cpp/sample.txt

(cd agent-lab/go && go test ./... && go build -o /tmp/expense-report-go .)
/tmp/expense-report-go agent-lab/go/sample.txt
/tmp/expense-report-go --category food agent-lab/go/sample.txt

(cd agent-lab/python && python3 -m unittest discover -v)
python3 agent-lab/python/main.py agent-lab/python/sample.txt
python3 agent-lab/python/main.py --category food agent-lab/python/sample.txt
```

预期输出分别是未筛选 `count=3 total=40.00`、food 筛选 `count=2 total=20.00`。测试还覆盖大写 `TRAVEL` 和不存在的类别。

## 本机这轮运行结果

本机使用 Codex CLI 0.161.0（同一会话模型配置）分别实现了筛选功能。之后独立重跑检查：C++ `ctest` 1/1 通过；Go `go test ./...` 通过；Python 4 项 `unittest` 通过。三种 CLI 在未筛选、`food`、大写 `TRAVEL`、未知类别四种输入下都分别输出 `3/40.00`、`2/20.00`、`1/20.00`、`0/0.00`。

这次没有可靠记录人工审查、等待和返工的总耗时，因此结果只说明三个实现通过了约定行为，不用于推算提效。Go 构建在 Agent sandbox 中遇到默认缓存目录权限问题，指定临时 `GOCACHE` 后构建通过；在普通终端复现时如未遇到权限问题，不需要该设置。审查还发现 C++ 初版用了受 locale 影响的 `std::tolower`，与“ASCII 大小写”契约不够精确，改为显式 ASCII 字符转换后重跑了构建和测试。这类契约核对是人工审查的实际价值之一。

## 用 Agent 重做

每个项目的 `README.md` 包含功能约定和本地验证命令。在对应语言目录启动你想比较的 Agent，粘贴下面任务；只替换结尾的项目命令即可：

```text
先阅读项目说明、源代码和现有测试，再实现 expense-report [--category CATEGORY] FILE。
类别比较按 ASCII 忽略大小写；未指定类别时保持当前汇总；继续忽略坏行并保持输出格式。
补测试：food -> count=2,total=20.00；TRAVEL -> count=1,total=20.00；未知类别 -> count=0,total=0.00；保留未筛选测试。
只改实现和测试文件。先说明将改哪些文件，再实施。运行项目说明中的构建和测试命令，以及未筛选和 food 两种 CLI 检查；报告实际命令、结果、diff 和未覆盖项。
```

验证当前结果后再试其他 Agent。每轮从干净 baseline 开始：将对应的 starter 目录复制到临时工作区，例如 `cp -R agent-lab/starter/cpp /tmp/expense-cpp-trial`，然后在副本中启动 Agent。不要在唯一工作副本上执行会丢弃未提交改动的重置命令。

## 记录表

| 语言 | 任务总耗时 | 首次测试通过 | 人工修改 / 返工 | 最终检查 | 主要问题 |
| --- | --- | --- | --- | --- | --- |
| C++ |  |  |  |  |  |
| Go |  |  |  |  |  |
| Python |  |  |  |  |  |

计时包含读仓库、下指令、等候、审 diff、修复和最终验收。若比较 Agent，把同一个项目 baseline 和任务在隔离副本中交给各 Agent；记录 Agent、模型、版本、权限、上下文和费用。一次三语言练习只能暴露工作流问题，不能证明谁更快或更好。
