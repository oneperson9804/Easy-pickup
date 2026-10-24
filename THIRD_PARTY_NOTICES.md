# 第三方组件与素材

完整精确依赖见 pubspec.lock。Flutter 会将 Dart 包声明的 LICENSE 收入 App 的“关于与开源 → 第三方开源许可证”。本项目 MIT 授权不替代依赖本身的授权。

主要依赖：Flutter/Dart、sqflite、shared_preferences、file_picker、share_plus、image_picker、mobile_scanner、barcode_widget/barcode、url_launcher、http，以及对应原生平台包。各包源码与 LICENSE 位于对应 pub.dev 包的 Repository 链接。

Android 使用 Google ML Kit 的 bundled Chinese Text Recognition 和 Barcode Scanning；iOS 截图识别使用 Google ML Kit TextRecognitionChinese。SDK 条款和数据处理说明：

- https://developers.google.com/ml-kit/terms
- https://developers.google.com/ml-kit/android-data-disclosure
- https://developers.google.com/ml-kit/ios-data-disclosure

图片和识别结果留在设备，SDK 的设备/应用/性能诊断按其官方说明处理。业务层没有第三方广告或账号统计 SDK。

Android SDK、Apple SDK、Flutter 引擎及各平台系统框架由对应权利人提供。第三方平台名称和商标归各自所有；本项目不隶属菜鸟、淘宝、拼多多、京东或快递公司。

原创生成图标及插画的用途与提示见 docs/ASSETS.md。legacy/ 为此前快捷入口的独立实现，不包含本次输入的反编译主应用源码。
