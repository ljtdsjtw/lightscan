import AppKit
import Vision
import ImageIO

enum ScannerError: LocalizedError {
    case unreadableImage
    var errorDescription: String? { "无法读取这张图片，请换一张 PNG、JPEG 或其他常见格式的图片。" }
}

enum QRScanner {
    static func read(_ image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        var seen = Set<String>()
        return (request.results ?? [])
            .sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.05 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            .compactMap(\.payloadStringValue)
            .filter { seen.insert($0).inserted }
    }

    static func image(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScannerError.unreadableImage
        }
        return image
    }

    static func webURL(_ text: String) -> URL? {
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
