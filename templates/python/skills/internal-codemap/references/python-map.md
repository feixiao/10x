# Python 模块代码地图与动态探针 (python-map.md)

## 1. 结构探测规则
- **工程元数据**: 查阅 `pyproject.toml`、`setup.py` 或 `requirements.txt`。
- **CLI 入口**: 检索 `if __name__ == '__main__':`。
- **单测与 Fixtures**: 优先查看 `tests/conftest.py`。

## 2. 动态探针命令表
```bash
# 收集单测用例树
pytest --collect-only -q 2>/dev/null
# 定位入口文件
git grep -l "if __name__ == .__main__."
```