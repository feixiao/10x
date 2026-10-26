# Android 工程规范与红线约束 (android-rules.md)

## 1. 关注点模式说明 (Focus Modes)
本项目支持多栈动态关注点切换，根据任务目标隔离或聚合门禁：
- **UI 模式 (`ui`)**: 关注 Compose/View 界面、ViewModel 状态机与 UI 视觉快照。
- **Native 模式 (`native`)**: 关注 C++/NDK 逻辑、算法、RAII 内存安全与 JNI 边界规范。
- **全栈/桥接模式 (`dual`)**: 同时覆盖 Native 与 UI 全量验证。
- **自动嗅探 (`auto`)**: 门禁脚本根据变更文件类型（`.cpp/.h` vs `.kt/.java`）自动选择门禁分支。

---

## 2. 架构红线 (Hard Rules)

### A. Kotlin / Compose 界面层红线
- **主线程禁令**: 严禁在主线程执行 I/O、网络请求或耗时 Native 计算（超过 5ms 必须切至 Dispatchers.Default / IO）。
- **MVI 单向数据流**:
  - 必须清晰分离 `UiState` 数据契约与 `UiIntent` 事件契约。
  - Composable 函数必须为无状态纯组件，接收 `(state: UiState, onIntent: (UiIntent) -> Unit)`，禁止在 Composable 内直接调用 ViewModel 方法。
- **状态流断言必须使用 Turbine**:
  - ViewModel 的 StateFlow 演进测试必须使用 `app.cash.turbine:turbine` 严格检验每次 emit，禁止使用 `Thread.sleep` 偷懒。
- **4 状态黄金 UI 快照**:
  - 页面级变动必须编写继承自 `BaseScreenshotTest` 的用例，在 `screenshots/` 目录产出 Default、Loading、Error、DarkMode 4 张快照。

### B. C++ / NDK / JNI 原生层红线
- **RAII 与内存安全**:
  - 所有堆资源必须通过 RAII 容器或智能指针（`std::unique_ptr` / `std::shared_ptr`）管理。
  - **严禁裸指针（Raw Pointer）跨线程或跨异步事件传递**，防范悬垂指针与 Use-After-Free。
- **JNIEnv 线程绑定约束**:
  - `JNIEnv*` 绝对与当前线程绑定，**严禁跨线程缓存或传递 `JNIEnv*`**。
  - 后台 C++ 线程调用 Java 时，必须通过 `JavaVM->AttachCurrentThread` 获取专属 Env，退出前必须 `DetachCurrentThread`。
- **JNI 局部引用管理 (LocalRef)**:
  - JVM 局部引用表默认上限仅 512。循环体或高频 JNI 调用中创建的局部引用必须显式调用 `env->DeleteLocalRef()` 释放，防范表溢出崩溃。
- **JNI 异常屏障与异常隔离**:
  - 调用 Java/Kotlin 方法后必须显式调用 `env->ExceptionCheck()`，若有异常必须调用 `env->ExceptionClear()` 或安全返回。
  - **C++ 异常严禁穿越 JNI 边界进入 JVM**：所有 JNIEXPORT 函数必须用 `try { ... } catch (...)` 包裹，转译为合法错误码或 Java 异常抛出。
- **ASan 与测试保障**:
  - 原生 C++ 模块修改必须配套单元测试（GTest 或 CTest），并通过 AddressSanitizer (ASan) 验证无内存泄漏和越界访问。

---

## 3. 门禁验证命令
```bash
# 1. 自动嗅探（推荐：根据当前改动自动选择 UI / Native / Dual 门禁）
./scripts/ai-verify.sh

# 2. 纯 Native / C++ 快速门禁（跳过 Roborazzi 截图与 Detekt，秒级验证）
./scripts/ai-verify.sh --focus=native

# 3. 纯 UI 页面门禁（Detekt + Lint + Roborazzi 快照）
./scripts/ai-verify.sh --focus=ui

# 4. 双层全量门禁
./scripts/ai-verify.sh --focus=dual
```