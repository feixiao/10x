# Android 工程规范与红线约束 (android-jni-rules.md)

## 1. 架构红线 (Hard Rules)
- **主线程禁令**: 严禁在主线程执行 I/O、网络请求或耗时 Native 计算。
- **MVI 单向数据流**:
  - 必须清晰分离 `UiState` 数据契约与 `UiIntent` 事件契约。
  - Composable 函数必须为无状态纯组件，接收 `(state: UiState, onIntent: (UiIntent) -> Unit)`，禁止在 Composable 内直接调用 ViewModel 方法。
- **状态流断言必须使用 Turbine**:
  - ViewModel 的 StateFlow 演进测试必须使用 `app.cash.turbine:turbine` 严格检验每次 emit，禁止使用 `Thread.sleep` 偷懒。
- **4 状态黄金 UI 快照**:
  - 页面级变动必须编写继承自 `BaseScreenshotTest` 的用例，在 `screenshots/` 目录产出 Default、Loading、Error、DarkMode 4 张快照。
- **JNI 局部引用管理**: 循环或密集调用中必须显式调用 `env->DeleteLocalRef()`。
- **JNI 异常检查**: 调用 Java 方法后必须检查 `env->ExceptionCheck()`；C++ 异常严禁穿越 JNI 边界进入 JVM。

## 2. 必跑门禁命令
```bash
# AI 自动化质量门禁（必须通过）
./scripts/ai-verify.sh

# 备用单项命令
./gradlew testDebugUnitTest && ./gradlew detekt lintDebug
```