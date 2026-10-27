import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = base * scale
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let side = CGFloat(size)
        NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.93, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: side * 0.05, y: side * 0.05, width: side * 0.9, height: side * 0.9),
                     xRadius: side * 0.20, yRadius: side * 0.20).fill()
        let module = side * 0.047
        func block(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: NSColor) {
            color.setFill()
            NSBezierPath(rect: NSRect(x: side * 0.193 + CGFloat(x) * module,
                                     y: side * 0.193 + CGFloat(y) * module,
                                     width: CGFloat(width) * module, height: CGFloat(height) * module)).fill()
        }
        for (x, y) in [(0, 8), (8, 8), (0, 0)] {
            block(x, y, 5, 5, .white)
            block(x + 1, y + 1, 3, 3, NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.93, alpha: 1))
            block(x + 2, y + 2, 1, 1, .white)
        }
        for (x, y) in [(6, 0), (8, 0), (9, 1), (11, 0), (12, 2), (8, 3), (10, 4), (12, 5), (6, 6), (4, 6), (2, 6), (0, 6), (6, 9), (6, 12)] {
            block(x, y, 1, 1, .white)
        }
        image.unlockFocus()
        let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try representation.representation(using: .png, properties: [:])!
            .write(to: directory.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}
