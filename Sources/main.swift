import AppKit
import Combine
import ServiceManagement
import Sparkle
import SwiftUI
import WidgetKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var store: MemoryStore!
    private var sync: TailSync!
    private let localization = LocalizationController()
    private let draft = CaptureDraft()
    private var languageObservation: AnyCancellable?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = MemoryStore()
        sync = TailSync(store: store)
        configureStatusItem()
        configurePopover()
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
        sync.start()
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
            button.toolTip = NSLocalizedString("app_name", comment: "")
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.contentViewController = NSHostingController(
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
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
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
        showPopover()
        if let itemID {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .showMemoryItem,
                    object: itemID
                )
            }
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        repositionPopover(below: button)
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self, weak button] in
            guard let self, let button else { return }
            self.repositionPopover(below: button)
            NSApplication.shared.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .focusCaptureField, object: nil)
        }
    }

    private func repositionPopover(below button: NSStatusBarButton) {
        guard let statusWindow = button.window,
              let popoverWindow = popover.contentViewController?.view.window
        else {
            return
        }

        let buttonRect = statusWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        let screenFrame = (statusWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSScreen.screens[0].visibleFrame
        let windowSize = popoverWindow.frame.size
        let margin: CGFloat = 8

        var x = buttonRect.midX - windowSize.width / 2
        x = max(screenFrame.minX + margin, x)
        x = min(screenFrame.maxX - windowSize.width - margin, x)

        let idealY = buttonRect.minY - windowSize.height - 4
        let y = max(screenFrame.minY + margin, idealY)
        popoverWindow.setFrameOrigin(NSPoint(x: x, y: y))
        popoverWindow.makeKeyAndOrderFront(nil)
    }

}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
