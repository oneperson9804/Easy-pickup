# 易取件 · Easy pickup

<p><img src="assets/branding/app_icon.png" alt="易取件" width="96"></p>

把取件通知、日历和随身码夹集中整理在手机上。界面以青色灵力为主调，点缀万年金雷竹的沉金纹理与细微雷光。

永久免费使用。

取件记录保存在本机。“标记已取”更新本机记录；包裹出库和签收按驿站、快递平台的实际流程办理。官方身份码从对应平台打开并验证。

## 功能

- 底部三页：待取件、取件日历、取件码夹；左上角菜单集中管理设置与说明。
- 按站点归组、搜索和自然排序；复制、编辑、批量标记已取、撤销及回收站恢复。
- 手动填写、粘贴文字、截图识别和系统分享导入；Android 授权后可导入历史短信、接收新的取件通知。
- 日历分别保存到件时间和已取时间，跨日未取持续可见。
- 扫码或图片添加静态二维码、条码；官方动态身份码通过对应平台入口查看。
- 站点与公司识别纠正规则、每周取件提醒、JSON 备份与恢复。
- Android 桌面清单可调整宽高；iOS 提供小、中、大 WidgetKit 组件及已取交互。
- 浅色、深色和跟随系统主题。

## 平台与权限

| 能力 | Android 8+ | iOS 17+ |
| --- | --- | --- |
| 本地记录、日历、码夹、导入导出 | 支持 | 支持 |
| 粘贴、截图识别、来源支持的系统分享 | 支持 | 支持 |
| 短信整理 | 系统允许并授权后自动导入、接收 | 使用粘贴或截图导入 |
| 桌面组件尺寸 | 按桌面支持的网格调整 | 系统小、中、大规格 |
| 组件与分享扩展的数据访问 | 同应用本机库 | 通过 App Group 共享 |

短信、相机和通知在使用相应功能时申请权限，手动录入可独立使用。Android 短信授权受系统与安装器策略影响，后台接收和组件刷新也受厂商省电、桌面策略影响；实际测试渠道见[验证记录](docs/VALIDATION.md)。

## 构建

Flutter 3.47.8 stable（commit `737ba8f885dc774b53b442759999a312c9461e4e`），Dart 3.13.7；JDK 21，Android SDK 36、Build Tools 36、NDK 28.2.13676358。依赖版本由 `pubspec.lock` 锁定。

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

正式 Android 包使用仓库外的签名配置：

```sh
bash scripts/create-local-signing.sh
bash scripts/build-android.sh
```

请离线备份生成的签名配置，后续更新沿用同一签名。如需自定义配置位置，设置 `EASY_PICKUP_SIGNING_ENV` 指向仓库外的环境文件，再运行构建脚本。

iOS 使用 macOS 与 Xcode，通过 CocoaPods 接入原生插件：

```sh
flutter pub get
flutter build ios --simulator --debug
test -d build/ios/iphonesimulator/Runner.app/PlugIns/PickupWidget.appex
test -d build/ios/iphonesimulator/Runner.app/PlugIns/ShareExtension.appex
```

真机分发需配置开发者团队、Runner 与两个扩展的 Bundle ID，以及 `group.io.github.oneperson9804.easypickup`。App Store 和 TestFlight 使用 Apple Developer Program 分发，配置要求见 [Apple 注册说明](https://developer.apple.com/cn/help/account/membership/enrolling-in-the-app/)。

## 备份与迁移

在“设置 → 备份与恢复”导出、导入 JSON 文件。导入时保留本机记录，按 ID、来源键去重，并读取备份中的码夹、规则和设置。备份包含取件信息，请自行保管。

从受支持版本迁移时，先使用配套工具导出文件，再到易取件导入。核对记录、时间和规则后再移除旧应用。操作步骤与签名要求见[迁移工具说明](tools/legacy-migration/README.md)。

## 数据处理

截图识别和 Android 扫码使用端侧 ML Kit 模型，输入图片、文字及识别结果在设备上处理。SDK 可能按 Google 官方说明发送设备、应用版本、性能和错误等诊断信息。[ML Kit 隐私](https://developers.google.com/ml-kit/terms)、[Android 数据披露](https://developers.google.com/ml-kit/android-data-disclosure)、[iOS 数据披露](https://developers.google.com/ml-kit/ios-data-disclosure)。

检查更新由用户触发，访问 GitHub 公开版本信息；反馈与官方取件入口打开对应外部服务。分享内容经用户确认后交给所选接收应用。完整说明可在 App 内离线阅读。

## 验证与版本

Android 1.0.0 安装包与 SHA-256 校验文件见本仓库 Releases，当前检查结果见[验证记录](docs/VALIDATION.md)。

GitHub Actions 执行 Linux 检查、Android 构建和 macOS iOS 构建。源码结构与数据流见[架构说明](docs/IMPLEMENTATION.md)。

## 许可证

项目采用 [MIT](LICENSE)。各依赖按自身许可证授权，App“关于与开源”可查看 Flutter 收集的许可。原生组件说明见[第三方说明](THIRD_PARTY_NOTICES.md)，图片规范见[素材说明](docs/ASSETS.md)。
