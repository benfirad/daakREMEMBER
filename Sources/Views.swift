import AppKit
import SwiftUI

extension Notification.Name {
    static let focusCaptureField = Notification.Name("focusCaptureField")
    static let showMemoryItem = Notification.Name("showMemoryItem")
}

private let ink = Color(red: 0.14, green: 0.13, blue: 0.12)
private let mutedInk = ink.opacity(0.58)
private let warm = Color(red: 0.96, green: 0.74, blue: 0.25)
private let paper = Color(red: 0.98, green: 0.96, blue: 0.91)

final class CaptureDraft: ObservableObject {
    @Published var text = ""
    @Published var folder: MemoryFolder {
        didSet {
            if persistsFolder {
                SharedStorage.saveCaptureFolder(folder)
            }
        }
    }
    private let persistsFolder: Bool

    init(
        folder: MemoryFolder? = nil,
        persistsFolder: Bool = true
    ) {
        self.persistsFolder = persistsFolder
        self.folder = folder ?? SharedStorage.selectedCaptureFolder()
        if persistsFolder {
            SharedStorage.saveCaptureFolder(self.folder)
        }
    }

    func consume() -> (text: String, folder: MemoryFolder)? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        text = ""
        return (clean, folder)
    }
}

private struct CaptureTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15, weight: .medium)
        field.textColor = NSColor(
            red: 0.14,
            green: 0.13,
            blue: 0.12,
            alpha: 1
        )
        field.placeholderString = placeholder
        field.lineBreakMode = .byTruncatingTail
        context.coordinator.field = field
        context.coordinator.installFocusObserver()
        context.coordinator.focusField()
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    static func dismantleNSView(
        _ field: NSTextField,
        coordinator: Coordinator
    ) {
        coordinator.removeFocusObserver()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CaptureTextField
        weak var field: NSTextField?
        private var focusObserver: NSObjectProtocol?

        init(parent: CaptureTextField) {
            self.parent = parent
        }

        func installFocusObserver() {
            focusObserver = NotificationCenter.default.addObserver(
                forName: .focusCaptureField,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.focusField()
            }
        }

        func removeFocusObserver() {
            if let focusObserver {
                NotificationCenter.default.removeObserver(focusObserver)
            }
            focusObserver = nil
        }

        func focusField() {
            focusFieldNow()
            DispatchQueue.main.async { [weak self] in
                self?.focusFieldNow()
            }
        }

        private func focusFieldNow() {
            guard let field, let window = field.window else { return }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(field)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            let submitCommands = [
                #selector(NSResponder.insertNewline(_:)),
                #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
            ]
            guard submitCommands.contains(commandSelector) else {
                return false
            }
            parent.onSubmit()
            focusField()
            return true
        }
    }
}

struct QuickCaptureView: View {
    @ObservedObject var store: MemoryStore
    @ObservedObject var localization: LocalizationController
    @ObservedObject var draft: CaptureDraft
    let syncNow: () -> Void
    let checkForUpdates: () -> Void
    @State private var expandedItemID: UUID?
    @State private var selectedFilter: MemoryFilter = .all

    private var displayedItems: [MemoryItem] {
        store.visibleItems(in: selectedFilter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.text("capture_greeting"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(localization.text("capture_question"))
                        .font(.system(size: 12))
                        .foregroundStyle(mutedInk)
                }
                Spacer()
                Menu {
                    Picker(
                        localization.text("language"),
                        selection: $localization.language
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(localization.text("settings"))
                Button(action: syncNow) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                .help(localization.text("sync_now"))
            }

            HStack(spacing: 8) {
                CaptureTextField(
                    text: $draft.text,
                    placeholder: localization.text("capture_placeholder"),
                    onSubmit: add
                )
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

            HStack(spacing: 7) {
                Menu {
                    Picker(
                        localization.text("capture_folder"),
                        selection: $draft.folder
                    ) {
                        ForEach(MemoryFolder.allCases) { folder in
                            Label(
                                localization.text(folder.localizationKey),
                                systemImage: folder.symbolName
                            )
                            .tag(folder)
                        }
                    }
                } label: {
                    Label(
                        localization.text(draft.folder.localizationKey),
                        systemImage: draft.folder.symbolName
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(warm.opacity(0.32), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Text(localization.text("capture_folder_hint"))
                    .font(.system(size: 9))
                    .foregroundStyle(mutedInk)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MemoryFilter.allCases) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedFilter = filter
                                expandedItemID = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(localization.text(filter.localizationKey))
                                Text("\(store.count(in: filter))")
                                    .foregroundStyle(mutedInk)
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                selectedFilter == filter
                                    ? warm.opacity(0.72)
                                    : Color.white.opacity(0.58),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if displayedItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: selectedFilter == .all ? "sparkles" : "folder")
                        .font(.system(size: 25))
                    Text(
                        localization.text(
                            selectedFilter == .all
                                ? "empty_state"
                                : "empty_folder"
                        )
                    )
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(mutedInk)
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(displayedItems) { item in
                                MemoryRow(
                                    item: item,
                                    store: store,
                                    isExpanded: Binding(
                                        get: { expandedItemID == item.id },
                                        set: { isExpanded in
                                            expandedItemID = isExpanded
                                                ? item.id
                                                : nil
                                        }
                                    ),
                                    copyLabel: localization.text("copy"),
                                    expandLabel: localization.text("show_full_text"),
                                    collapseLabel: localization.text("collapse_text"),
                                    moveLabel: localization.text("move_to"),
                                    folderName: localization.text(
                                        item.effectiveFolder.localizationKey
                                    ),
                                    folderNameFor: { folder in
                                        localization.text(folder.localizationKey)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(for: .showMemoryItem)
                    ) { notification in
                        guard let id = notification.object as? UUID else { return }
                        expandedItemID = id
                        DispatchQueue.main.async {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(store.lastSync == nil ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(
                    localization.text(
                        store.syncMessageKey,
                        arguments: store.syncMessageArguments
                    )
                )
                    .font(.system(size: 10))
                    .foregroundStyle(mutedInk)
                    .lineLimit(1)
                Spacer()
                Button(
                    localization.text("check_for_updates"),
                    action: checkForUpdates
                )
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(mutedInk)
                Button(localization.text("quit")) {
                    NSApplication.shared.terminate(nil)
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(mutedInk)
            }
        }
        .padding(16)
        .frame(width: 360, height: 560, alignment: .top)
        .background(paper)
        .foregroundStyle(ink)
        .environment(\.colorScheme, .light)
        .onAppear {
            NotificationCenter.default.post(name: .focusCaptureField, object: nil)
        }
    }

    private func add() {
        guard let capture = draft.consume() else { return }
        store.add(capture.text, folder: capture.folder)
        syncNow()
        NotificationCenter.default.post(name: .focusCaptureField, object: nil)
    }
}

struct MemoryRow: View {
    let item: MemoryItem
    @ObservedObject var store: MemoryStore
    @Binding var isExpanded: Bool
    let copyLabel: String
    let expandLabel: String
    let collapseLabel: String
    let moveLabel: String
    let folderName: String
    let folderNameFor: (MemoryFolder) -> String
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Button { store.toggle(item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.green : mutedInk)
                    .font(.system(size: 17))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(item.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(item.isDone ? mutedInk : ink)
                        .strikethrough(item.isDone)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(isExpanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded ? collapseLabel : expandLabel)

                Label(folderName, systemImage: item.effectiveFolder.symbolName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(mutedInk)
            }

            if isHovering {
                Button(action: copyText) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(didCopy ? Color.green : mutedInk)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(copyLabel)
                .transition(.opacity.combined(with: .scale))
            }

            Menu {
                ForEach(MemoryFolder.allCases) { folder in
                    Button {
                        store.move(item.id, to: folder)
                    } label: {
                        Label(folderNameFor(folder), systemImage: folder.symbolName)
                    }
                }
            } label: {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(mutedInk)
                    .frame(width: 18, height: 18)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(moveLabel)

            Button { store.remove(item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(mutedInk)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Color.white.opacity(isHovering ? 0.82 : 0.62),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
            if !hovering {
                didCopy = false
            }
        }
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        didCopy = true
    }
}
