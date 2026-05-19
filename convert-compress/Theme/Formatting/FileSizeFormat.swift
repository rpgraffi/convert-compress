import Foundation

enum FileSizeFormat {
    static func string(forByteCount bytes: Int) -> String {
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024.0
        let byteCount = Double(bytes)
        if byteCount >= megabyte {
            return String(format: "%.2f MB", byteCount / megabyte)
        }
        if byteCount >= kilobyte {
            return String(format: "%.0f KB", byteCount / kilobyte)
        }
        return "\(bytes) B"
    }
}

