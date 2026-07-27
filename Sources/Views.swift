import SwiftUI

private let ink = Color(red: 0.14, green: 0.13, blue: 0.12)
private let warm = Color(red: 0.96, green: 0.74, blue: 0.25)
private let paper = Color(red: 0.98, green: 0.96, blue: 0.91)

final class CaptureDraft: ObservableObject {
    @Published var text = ""
}

struct QuickCaptureView: View {
    @ObservedObject var store: MemoryStore
    let syncNow: () -> Void
    @ObservedObject private var draft = CaptureDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buyur abim 👋")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Aklına ne geldi, neler yapman lazım?")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: syncNow) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                .help("Şimdi eşitle")
            }

            HStack(spacing: 8) {
                TextField("Unutmadan yaz…", text: $draft.text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ink)
                        .frame(width: 28, height: 28)
                        .background(warm, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))

            if store.visibleItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 25))
                    Text("Kafan artık boş, ben tutuyorum.")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(store.visibleItems) { item in
                            MemoryRow(item: item, store: store)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(store.lastSync == nil ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(store.syncMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("Çıkış") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(paper)
    }

    private func add() {
        store.add(draft.text)
        draft.text = ""
        syncNow()
    }
}

struct MemoryRow: View {
    let item: MemoryItem
    @ObservedObject var store: MemoryStore

    var body: some View {
        HStack(spacing: 9) {
            Button { store.toggle(item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.green : Color.secondary)
                    .font(.system(size: 17))
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.isDone ? Color.secondary : ink)
                .strikethrough(item.isDone)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)

            Button { store.remove(item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct DesktopWidgetView: View {
    @ObservedObject var store: MemoryStore
    let openCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(warm)
                Text("AKLIMA GELDİ")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.2)
                Spacer()
                Button(action: openCapture) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            if store.visibleItems.isEmpty {
                Text("Aklına geleni üst bardan bana söyle abim.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(store.visibleItems.prefix(6))) { item in
                    HStack(alignment: .top, spacing: 7) {
                        Button { store.toggle(item.id) } label: {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(item.isDone ? Color.green : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        Text(item.text)
                            .font(.system(size: 12, weight: .medium))
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? Color.secondary : ink)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 288)
        .background(.ultraThinMaterial)
        .background(paper.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }
}
