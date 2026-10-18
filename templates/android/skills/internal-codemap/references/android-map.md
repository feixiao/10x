# Android 模块代码地图与动态探针 (android-map.md)

## 1. 结构探测规则
- **模块树**: 查阅根目录 `settings.gradle` 中的 `include` 列表。
- **入口组件**: 查阅 `AndroidManifest.xml` 中的主启动 Activity。
- **JNI / NDK 桥接点**: 查阅 `build.gradle` 中的 `externalNativeBuild` 或 `CMakeLists.txt`。

## 2. 动态探针命令表
```bash
# 列出所有 Gradle 项目
./gradlew projects 2>/dev/null || gradle projects
# 定位 Native 声明 (Kotlin)
git grep -n 'external fun'
# 定位 NDK 符号
git grep -n 'JNIEXPORT' -- '*.cpp' '*.c'
```