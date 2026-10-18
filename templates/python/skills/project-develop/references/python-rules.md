# Python 工程规范与红线约束 (python-rules.md)

## 1. 架构红线 (Hard Rules)
- **类型提示 (Type Hints)**: 所有公共模块函数与类方法必须标注完整的 Type Hints。
- **严禁裸 `except:`**: 严禁使用裸 `except:` 或仅 `pass` 吞掉异常。
- **跨平台路径与句柄**: 统一使用 `pathlib.Path`；文件与子进程必须使用 `with` 语句管理生命周期。

## 2. 必跑验证命令
```bash
ruff check . && mypy . && pytest -q
```