import SwiftUI
import WidgetKit

struct MemoryEntry: TimelineEntry {
    let date: Date
    let items: [MemoryItem]
    let language: AppLanguage

    func text(_ key: String) -> String {
        AppLocalization.text(key, language: language)
    }
}

struct MemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoryEntry {
        let language = AppLocalization.selectedLanguage()
        return MemoryEntry(date: Date(), items: [
            MemoryItem(
                text: AppLocalization.text(
                    "widget_example_first",
                    language: language
                )
            ),
            MemoryItem(
                text: AppLocalization.text(
                    "widget_example_second",
                    language: language
                )
            )
        ], language: language)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> Void) {
        completion(
            MemoryEntry(
                date: Date(),
                items: visibleItems(),
                language: AppLocalization.selectedLanguage()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryEntry>) -> Void) {
        let entry = MemoryEntry(
            date: Date(),
            items: visibleItems(),
            language: AppLocalization.selectedLanguage()
        )
        let refresh = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
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
        switch family {
        case .systemSmall:
            return 4
        case .systemMedium:
            return 4
        case .systemLarge:
            return 9
        default:
            return 7
        }
    }

    private var itemLineLimit: Int {
        1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(.orange)
                Text(entry.text("widget_title"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.secondary)
            }

            if entry.items.isEmpty {
                Spacer()
                Text(entry.text("widget_empty"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(Array(entry.items.prefix(limit))) { item in
                    Link(
                        destination: URL(
                            string: "daakremember://item/\(item.id.uuidString)"
                        )!
                    ) {
                        HStack(alignment: .top, spacing: 7) {
                            Image(
                                systemName: item.isDone
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(item.isDone ? .green : .secondary)
                            Text(item.text)
                                .font(.system(size: 12, weight: .medium))
                                .strikethrough(item.isDone)
                                .foregroundStyle(
                                    item.isDone ? .secondary : .primary
                                )
                                .lineLimit(itemLineLimit)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "daakremember://capture"))
        .environment(\.locale, Locale(identifier: entry.language.rawValue))
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct AklimaGeldiWidgetBundle: WidgetBundle {
    var body: some Widget {
        AklimaGeldiWidget()
    }
}
