import AVFoundation
import Flutter
import UIKit
import UserNotifications
import WidgetKit

final class EasyPickupPlatform: NSObject, FlutterPlugin {
    private struct AppRoute: Decodable {
        let uri: URL
    }
    private struct Destination: Decodable {
        let id: String
        let apps: [AppRoute]
    }
    private struct Catalog: Decodable {
        let destinations: [Destination]
    }
    private let catalog: Result<[Destination], Error>

    private init(assetPath: String?) {
        catalog = Result {
            guard let assetPath else {
                throw NSError(domain: "EasyPickup", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取平台入口"])
            }
            return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: URL(fileURLWithPath: assetPath))).destinations
        }
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "easy_pickup/platform", binaryMessenger: registrar.messenger())
        let key = registrar.lookupKey(forAsset: "assets/platforms.json")
        registrar.addMethodCallDelegate(EasyPickupPlatform(assetPath: Bundle.main.path(forResource: key, ofType: nil)), channel: channel)
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
            let destinations: [Destination]
            do { destinations = try catalog.get() }
            catch { result(FlutterError(code: "destination", message: error.localizedDescription, details: nil)); return }
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
                        "availableApps": destinations.filter { destination in
                            destination.apps.contains { UIApplication.shared.canOpenURL($0.uri) }
                        }.map { $0.id }
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
            do {
                guard let id = arguments["id"] as? String,
                      let destination = try catalog.get().first(where: { $0.id == id }) else {
                    result(FlutterError(code: "destination", message: "未知的官方入口", details: nil)); return
                }
                open(destination, routeIndex: 0, result: result)
            } catch {
                result(FlutterError(code: "destination", message: error.localizedDescription, details: nil))
            }
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

    private func open(_ destination: Destination, routeIndex: Int, result: @escaping FlutterResult) {
        guard routeIndex < destination.apps.count else {
            result(["id": destination.id, "status": "unavailable", "reason": "route_unavailable"])
            return
        }
        UIApplication.shared.open(destination.apps[routeIndex].uri, options: [:]) { opened in
            if opened { result(["id": destination.id, "status": "app"]) }
            else { self.open(destination, routeIndex: routeIndex + 1, result: result) }
        }
    }
}
