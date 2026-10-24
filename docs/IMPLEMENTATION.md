# 易取件 1.0.0 实施约定

已获用户确认：完整重做现版所有实用功能，Android/iOS 共享源码，永久免费、免登录、无广告、无邀请或商业额度。仓库展示名 Easy pickup；GitHub slug 采用 easy-pickup（空格规范化为连字符）。

## 并行所有权

- 根代理：lib/core、lib/services、lib/main.dart、测试、发布与文档、图片资产。
- UI 代理：lib/ui 下所有页面和主题。
- 原生代理：android/app/src/main、iOS AppDelegate/原生服务/WidgetExtension 与 target 配置。
- 工具链代理：Flutter SDK、自动生成骨架、必要 SDK；不覆盖以上手写文件。

## 本地数据契约 v1

数据库文件 easy_pickup.db。Android 使用 context.getDatabasePath；iOS 使用 group.io.github.oneperson9804.easypickup 容器，未配置签名组时主 App 可使用 Application Support，权限页面解释组件不可用原因。原生 getDatabasePath 返回同一绝对路径。SQLite user_version=1。

```sql
CREATE TABLE IF NOT EXISTS parcels(id TEXT PRIMARY KEY,station TEXT NOT NULL,code TEXT NOT NULL,company TEXT NOT NULL DEFAULT '',raw_text TEXT NOT NULL DEFAULT '',arrived_at INTEGER NOT NULL,collected_at INTEGER,deleted_at INTEGER,source TEXT NOT NULL DEFAULT 'manual',source_key TEXT UNIQUE);
CREATE INDEX IF NOT EXISTS parcels_state ON parcels(deleted_at,collected_at,arrived_at);
CREATE TABLE IF NOT EXISTS saved_codes(id TEXT PRIMARY KEY,label TEXT NOT NULL,value TEXT NOT NULL,format TEXT NOT NULL DEFAULT 'qr',created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS rules(id TEXT PRIMARY KEY,kind TEXT NOT NULL,pattern TEXT NOT NULL,replacement TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
```

所有时间为 Unix 毫秒。collected_at IS NULL 为待取；deleted_at 为软删除。source_key 为原始来源去重标识，短信统一 sms:<address>:<date>:<body>，不按两秒窗口丢弃不同短信。手动录入可为 null。source=sms/manual/paste/ocr/backup。设置值为 JSON。

## Flutter 接口（根代理实现）

`lib/core/models.dart`：Parcel(id, station, code, company, rawText, arrivedAt, collectedAt?, deletedAt?, source, sourceKey?)；isCollected。SavedCode(id,label,value,format,createdAt)。RecognitionRule(id,kind,pattern,replacement)。AppSettings(themeMode,sortMode,stationOrder,widgetStyle,widgetShowCodes,reminderEnabled,reminderHour,reminderMinute,reminderWeekdays,smsLookbackDays)，copyWith。

`lib/core/app_controller.dart`：AppController extends ChangeNotifier。parcels（未删除全部记录）、trash、codes、rules、settings、platform、busy、error。pending/collected 派生 getter。方法：reload(), addParcel(Parcel), updateParcel(Parcel), markCollected(Iterable<String> ids,bool collected), removeParcels(Iterable<String> ids), restoreParcels(Iterable<String> ids), emptyTrash(), saveCode(SavedCode), deleteCode(String), saveRule(RecognitionRule), deleteRule(String), updateSettings(AppSettings), importText(String,{String source='paste'}), importSms(), exportBackup(), importBackup(), shareParcels(List<Parcel>,{bool asImage=false}), recognizeScreenshot(), checkUpdates(), openFeedback(), openRepository()。importText/importSms/importBackup返回ImportResult(added,duplicates,unrecognized)；recognizeScreenshot返回String?（用户取消为null）。exportBackup返回bool。错误向调用者抛出，UI展示；不吞成成功。

`lib/services/platform_services.dart`：PlatformServices，getPermissions()->Future<Map<String,dynamic>>、requestSms()->Future<bool>、requestNotifications()->Future<bool>、pinWidget()->Future<bool>、openSettings()->Future<void>、openOfficial(String id)->Future<bool>、refreshWidgets()->Future<void>、scheduleReminders(AppSettings)->Future<void>。MethodChannel 名称 easy_pickup/platform；方法名 getDatabasePath/getPermissions/requestSms/importSms/requestNotifications/pinWidget/openSettings/openOfficial/refreshWidgets/scheduleReminders。importSms 参数 sinceMs，返回 added/duplicates/unrecognized；openOfficial 参数 id；scheduleReminders 参数 enabled/hour/minute/weekdays。

原生 Android 短信接收和 Flutter 共用同一 SQLite 数据库。原生写入后刷新组件；主 App onResume reload。组件操作直接更改 collected_at，主 App 恢复时同步。Flutter 写入后也 refreshWidgets。

## 界面入口

UI 根 `lib/ui/app.dart` 导出 EasyPickupApp({required AppController controller})，负责 MaterialApp（zh_CN、浅深色主题）和主界面。底部：待取件/取件日历/取件码夹。左上角菜单位置不变。首页常驻添加入口。扫码由 mobile_scanner 提供，静态码 barcode_widget 展示，截图识别由根服务调用 image_picker + google_mlkit_text_recognition。所有易取件的本地操作无登录及次数机制。

设置/说明/FAQ/协议/隐私等全部新写，删除旧域名与品牌。分享取件信息使用系统分享，绝无邀请推广。图像资产使用 Image 模型生成，禁止手绘箭头引导。只允许主动检查更新请求 GitHub API，明确用户发起的外部分享、反馈、官方 App 跳转。

## 交付与验收

新 App Android applicationId / iOS bundle id：io.github.oneperson9804.easypickup。版本 1.0.0+1。新包与旧 com.sidutech.express 独立；通过一次性旧版导出 JSON 迁移，不读取其他 App 私有数据。无 Apple 付费账号时仍交付 iOS 源码与可验证的未签名构建流程，真机/TestFlight 正式分发另需账号。

测试含文本识别/去重/批量状态/备份恢复，Android 模拟器安装、权限拒绝与开启、连续短信、小组件添加/缩放/关闭主程序后已取操作、日历一致性；新源代码不继承旧 APK 验收结论。
