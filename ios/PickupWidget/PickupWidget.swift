import AppIntents
import SwiftUI
import WidgetKit

struct PickupEntry: TimelineEntry {
    let date: Date
    var snapshot = WidgetParcelSnapshot()
    var message: String?
}

struct PickupProvider: TimelineProvider {
    func placeholder(in context: Context) -> PickupEntry { PickupEntry(date: Date(), message: "桌面取件清单") }
    func getSnapshot(in context: Context, completion: @escaping (PickupEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PickupEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(1800))))
    }
    private func entry() -> PickupEntry {
        do { return PickupEntry(date: Date(), snapshot: try SharedParcelStore.snapshot()) }
        catch { return PickupEntry(date: Date(), message: error.localizedDescription) }
    }
}

struct CollectParcelIntent: AppIntent {
    static var title: LocalizedStringResource = "标记已取"
    static var description = IntentDescription("更新易取件的本机记录，不向快递公司或驿站确认出库。")
    static var openAppWhenRun = false
    @Parameter(title: "记录标识") var parcelID: String
    init() {}
    init(parcelID: String) { self.parcelID = parcelID }
    func perform() async throws -> some IntentResult {
        try SharedParcelStore.collect(id: parcelID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct PickupWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PickupEntry
    private var dark: Bool { entry.snapshot.style != "ivory" }
    private var foreground: Color { dark ? Color(red: 0.95, green: 0.98, blue: 0.98) : Color(red: 0.09, green: 0.22, blue: 0.27) }
    private var accent: Color { dark ? Color(red: 0.89, green: 0.77, blue: 0.49) : Color(red: 0.08, green: 0.49, blue: 0.53) }
    private var limit: Int { family == .systemSmall ? 1 : family == .systemMedium ? 2 : 5 }
    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            HStack {
                Label("易取件", systemImage: "shippingbox").font(.headline)
                Spacer(minLength: 2)
                if entry.message == nil { Text("\(entry.snapshot.count) 待取").font(.subheadline.bold()).foregroundStyle(accent) }
            }
            if let message = entry.message {
                Text(message).font(.caption).foregroundStyle(foreground.opacity(0.75))
                Spacer(minLength: 0)
            } else if entry.snapshot.count == 0 {
                Spacer(minLength: 0)
                Text("都取好了").font(.title3.weight(.semibold))
                Text("轻装出发，顺路回家").font(.caption).foregroundStyle(foreground.opacity(0.7))
                Spacer(minLength: 0)
            } else {
                ForEach(entry.snapshot.parcels.prefix(limit)) { parcel in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parcel.station).font(.caption2).lineLimit(1).foregroundStyle(foreground.opacity(0.72))
                            Text(entry.snapshot.showCodes ? parcel.code : "取件码已隐藏")
                                .font(family == .systemLarge ? .title3.bold() : .headline).lineLimit(1).minimumScaleFactor(0.65)
                        }
                        Spacer(minLength: 2)
                        Button(intent: CollectParcelIntent(parcelID: parcel.id)) {
                            Image(systemName: "checkmark").font(.subheadline.bold()).frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain).foregroundStyle(accent)
                        .accessibilityLabel("标记\(parcel.station)的快递已取")
                    }
                }
                Spacer(minLength: 0)
            }
            if family != .systemSmall {
                Text("标记已取仅更新本机记录").font(.system(size: 10)).foregroundStyle(foreground.opacity(0.6))
            }
        }
        .foregroundStyle(foreground)
        .containerBackground(dark ? Color(red: 0.07, green: 0.19, blue: 0.23) : Color(red: 0.95, green: 0.97, blue: 0.97), for: .widget)
    }
}

struct EasyPickupWidget: Widget {
    let kind = "EasyPickupWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickupProvider()) { PickupWidgetView(entry: $0) }
            .configurationDisplayName("易取件")
            .description("查看待取件，并直接标记已取。")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct EasyPickupWidgetBundle: WidgetBundle {
    var body: some Widget { EasyPickupWidget() }
}
