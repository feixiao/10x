# C++ 工程规范与红线约束 (cpp-rules.md)

## 1. 架构红线 (Hard Rules)
- **标准版本**: 严格遵循当前项目指定 C++ 标准，严禁擅自使用更高版本特性破坏构建平台兼容性。
- **RAII 与内存管理**: 所有堆资源必须通过 RAII 容器或智能指针管理；**严禁裸指针（Raw Pointer）跨线程或跨异步事件传递**。
- **异常与错误码**: 明确系统错误边界。若系统约定基于错误码（Error Code），严禁向外抛出未捕获的 C++ 异常。

## 2. 必跑验证命令
```bash
cmake --build build -j && ctest --test-dir build --output-on-failure
```