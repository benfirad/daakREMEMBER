import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let background = NSBezierPath(roundedRect: rect.insetBy(dx: 64, dy: 64), xRadius: 220, yRadius: 220)
NSColor(calibratedRed: 0.96, green: 0.69, blue: 0.16, alpha: 1).setFill()
background.fill()

let glow = NSBezierPath(ovalIn: NSRect(x: 145, y: 400, width: 730, height: 730))
NSColor(calibratedWhite: 1, alpha: 0.18).setFill()
glow.fill()

if let symbol = NSImage(systemSymbolName: "brain.head.profile.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 530, weight: .bold)
    let configured = symbol.withSymbolConfiguration(config) ?? symbol
    NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.11, alpha: 1).set()
    configured.draw(
        in: NSRect(x: 247, y: 235, width: 530, height: 530),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Icon could not be generated")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
