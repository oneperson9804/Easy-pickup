# 取件直达

直接打开拼多多「取快递」页面的独立快捷入口，减少从通知或扫码页面查找取件码的步骤。

**在线使用：<https://parcel-pickup-direct.blond-alder-1687.chatgpt.site>**

## 使用

- **安卓**：从网页下载并安装「取快递」APK，再点桌面图标。需要安卓 7.0 及以上，以及已安装并登录的拼多多。
- **iPhone**：用 Safari 打开网页，点「分享 → 添加到主屏幕」。以后从桌面进入网页，再点「打开拼多多取件页」。网页内另有手动创建苹果快捷指令的教程。
- **分享**：使用网页右上角的分享按钮，或把网页链接发给同学。对方使用自己的拼多多账号。

iPhone 第一版提供网页和手动快捷指令方案，没有原生 `.ipa` 安装包。

本工具不隶属拼多多，不要求提供账号、手机号或取件码，不读取取件信息，不支持拍照签收。安卓版只负责唤起指定页面，未声明应用权限；取件信息及出库流程以拼多多和驿站为准。

## 当前验证状态

截至 2026-10-24：

- 固定深链已由用户在 vivo 手机扫码实测，能够进入拼多多取件列表。
- Android APK 已构建，尚待在 vivo 安装后点击桌面图标验收。
- iPhone 深链及手动快捷指令尚待真机验证。

使用的固定地址为：

```text
pinduoduo://com.xunmeng.pinduoduo/mdkd/package
```

## 源码结构

```text
android/
  AndroidManifest.xml
  src/local/pickup/shortcut/MainActivity.java
  res/
  build.ps1
web/
  index.html
  app.js
  styles.css
  manifest.webmanifest
  sw.js
  icons/
  downloads/pickup-shortcut-v1.0.apk
```

`web/` 是无构建步骤的静态网站，可直接放到 HTTPS 静态托管。主屏幕安装及 Service Worker 依赖浏览器支持；Service Worker 只缓存指定的同源页面资源，不缓存 APK。修改离线页面资源时，请更新 `web/sw.js` 中的缓存版本。

## 在 Windows 构建 Android APK

准备 JDK 17、Android SDK Build-Tools 35 和 Android Platform 35，按以下目录放置。脚本不会下载工具链，不需要 Gradle 或 AndroidX。

```text
.local/toolchain/
  jdk/          # 目录内应能找到 bin/javac.exe
  build-tools/  # 目录内应能找到 aapt2.exe、d8.bat、zipalign.exe、apksigner.bat
  platform/     # 目录内应能找到 Android 35 的 android.jar
```

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\android\build.ps1
```

APK 输出到 `dist/pickup-shortcut-v1.0.apk`。脚本会校验签名、ZIP 对齐和权限声明。

第一次构建会在 `.local/pickup-signing/` 生成本地签名密钥及密码，后续构建沿用这组签名。请自行保留这些文件；更换签名后，已安装的旧版本不能直接覆盖更新。仓库不包含签名密钥、密码或工具链。

若要更新网页提供的 APK，另行把构建结果复制到 `web/downloads/pickup-shortcut-v1.0.apk`。

## 参考

- URI 线索：[ranjiushu/pinduoduo-quick](https://github.com/ranjiushu/pinduoduo-quick)。本仓库的 Android 及网页实现为独立编写。
- 交互参考：[取件婆婆](https://r.app.xiaomi.com/details?id=com.sidutech.express)、[包裹时光](https://apps.apple.com/cn/app/id6755714549)。
