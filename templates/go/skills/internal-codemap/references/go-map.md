# Go 模块代码地图与动态探针 (go-map.md)

## 1. 结构探测规则
- **模块声明**: 查阅 `go.mod` 明确 module 名称与依赖版本。
- **服务启动点**: 检索 `package main` 所在的入口目录（通常为 `cmd/` 或根目录）。
- **核心接口**: 优先查阅定义核心业务行为的 `interface`。

## 2. 动态探针命令表
```bash
# 快速列出工程内所有包路径
go list ./... 2>/dev/null
# 定位 main 入口
git grep -l 'package main'
# 检索接口定义
git grep -n 'type .* interface {'
```