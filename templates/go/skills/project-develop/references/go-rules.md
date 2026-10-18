# Go 工程规范与红线约束 (go-rules.md)

## 1. 架构红线 (Hard Rules)
- **外部 I/O 解耦与 Fake 注入**: 外部依赖必须通过 `interface` 抽象，单测一律使用 Fake，严禁单测依赖外部网络环境。
- **Context 取消传播**: 核心函数第一参数必须为 `ctx context.Context`，循环或长 I/O 必须监听 `ctx.Done()`。
- **错误包装**: 统一使用 `fmt.Errorf("...: %w", err)` 保持调用链。

## 2. 必跑验证命令
```bash
go test -v -race ./... && golangci-lint run
```