import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var widgetPanel: NSPanel!
    private var store: MemoryStore!
    private var sync: TailSync!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = MemoryStore()
        sync = TailSync(store: store)
        configureStatusItem()
        configurePopover()
        configureDesktopWidget()
        sync.start()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile.fill", accessibilityDescription: "Aklıma Geldi")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "Aklıma Geldi"
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: QuickCaptureView(store: store) { [weak self] in self?.sync.syncNow() }
        )
    }

    private func configureDesktopWidget() {
        let view = DesktopWidgetView(store: store) { [weak self] in self?.showPopover() }
        let controller = NSHostingController(rootView: view)
        let size = NSSize(width: 288, height: 260)
        widgetPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        widgetPanel.contentViewController = controller
        widgetPanel.isOpaque = false
        widgetPanel.backgroundColor = .clear
        widgetPanel.hasShadow = true
        widgetPanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        widgetPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        widgetPanel.isMovableByWindowBackground = true
        widgetPanel.hidesOnDeactivate = false
        positionWidget()
        widgetPanel.orderFrontRegardless()
    }

    private func positionWidget() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        widgetPanel?.setFrameOrigin(NSPoint(
            x: frame.maxX - 310,
            y: frame.minY + 24
        ))
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
