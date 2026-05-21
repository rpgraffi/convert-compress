import Foundation

enum ResizeDimensionParser {
    /// Parses dimension strings in various formats and extracts width and height values.
    ///
    /// Supported formats include `680x340`, `680 x 340`, `680*340`, `680-340`,
    /// `680.340`, `680_340`, `680 340`, `680/340`, `680:340`, and `680,340`.
    static func parse(_ text: String) -> (width: String, height: String)? {
        let pattern = #"^\s*(\d+)\s*[xX×/:,*._\s-]+\s*(\d+)\s*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 3 else {
            return nil
        }

        guard let widthRange = Range(match.range(at: 1), in: text),
              let heightRange = Range(match.range(at: 2), in: text) else {
            return nil
        }

        return (
            width: String(text[widthRange]),
            height: String(text[heightRange])
        )
    }
}

