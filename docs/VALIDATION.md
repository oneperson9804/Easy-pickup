# 易取件 1.0.0 验证记录

状态：开发验收中。以下只记录新源码工程结果，不继承旧 code56 APK 验收结论。

- 已完成：Flutter 3.47.8 / Dart 3.13.7 环境、Android SDK36/NDK28.2。
- 已完成：全工程 flutter analyze 无问题（分享导入等后续改动将再验证）。
- 已完成：6项核心测试，包括共同短信样例、验证码隔离、识别纠正规则、自然排序、撤销、200条跨日跨月SQLite状态操作与备份去重。
- 已完成：Android 原生 AAPT2 资源链接、Kotlin 类型编译、原生短信样例；不是最终 APK 构建结论。
- 进行中：完整签名 APK 构建、Android16模拟器功能测试、迁移包导出导入。
- 进行中：iOS macOS CI 编译 Runner、PickupWidget 与 ShareExtension。
- 未覆盖：Apple 开发者签名、iPhone 真机、TestFlight/App Store、国产真机侧载安装器权限、长期休眠；发布前据实更新。

审查已修复：实时/历史短信时间键一致性、前台接收后刷新、旧Android实际通知状态、备份提交与提醒失败分离、官方URL scheme白名单、恢复已取的准确时间。
