import SwiftUI
import WidgetKit

struct MemoryEntry: TimelineEntry {
    let date: Date
    let items: [MemoryItem]
}

struct MemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), items: [
            MemoryItem(text: String(localized: "widget_example_first")),
            MemoryItem(text: String(localized: "widget_example_second"))
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> Void) {
        completion(MemoryEntry(date: Date(), items: visibleItems()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryEntry>) -> Void) {
        let entry = MemoryEntry(date: Date(), items: visibleItems())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func visibleItems() -> [MemoryItem] {
        SharedStorage.load()
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return $0.updatedAt > $1.updatedAt
            }
    }
}

struct AklimaGeldiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MemoryEntry

    private var limit: Int {
        family == .systemSmall ? 4 : 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(.orange)
                Text("widget_title")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.secondary)
            }

            if entry.items.isEmpty {
                Spacer()
                Text("widget_empty")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(Array(entry.items.prefix(limit))) { item in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(item.isDone ? .green : .secondary)
                        Text(item.text)
                            .font(.system(size: 12, weight: .medium))
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                            .lineLimit(family == .systemSmall ? 1 : 2)
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "aklimageldi://capture"))
    }
}

struct AklimaGeldiWidget: Widget {
    let kind = "AklimaGeldiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoryProvider()) { entry in
            AklimaGeldiWidgetView(entry: entry)
        }
        .configurationDisplayName("widget_display_name")
        .description("widget_description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AklimaGeldiWidgetBundle: WidgetBundle {
    var body: some Widget {
        AklimaGeldiWidget()
    }
}
