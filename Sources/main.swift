import AppKit
import Combine
import ServiceManagement
import Sparkle
import SwiftUI
import WidgetKit

private final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let capturePanel = CapturePanel(
        contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var store: MemoryStore!
    private var sync: TailSync!
    private let localization = LocalizationController()
    private let draft = CaptureDraft()
    private var languageObservation: AnyCancellable?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private let showcaseMode = ProcessInfo.processInfo.arguments.contains("--showcase")
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = showcaseMode
            ? MemoryStore(
                initialItems: [
                    MemoryItem(text: "Review the DAAK NODE release", folder: .tasks),
                    MemoryItem(text: "Save the book list for offline reading", folder: .notes),
                    MemoryItem(text: "Mail • weekly project summary", folder: .mail),
                ],
                saveItems: { _ in }
            )
            : MemoryStore()
        sync = TailSync(store: store)
        configureStatusItem()
        configureCapturePanel()
        configureMouseMonitors()
        registerLaunchAtLogin()
        languageObservation = localization.$language.sink { [weak self] _ in
            guard let self else { return }
            self.statusItem.button?.toolTip = self.localization.text("app_name")
            WidgetCenter.shared.reloadAllTimelines()
        }
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        if showcaseMode {
            store.markSyncReady()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showCapturePanel()
            }
        } else {
            sync.start()
        }
    }

    private func registerLaunchAtLogin() {
        let service = SMAppService.mainApp
        guard service.status == .notRegistered else { return }
        do {
            try service.register()
        } catch {
            NSLog("daakREMEMBER login item registration failed: %@", error.localizedDescription)
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile.fill", accessibilityDescription: "daakREMEMBER")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.refusesFirstResponder = true
            button.sendAction(on: [.leftMouseUp])
            button.toolTip = NSLocalizedString("app_name", comment: "")
        }
    }

    private func configureCapturePanel() {
        capturePanel.level = .popUpMenu
        capturePanel.isFloatingPanel = true
        capturePanel.hidesOnDeactivate = false
        capturePanel.isReleasedWhenClosed = false
        capturePanel.hasShadow = true
        capturePanel.backgroundColor = .clear
        capturePanel.isOpaque = false
        capturePanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
        ]
        capturePanel.contentViewController = NSHostingController(
            rootView: QuickCaptureView(
                store: store,
                localization: localization,
                draft: draft,
                syncNow: { [weak self] in self?.sync.syncNow() },
                checkForUpdates: { [weak self] in
                    self?.updaterController.checkForUpdates(nil)
                }
            )
        )
        capturePanel.contentView?.wantsLayer = true
        capturePanel.contentView?.layer?.cornerRadius = 12
        capturePanel.contentView?.layer?.masksToBounds = true
    }

    private func configureMouseMonitors() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, self.capturePanel.isVisible else { return event }
            let statusWindow = self.statusItem.button?.window
            if event.window !== self.capturePanel && event.window !== statusWindow {
                self.capturePanel.orderOut(nil)
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.capturePanel.orderOut(nil)
            }
        }
    }

    @objc private func togglePopover() {
        if let event = NSApplication.shared.currentEvent,
           event.type == .keyDown || event.type == .keyUp
        {
            return
        }
        if capturePanel.isVisible {
            capturePanel.orderOut(nil)
        } else {
            showCapturePanel()
        }
    }

    @objc private func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        let itemID = event.paramDescriptor(
            forKeyword: keyDirectObject
        )?.stringValue.flatMap { value -> UUID? in
            guard let url = URL(string: value),
                  url.host == "item",
                  let idText = url.pathComponents.dropFirst().first
            else {
                return nil
            }
            return UUID(uuidString: idText)
        }
        showCapturePanel()
        if let itemID {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .showMemoryItem,
                    object: itemID
                )
            }
        }
    }

    private func showCapturePanel() {
        guard let button = statusItem.button else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        repositionCapturePanel(below: button)
        capturePanel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .focusCaptureField, object: nil)
        DispatchQueue.main.async { [weak self, weak button] in
            guard let self, let button else { return }
            NSApplication.shared.activate(ignoringOtherApps: true)
            self.repositionCapturePanel(below: button)
            self.capturePanel.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .focusCaptureField, object: nil)
        }
    }

    private func repositionCapturePanel(below button: NSStatusBarButton) {
        guard let statusWindow = button.window else { return }

        let buttonRect = statusWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        let screenFrame = (statusWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSScreen.screens[0].visibleFrame
        let windowSize = capturePanel.frame.size
        let margin: CGFloat = 8

        var x = buttonRect.midX - windowSize.width / 2
        x = max(screenFrame.minX + margin, x)
        x = min(screenFrame.maxX - windowSize.width - margin, x)

        let idealY = buttonRect.minY - windowSize.height - 4
        let y = max(screenFrame.minY + margin, idealY)
        capturePanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
