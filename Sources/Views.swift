import AppKit
import SwiftUI

extension Notification.Name {
    static let focusCaptureField = Notification.Name("focusCaptureField")
    static let submitCapture = Notification.Name("submitCapture")
}

private let ink = Color(red: 0.14, green: 0.13, blue: 0.12)
private let mutedInk = ink.opacity(0.58)
private let warm = Color(red: 0.96, green: 0.74, blue: 0.25)
private let paper = Color(red: 0.98, green: 0.96, blue: 0.91)

final class CaptureDraft: ObservableObject {
    @Published var text = ""
}

private final class ReturnSubmittingTextField: NSTextField {
    var submitHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            submitHandler?()
            return
        }
        super.keyDown(with: event)
    }
}

private struct CaptureTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ReturnSubmittingTextField {
        let field = ReturnSubmittingTextField()
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
        field.submitHandler = onSubmit
        context.coordinator.field = field
        context.coordinator.focusObserver = NotificationCenter.default.addObserver(
            forName: .focusCaptureField,
            object: nil,
            queue: .main
        ) { [weak field] _ in
            field?.window?.makeFirstResponder(field)
        }
        DispatchQueue.main.async { [weak field] in
            field?.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(
        _ field: ReturnSubmittingTextField,
        context: Context
    ) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        field.submitHandler = onSubmit
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    static func dismantleNSView(
        _ field: ReturnSubmittingTextField,
        coordinator: Coordinator
    ) {
        if let observer = coordinator.focusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CaptureTextField
        weak var field: ReturnSubmittingTextField?
        var focusObserver: NSObjectProtocol?

        init(_ parent: CaptureTextField) {
            self.parent = parent
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
            guard commandSelector == #selector(NSResponder.insertNewline(_:))
                    || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            else {
                return false
            }
            parent.onSubmit()
            return true
        }
    }
}

struct QuickCaptureView: View {
    @ObservedObject var store: MemoryStore
    @ObservedObject var localization: LocalizationController
    let syncNow: () -> Void
    let checkForUpdates: () -> Void
    @ObservedObject private var draft = CaptureDraft()

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

            if store.visibleItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 25))
                    Text(localization.text("empty_state"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(mutedInk)
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
        .frame(width: 360)
        .background(paper)
        .foregroundStyle(ink)
        .environment(\.colorScheme, .light)
        .onReceive(
            NotificationCenter.default.publisher(for: .submitCapture)
        ) { _ in
            add()
        }
    }

    private func add() {
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.add(text)
        draft.text = ""
        syncNow()
        NotificationCenter.default.post(name: .focusCaptureField, object: nil)
    }
}

struct MemoryRow: View {
    let item: MemoryItem
    @ObservedObject var store: MemoryStore

    var body: some View {
        HStack(spacing: 9) {
            Button { store.toggle(item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.green : mutedInk)
                    .font(.system(size: 17))
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.isDone ? mutedInk : ink)
                .strikethrough(item.isDone)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)

            Button { store.remove(item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(mutedInk)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
    }
}
