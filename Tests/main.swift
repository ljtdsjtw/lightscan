import AppKit
import CoreImage

let context = CIContext()
let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/fixtures")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var passed = 0

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
    print("PASS: \(message)")
}

func qr(_ text: String) -> CGImage {
    let filter = CIFilter(name: "CIQRCodeGenerator")!
    filter.setValue(Data(text.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    let scaled = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    let padded = scaled.extent.insetBy(dx: -32, dy: -32)
    let background = CIImage(color: .white).cropped(to: padded)
    return context.createCGImage(scaled.composited(over: background), from: padded)!
}

func save(_ image: CGImage, _ filename: String) throws -> URL {
    let destination = directory.appendingPathComponent(filename)
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: destination)
    return destination
}

let examples = [
    "https://example.com/scan?source=lightscan&value=42",
    "你好，这是离线扫码测试。🍵",
    "WIFI:T:WPA;S:Test Network;P:sample-only-123;;",
    "第一行\n第二行\n第三行",
    "plain text 0123456789"
]
for (index, text) in examples.enumerated() {
    let url = try save(qr(text), "qr-\(index).png")
    let decoded = try QRScanner.read(QRScanner.image(at: url))
    check(decoded == [text], "二维码内容完整往返：样例 \(index + 1)")
}

let canvas = CGContext(data: nil, width: 1000, height: 600, bitsPerComponent: 8,
                       bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
canvas.setFillColor(CGColor(gray: 1, alpha: 1))
canvas.fill(CGRect(x: 0, y: 0, width: 1000, height: 600))
let blank = canvas.makeImage()!
check(try QRScanner.read(blank).isEmpty, "无二维码图片返回空结果")
_ = try save(blank, "blank.png")
canvas.interpolationQuality = .none
for (index, text) in [examples[0], examples[1], examples[0]].enumerated() {
    let x = CGFloat(index) * 320 + 20
    canvas.draw(qr(text), in: CGRect(x: x, y: 130, width: 300, height: 300))
}
let multiple = canvas.makeImage()!
_ = try save(multiple, "multiple.png")
let decoded = try QRScanner.read(multiple)
check(Set(decoded) == Set([examples[0], examples[1]]) && decoded.count == 2, "多二维码识别并去重")

check(QRScanner.webURL("https://example.com/path") != nil, "允许手动打开 HTTPS 链接")
for value in ["javascript:alert(1)", "file:///tmp/test", "WIFI:T:WPA;;", "https://", "plain text"] {
    check(QRScanner.webURL(value) == nil, "普通文本和非网页协议不启用打开按钮：\(value)")
}

let broken = directory.appendingPathComponent("broken.png")
try Data("not an image".utf8).write(to: broken)
do {
    _ = try QRScanner.image(at: broken)
    check(false, "损坏图片应返回错误")
} catch {
    check(error is ScannerError, "损坏图片返回可读错误")
}

print("\(passed) checks passed. Fixtures: \(directory.path)")
