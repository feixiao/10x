# Android 工程规范与红线约束 (android-jni-rules.md)

## 1. 架构红线 (Hard Rules)
- **主线程禁令**: 严禁在主线程执行 I/O、网络请求或耗时 Native 计算。
- **JNI 局部引用管理**: 循环或密集调用中必须显式调用 `env->DeleteLocalRef()`。
- **JNI 异常检查**: 调用 Java 方法后必须检查 `env->ExceptionCheck()`；C++ 异常严禁穿越 JNI 边界进入 JVM。

## 2. 必跑验证命令
```bash
./gradlew testDebugUnitTest && ./gradlew lintDebug
```