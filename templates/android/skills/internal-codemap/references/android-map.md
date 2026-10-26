# Android 模块代码地图与动态探针 (android-map.md)

## 1. 结构探测规则

### A. 上层业务与 UI 层
- **模块依赖树**: 查阅根目录 `settings.gradle` / `settings.gradle.kts` 中的 `include` 列表。
- **主入口组件**: 查阅 `AndroidManifest.xml` 中的主启动 Activity / Application。
- **Compose 页面组件**: 查找声明 `UiState` / `UiIntent` / `@Composable fun XxxContent` 的源码文件。

### B. C++ / NDK 原生层
- **Native 构建配置**: 查阅各模块 `build.gradle(.kts)` 中的 `externalNativeBuild { cmake { ... } }` 或 `ndkBuild`。
- **CMake Target 依赖树**: 查阅 `CMakeLists.txt` 中的 `add_library`、`target_link_libraries` 与 `add_subdirectory`。
- **JNI 桥接入口**:
  - Kotlin/Java 端：查找 `external fun` 或 `native` 方法及 `System.loadLibrary`。
  - C++ 端：查找包含 `JNIEXPORT`、`JNICALL` 或 `RegisterNatives` 的实现文件。
- **原生单测配置**: 查找 host 端 CMakeLists 或包含 `#include <gtest/gtest.h>` 的测试目标。

---

## 2. 动态探针命令表
```bash
# 1. Gradle 模块探测
./gradlew projects 2>/dev/null || gradle projects

# 2. 定位 Native 声明 (Kotlin/Java)
git grep -n 'external fun' -- '*.kt'
git grep -n 'native ' -- '*.java'

# 3. 定位 JNI 导出与动态注册符号 (C/C++)
git grep -n 'JNIEXPORT' -- '*.cpp' '*.c' '*.cc'
git grep -n 'RegisterNatives' -- '*.cpp' '*.c' '*.cc'

# 4. 定位 CMakeLists 与原生源文件
git ls-files '**/CMakeLists.txt' 'CMakeLists.txt'
git ls-files '*.cpp' '*.cc' '*.c' '*.h' '*.hpp'

# 5. 探查当前 Native Target (若配置了本地 CMake)
cmake -B build_native -N 2>/dev/null || true

# 6. 查找 C++ 单元测试文件
git grep -l '#include <gtest/' -- '*.cpp' '*.cc' 2>/dev/null || true
```