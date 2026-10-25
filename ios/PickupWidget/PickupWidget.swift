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
    static var description = IntentDescription("记录已经取走的包裹。")
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
    private var foreground: Color { dark ? Color(red: 0.97, green: 0.99, blue: 0.99) : Color(red: 0.08, green: 0.23, blue: 0.26) }
    private var accent: Color { dark ? Color(red: 0.96, green: 0.86, blue: 0.61) : Color(red: 0.28, green: 0.42, blue: 0.41) }

    var body: some View {
        GeometryReader { geometry in
            let rowHeight: CGFloat = family == .systemLarge ? 62 : 48
            let limit = family == .systemSmall ? 1 : max(1, Int((geometry.size.height - 30) / (rowHeight + 5)))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("易取件").font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 2)
                    if entry.message == nil {
                        Text("\(entry.snapshot.count) 件待取")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                if let message = entry.message {
                    Spacer(minLength: 0)
                    Text(message).font(.caption).foregroundStyle(foreground.opacity(0.8))
                    Spacer(minLength: 0)
                } else if entry.snapshot.count == 0 {
                    Spacer(minLength: 0)
                    Text("都取好了").font(.title3.weight(.semibold))
                    Text("轻装出发").font(.caption).foregroundStyle(foreground.opacity(0.75))
                    Spacer(minLength: 0)
                } else {
                    ForEach(entry.snapshot.parcels.prefix(limit)) { parcel in
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(parcel.station)
                                    .font(.system(size: 11))
                                    .lineLimit(family == .systemLarge || family == .systemSmall ? 2 : 1)
                                    .foregroundStyle(foreground.opacity(0.82))
                                Text(entry.snapshot.showCodes ? (parcel.code.isEmpty ? "待补充" : parcel.code) : "取件码已隐藏")
                                    .font(.system(size: family == .systemLarge ? 24 : 20, weight: .bold, design: .rounded))
                                    .lineLimit(1).minimumScaleFactor(0.65)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Button(intent: CollectParcelIntent(parcelID: parcel.id)) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 48, height: 48)
                                    .background((dark ? Color.black : Color.white).opacity(dark ? 0.18 : 0.36),
                                                in: RoundedRectangle(cornerRadius: 17))
                                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(accent.opacity(0.4), lineWidth: 0.7))
                            }
                            .buttonStyle(.plain).foregroundStyle(accent)
                            .accessibilityLabel("标记\(parcel.station)的快递已取")
                        }
                        .frame(minHeight: rowHeight)
                    }
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(foreground)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: dark
                        ? [Color(red: 0.22, green: 0.47, blue: 0.51).opacity(entry.snapshot.opacity + 0.09),
                           Color(red: 0.05, green: 0.15, blue: 0.20).opacity(entry.snapshot.opacity)]
                        : [Color.white.opacity(entry.snapshot.opacity + 0.1),
                           Color(red: 0.81, green: 0.90, blue: 0.91).opacity(entry.snapshot.opacity)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.6), accent.opacity(0.2), Color.white.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
                    .padding(0.5)
            }
        }
    }
}

struct EasyPickupWidget: Widget {
    let kind = "EasyPickupWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickupProvider()) { PickupWidgetView(entry: $0) }
            .configurationDisplayName("易取件")
            .description("站点、取件码与待取数量，轻点勾选记录已取。")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
    }
}

@main
struct EasyPickupWidgetBundle: WidgetBundle {
    var body: some Widget { EasyPickupWidget() }
}
