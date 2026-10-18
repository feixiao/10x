# Android 盲审技术栈核查清单 (checklist.md)

- [ ] **主线程阻塞**: 主线程是否有网络、IO 或超过 5ms 的复杂 Native 计算？
- [ ] **JNI LocalRef 泄漏**: 循环中是否及时调用 `env->DeleteLocalRef()` 防范 512 局部引用表溢出？
- [ ] **JNI 异常屏障**: C++ 代码是否包裹在 try-catch 中，防止未捕获异常导致崩溃？
- [ ] **Context 泄漏**: 单例或后台协程是否持久化持有 Activity 引用？