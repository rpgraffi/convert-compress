import Foundation

enum MaxFileSize {
    /// KB = 1024 bytes, same as `FileSizeFormat`.
    static let stopsKB = [20, 50, 100, 150, 200, 250, 300, 400, 500, 750, 1024, 1536, 2048, 3072, 4096, 5120]
    static let qualityRange = 0.01...0.9

    /// Highest quality whose file fits, or the smallest file when none does.
    static func fit(maxByteCount: Int, encode: (Double) throws -> Data) throws -> Data {
        var low = qualityRange.lowerBound
        var high = qualityRange.upperBound
        let top = try encode(high)
        guard top.count > maxByteCount else { return top }
        var best = try encode(low)
        guard best.count <= maxByteCount else { return best }

        for _ in 0..<6 {
            try Task.checkCancellation()
            let mid = (low + high) / 2
            let data = try encode(mid)
            if data.count <= maxByteCount {
                best = data
                low = mid
            } else {
                high = mid
            }
        }
        return best
    }

    static func showsMB(_ kilobytes: Int) -> Bool {
        kilobytes >= 1024
    }

    static func number(_ kilobytes: Int) -> String {
        guard showsMB(kilobytes) else { return "\(kilobytes)" }
        return (Double(kilobytes) / 1024).formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...2)))
    }

    static func unit(_ kilobytes: Int) -> String {
        showsMB(kilobytes) ? "MB" : "KB"
    }

    static func label(_ kilobytes: Int) -> String {
        "\(number(kilobytes)) \(unit(kilobytes))"
    }

    /// A bare number uses the shown unit; "500 kb" or "1,5m" picks its own.
    static func kilobytes(from text: String, shownInMB: Bool) -> Int? {
        let input = text.lowercased().replacingOccurrences(of: ",", with: ".").filter { !$0.isWhitespace }
        let number = input.prefix { $0.isNumber || $0 == "." }
        let inMB: Bool
        switch input.dropFirst(number.count) {
        case "": inMB = shownInMB
        case "k", "kb": inMB = false
        case "m", "mb": inMB = true
        default: return nil
        }
        guard let value = Double(number) else { return nil }
        let kilobytes = (inMB ? value * 1024 : value).rounded()
        guard kilobytes >= 1, kilobytes <= 10 * 1024 * 1024 else { return nil }
        return Int(kilobytes)
    }
}
