# 第三方组件与素材

更新日期：2026-10-25。

精确依赖见 `pubspec.lock`。Flutter 将 Dart 包声明的 LICENSE 收入 App 的“关于与开源 → 第三方开源许可证”；各依赖按自身许可证授权。

主要依赖包括 Flutter/Dart、sqflite、shared_preferences、file_picker、share_plus、image_picker、mobile_scanner、barcode_widget/barcode、url_launcher、http 及对应原生平台包。各包的源码和 LICENSE 可从其 pub.dev 页面中的 Repository 链接查看。

Android 使用 Google ML Kit Chinese Text Recognition 和 Barcode Scanning；iOS 截图识别使用 Google ML Kit TextRecognitionChinese。SDK 条款和数据处理说明：

- [ML Kit 条款与隐私](https://developers.google.com/ml-kit/terms)
- [Android 数据披露](https://developers.google.com/ml-kit/android-data-disclosure)
- [iOS 数据披露](https://developers.google.com/ml-kit/ios-data-disclosure)

图片、文字及识别结果在设备上处理。SDK 的设备、应用版本、性能和错误等诊断信息按上述官方说明处理。

Android SDK、Apple SDK、Flutter 引擎及各平台系统框架由对应权利人提供。第三方平台名称与商标归各自所有，官方取件流程由相应平台提供。

项目图标和插画随项目许可证发布，设计规范见[素材说明](docs/ASSETS.md)。
