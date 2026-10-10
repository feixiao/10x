# 实操：两个 Agent 并行完成一个 Go 小项目

这个练习选择一个**全新项目** `wordfreq-lab`，不用本机已有仓库，也不依赖第三方 Go 包。目标：从标准输入读取文本，按英文字母组成的单词计数，输出出现次数最多的 10 个词；次数降序，相同次数按词典序升序。输入 `Go go! AI.\n` 时，输出必须是 `go 2\nai 1\n`。空输入输出为空。

预计需要 Git、Go、已登录可用的 Pi；Claude Code 用户可在第 3 步改用 Claude。练习创建的代码由 Agent 编写，本指南只给项目契约、工具命令与验收方法。**这是流程演练，不是 AI 或多 Agent 提效实验**：人为设计的任务无法测出真实项目的净收益。

## 1. 建立干净的起点

在你希望放置练习的目录打开终端。以下命令会新建 `wordfreq-lab` 及两个并行工作目录；项目名如已存在，请先换一个新名字。

```sh
mkdir wordfreq-lab
cd wordfreq-lab
git init -b main
go mod init example.com/wordfreq
```

此时 `go.mod` 是未跟踪文件，尚无提交；若 Git 要求设置提交身份，先按你自己的身份完成 Git 配置。先完成下一步的计划，再提交起点供 worktree 使用。

## 2. 先写计划，再固定接口

在项目根目录运行 `pi`（Claude Code 用户可用 `claude --permission-mode plan`），先让它**只读规划，不改文件**。三项行为契约如下：

- **计数 Agent**：仅修改 `internal/count/`。实现 `func Count(r io.Reader) (map[string]int, error)`；只把 ASCII 字母 `[A-Za-z]` 视为单词，转为小写；其他字符都是分隔符。测试重复词、空输入与含数字的输入。
- **排序 Agent**：仅修改 `internal/render/`。实现 `func Render(counts map[string]int, limit int) string`；按次数降序、相同次数按词典序升序，每行 `词 次数\n`；`limit <= 0` 或空映射返回空字符串。测试并列、截断与空映射。
- **主 Agent**：等前两项完成并集成后，实现根目录的 `main.go`，读取标准输入，调用 `Count` 和 `Render(..., 10)`，将输出写到标准输出；读取失败时输出错误到标准错误并以非零状态退出。

把本页开头的 CLI 目标、上述三条契约和下面指令**一起粘贴**到 Pi；新项目里的 Agent 不会自动读到这份指南：

> 只读规划，不修改文件。目标是实现本指南定义的 wordfreq CLI。请按上面三个任务列出：文件归属、共享 Go 接口、依赖顺序、每个任务的单测命令、最终验收命令和失败处理。保持两个编码任务可独立执行；不要自行更改已给出的行为契约。等我确认计划后，再把计划写入 task_plan.md，把接口决策写入 findings.md，把任务和测试日志框架写入 progress.md。

检查返回的 plan 是否满足契约。确认后，让同一 Agent 写入 `task_plan.md`（阶段与待办）、`findings.md`（接口与设计决定）、`progress.md`（执行和测试结果）；这是 [planning-with-files 的三文件模式](https://github.com/OthmanAdi/planning-with-files#the-3-file-pattern)。Claude Code 使用 plan mode 时，按界面流程批准并退出只读模式后才能写文件。此练习**手动维护三文件，不需要先安装插件**；Pi 的插件路径和 `/plan-execute` 用法见 [Pi 指南](./PI_WORKFLOWS.md#可选planning-with-files-插件)。

这里为了让两个独立 worktree 读到共同契约，特意把三份初始文件一起提交；planning-with-files 插件的默认做法是把它们作为 gitignored 的工作记忆，本练习的 Git 用法是教学选择，不代表插件默认行为。检查三个文件没有秘密信息后提交基线：

```sh
git add go.mod task_plan.md findings.md progress.md
git commit -m "Plan word frequency lab"
git status --short
```

最后一条应无输出。两个并行 Agent 只读取三份文件，不同时改它们；主 Agent 在集成后更新状态和验收记录。若已安装 Pi 的 planning-with-files 插件，在主会话审阅计划后可用 `/plan-execute` 启用执行提醒；两个 worker 会话只读取冻结的契约，不共写同一份状态。

## 3. 两个 Pi 会话并行编码和单测

先在项目根目录创建独立工作目录：

```sh
git worktree add -b feat/count ../wordfreq-lab-count
git worktree add -b feat/render ../wordfreq-lab-render
```

打开**两个终端**。终端 A 进入 `../wordfreq-lab-count` 并运行 `pi`，发送：

> 按 task_plan.md 和 findings.md 执行计数任务。只修改 internal/count/。实现 Count(r io.Reader) (map[string]int, error)。单词仅由 ASCII 字母组成，统一小写，其他字符作分隔符。补测试覆盖 `Go go! AI.`、空输入和含数字输入。运行 `go test ./internal/count`，给出真实结果和 diff。不要修改三个计划文件、提交、推送或修改其他目录。

终端 B 进入 `../wordfreq-lab-render` 并运行 `pi`，发送：

> 按 task_plan.md 和 findings.md 执行排序任务。只修改 internal/render/。实现 Render(counts map[string]int, limit int) string。次数降序、并列按词典序升序，每行 `词 次数\n`；limit <= 0 或空映射返回空字符串。补测试覆盖并列、截断和空映射。运行 `go test ./internal/render`，给出真实结果和 diff。不要修改三个计划文件、提交、推送或修改其他目录。

如果使用 Claude Code，在两个 worktree 内分别运行 `claude` 并发送相同任务即可；Claude Code 的子 Agent 或 Agent Teams 并不自动替代这里的两个独立 worktree。

两边结束后，在终端 A（`wordfreq-lab-count`）运行：

```sh
go test ./internal/count
git status --short
git diff --check
```

在终端 B（`wordfreq-lab-render`）运行：

```sh
go test ./internal/render
git status --short
git diff --check
```

检查 Agent 是否改了分配范围外的文件；若失败，让对应 Agent 根据失败输出修正。确认 diff 符合第 2 步的契约后，在终端 A 运行 `git add internal/count && git commit -m "Implement word counting"`，在终端 B 运行 `git add internal/render && git commit -m "Implement result rendering"`。

## 4. 在主工作目录集成并补 CLI

返回最初的 `wordfreq-lab` 目录，依次执行：

```sh
git merge --no-ff feat/count
git merge --no-ff feat/render
go test ./...
```

合并或测试失败时先处理集成问题。通过后在主目录运行 `pi`（或 `claude`），交给主 Agent：

> 按 task_plan.md 和 findings.md 完成主任务。基于现有 internal/count 和 internal/render 接口，只新增或修改根目录的 main.go、task_plan.md、findings.md、progress.md：CLI 从标准输入读取并输出出现次数最多的 10 个词，读取失败时在标准错误输出错误并退出非零。先运行 `go test ./...`，再用 `printf 'Go go! AI.\n' | go run .` 和空输入检查行为；将已完成阶段标记在 task_plan.md，把执行命令与真实结果写入 progress.md。展示实际输出与 diff。不要修改两个 internal 包。

## 5. 独立验收和审查

在主目录的 Bash 终端运行以下命令；`set -o pipefail` 确保程序失败时管道也失败，后两条使用 Bash 的进程替换语法：

```sh
set -o pipefail
go test ./...
go vet ./...
printf 'Go go! AI.\n' | go run . | diff -u <(printf 'go 2\nai 1\n') -
printf '' | go run . | diff -u /dev/null -
git status --short
git diff --check
```

所有命令退出码为 0 才算机器检查通过；`git diff --check` 不能检查未跟踪的新文件，所以同时看 `git status --short` 和实际 diff。另开一个只读 Pi 会话审查计数、排序、错误处理和测试是否符合第 2 步的契约：

```sh
pi --no-mcp --no-extensions --tools read,grep,find,ls --print "阅读当前项目，按任务契约检查实现与测试。只报告有文件位置和触发条件的缺陷；不要修改文件。"
```

审查发现问题时让主 Agent 修复，再重跑本节检查，并在 `progress.md` 记录验收结果和未覆盖项、在 `task_plan.md` 更新完成状态。最终在主目录审完新增文件与 diff 后自行提交 `main.go` 和更新的三个计划文件；项目未配置远端，因此本练习不推送或发布。若想观察提效，记录自己用于准备、等待、审查、返工和最终验收的时间；不要只记录 Agent 生成代码的时间。
