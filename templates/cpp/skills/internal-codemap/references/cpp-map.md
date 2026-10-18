# C++ 模块代码地图与动态探针 (cpp-map.md)

## 1. 结构探测规则
- **Target 依赖树**: 查阅各层级 `CMakeLists.txt` 中的 `add_library`、`add_executable` 与 `target_link_libraries`。
- **可执行主入口**: 查找包含 `int main(` 的 `.cpp` / `.cc` 实现文件。
- **公共 API 与协议**: 优先查阅 `include/` 或模块头文件目录，严禁直接跳进实现文件猜测内存布局。

## 2. 动态探针命令表
```bash
# 探查所有已声明的 CMake Target
cmake -B build -N 2>/dev/null
# 定位包含 main 的入口程序
git grep -n 'int main(' -- '*.cpp' '*.cc' '*.c'
# 检索核心头文件
git ls-files '*.h' '*.hpp'
```