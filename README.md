# 易取件 · Easy pickup

青竹与金雷配色的开源取件助手。永久免费、免登录、无广告、无邀请解锁，无商业次数限制。

取件记录保存在本机。**“标记已取”只更新本机记录，不替代快递公司或驿站的正式签收。** 官方身份码入口打开相应平台，该平台可能需要登录自己的账号。

## 1.0.0 功能

- 底部三页：待取件、取件日历、取件码夹；左上角菜单集中管理设置与说明。
- 按站点归组、搜索和自然排序；复制、编辑、批量标记已取、准确撤销、回收站。
- 手动、粘贴文字、截图识别、外部分享导入；Android 授权后历史短信导入和后台接收。
- 日历同时保留到件时间和已取时间，跨日未取持续可见。
- 扫码或图片添加本地静态二维码/条码，官方动态身份码单独打开。
- 本地站点与公司纠正规则、每周取件提醒、JSON 备份与合并恢复。
- Android 可调整宽高的桌面清单；iOS 小、中、大 WidgetKit 组件及已取交互。
- 统一浅色、深色和跟随系统主题，原创 Image 模型图标与空状态插画。

## 平台区别

| 能力 | Android 8+ | iOS 17+ |
| --- | --- | --- |
| 本地记录、日历、码夹、导入导出 | 支持 | 支持 |
| 粘贴、截图识别、来源支持的系统分享 | 支持 | 支持 |
| 自动读取短信收件箱 | 系统允许并授权后支持 | 不提供；使用上述导入方式 |
| 桌面组件尺寸 | 由桌面支持的网格调整 | 系统小、中、大规格 |
| 小组件和分享扩展共享数据 | 同应用本机库 | 需要有效 App Group 签名配置 |

拒绝短信、相机或通知权限后仍可手动管理记录。短信硬限制受系统及安装器影响，ADB 安装验收不能代表所有手机侧载安装器；应用不要求成为默认短信应用。厂商后台和桌面策略可能影响实时接收和组件刷新。

## 构建

Flutter 3.47.8 stable（官方 commit `737ba8f885dc774b53b442759999a312c9461e4e`），Dart 3.13.7；JDK 21，Android SDK 36、Build Tools 36、NDK 28.2.13676358。依赖版本由 `pubspec.lock` 锁定。

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

正式 Android 包使用独立签名，密钥保存在仓库外：

```sh
bash scripts/create-local-signing.sh
bash scripts/build-android.sh
```

请自行离线备份生成的签名配置。后续更新必须沿用同一签名；仓库、Issue 和工作流都不应包含签名密钥或密码。无密钥环境可构建调试包，release 不借用 debug 密钥冒充正式签名。

如需自定义签名配置路径，设置 `EASY_PICKUP_SIGNING_ENV` 指向仓库外的环境文件，再运行构建脚本。

iOS 需要 macOS 与 Xcode：

```sh
flutter pub get
flutter build ios --simulator --debug
test -d build/ios/iphonesimulator/Runner.app/PlugIns/PickupWidget.appex
```

项目包含实际 `PickupWidget` 与 `ShareExtension` targets。真机分发前配置自己的开发者团队、三个 Bundle ID 和 `group.io.github.oneperson9804.easypickup`。App Store/TestFlight 还需要有效 Apple Developer Program 会员；中国大陆当前官方年费为 ¥688。App 对使用者始终免费。当前没有开发者账号，不应把 iOS 源码或模拟器构建称为已上架版本。

## 数据迁移

新 Android 标识为 `io.github.oneperson9804.easypickup`，与旧 `com.sidutech.express` 独立。新应用不能直接读取旧 App 私有数据库。使用配套旧版导出工具生成 JSON，再在新 App“设置 → 备份与恢复”导入；确认记录、时间与规则迁移完成后再移除旧版。见 [迁移工具说明](tools/legacy-migration/README.md)。

恢复操作合并记录并按 ID/来源键去重，导入备份中的设置、码夹和规则；不会清空现有记录。备份文件含取件信息，请自行保管。

## 隐私与第三方组件

没有账号、支付、邀请、广告、云端取件数据库或商业额度模块。源码不包含原 App 反编译 SDK 和个人记录。

截图识别和 Android 扫码使用端侧 ML Kit 模型，输入图片、文字和识别结果在本机处理。根据 Google 官方说明，SDK 可能发送设备、应用版本、性能、错误等诊断信息；不能把“端侧识别”解释为“全部依赖永不联网”。[ML Kit 隐私](https://developers.google.com/ml-kit/terms)、[Android 数据披露](https://developers.google.com/ml-kit/android-data-disclosure)、[iOS 数据披露](https://developers.google.com/ml-kit/ios-data-disclosure)。

检查更新由用户主动触发，访问 GitHub 公开 Releases；反馈与官方取件入口打开外部服务。分享内容由用户检查后交给所选接收应用。完整说明在 App 内可离线阅读。

## 验证与发布

新工程正在进行设备与 CI 验收，当前未把旧 APK 的测试结果作为新 App 结论。最终状态和已知限制见 [验证记录](docs/VALIDATION.md)。正式 APK 从本仓库 Releases 获取，校验值随版本提供。

GitHub Actions 使用公开仓库的标准 Linux/macOS runner，只执行验证，不持有签名凭据、不自动发布 App Store。

## 许可证与历史

新工程采用 [MIT](LICENSE)。第三方组件保留各自许可证，App“关于与开源”可查看 Flutter 收集的许可；原生 ML Kit 条款见 [第三方说明](THIRD_PARTY_NOTICES.md)。原创图片见 [素材说明](docs/ASSETS.md)。

本仓库由原 `parcel-pickup-direct` 演进，保留 Git 历史，旧的轻量快捷入口保存在 `legacy/`。旧快捷入口与完整易取件的功能和验收范围不同。
