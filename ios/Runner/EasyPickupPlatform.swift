import AVFoundation
import Flutter
import UIKit
import UserNotifications
import WidgetKit

final class EasyPickupPlatform: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "easy_pickup/platform", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(EasyPickupPlatform(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "getDatabasePath":
            do { result(try SharedParcelStore.prepareMainDatabase().path) }
            catch { result(FlutterError(code: "database", message: error.localizedDescription, details: nil)) }
        case "consumeSharedImport":
            do { result(try SharedIncomingStore.consume()) }
            catch { result(FlutterError(code: "share_import", message: error.localizedDescription, details: nil)) }
        case "ackSharedImport":
            do {
                guard let id = arguments["draftId"] as? String else { throw IncomingImportError.invalidPayload }
                try SharedIncomingStore.acknowledge(id: id)
                result(nil)
            } catch { result(FlutterError(code: "share_ack", message: error.localizedDescription, details: nil)) }
        case "getPermissions":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                DispatchQueue.main.async {
                    result([
                        "platform": "ios", "readSms": false, "receiveSms": false,
                        "notifications": allowed,
                        "camera": AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                        "batteryOptimized": false,
                        "widgetSupported": SharedParcelStore.groupAvailable,
                        "appGroupAvailable": SharedParcelStore.groupAvailable,
                        "widgetStatus": SharedParcelStore.groupAvailable ? "在主屏幕小组件图库添加易取件" : "组件需要配置 App Groups 的签名版本",
                        "availableApps": Self.destinations.compactMap { key, value in UIApplication.shared.canOpenURL(value) ? key : nil }
                    ])
                }
            }
        case "requestSms", "importSms":
            result(FlutterError(code: "unsupported", message: "iOS 版请使用粘贴、截图或手动添加；本应用不读取短信收件箱。", details: nil))
        case "requestNotifications":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    if let error { result(FlutterError(code: "notifications", message: error.localizedDescription, details: nil)) }
                    else { result(granted) }
                }
            }
        case "openSettings":
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) { opened in
                if opened { result(nil) } else { result(FlutterError(code: "settings", message: "无法打开系统设置", details: nil)) }
            }
        case "openOfficial":
            guard let id = arguments["id"] as? String, let url = Self.destinations[id] else {
                result(FlutterError(code: "destination", message: "未知的官方入口", details: nil)); return
            }
            guard UIApplication.shared.canOpenURL(url) else { result(false); return }
            UIApplication.shared.open(url) { result($0) }
        case "pinWidget":
            // iOS does not allow apps to pin a widget. The UI explains the system widget gallery.
            result(false)
        case "refreshWidgets":
            WidgetCenter.shared.reloadAllTimelines()
            result(nil)
        case "scheduleReminders":
            configureReminders(arguments, result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func configureReminders(_ arguments: [String: Any], result: @escaping FlutterResult) {
        let center = UNUserNotificationCenter.current()
        let ids = (1...7).map { "easy-pickup.weekly.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard arguments["enabled"] as? Bool == true else { result(nil); return }
        let hour = arguments["hour"] as? Int ?? 18
        let minute = arguments["minute"] as? Int ?? 0
        let weekdays = arguments["weekdays"] as? [Int] ?? Array(1...7)
        guard (0...23).contains(hour), (0...59).contains(minute), weekdays.allSatisfy({ (1...7).contains($0) }) else {
            result(FlutterError(code: "reminder", message: "提醒时间不正确", details: nil)); return
        }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async { result(FlutterError(code: "notification_permission", message: "请先允许通知，再开启取件提醒。", details: nil)) }; return
            }
            let group = DispatchGroup()
            let lock = NSLock()
            var firstError: Error?
            for day in Set(weekdays) {
                let content = UNMutableNotificationContent()
                content.title = "顺路取件，轻装回家"
                content.body = "打开易取件，看看是否还有待取快递。"
                content.sound = .default
                var components = DateComponents()
                components.weekday = day == 7 ? 1 : day + 1
                components.hour = hour; components.minute = minute
                group.enter()
                center.add(UNNotificationRequest(identifier: "easy-pickup.weekly.\(day)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))) { error in
                    if let error { lock.lock(); if firstError == nil { firstError = error }; lock.unlock() }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                if let error = firstError {
                    center.removePendingNotificationRequests(withIdentifiers: ids)
                    result(FlutterError(code: "reminder", message: error.localizedDescription, details: nil))
                }
                else { result(nil) }
            }
        }
    }

    private static let destinations: [String: URL] = [
        "cainiao_code": URL(string: "cainiao://desktop/station_code")!,
        "taobao_code": URL(string: "taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code%3Fx-ssr%3Dtrue")!,
        "pinduoduo_code": URL(string: "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11")!,
        "pinduoduo_pickup": URL(string: "pinduoduo://com.xunmeng.pinduoduo/mdkd/package")!,
        "jd_orders": URL(string: "openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22orderlist%22%7D")!,
        "taobao_orders": URL(string: "taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fh5.m.taobao.com%2Fawp%2Fbase%2Forder%2Flistul.htm")!
    ]
}
