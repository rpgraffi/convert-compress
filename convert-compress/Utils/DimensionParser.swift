import Foundation

// MARK: - Dimension Parsing

/// Parses dimension strings in various formats and extracts width and height values.
///
/// Supported formats:
/// - `680x340`, `680X340`, `680×340`
/// - `680 x 340`, `680 X 340` (with spaces)
/// - `680*340` (asterisk, common for "by")
/// - `680-340`, `680‐340` (hyphen/en dash, from copy-pasted text)
/// - `680.340`, `680_340` (from filenames)
/// - `680 340` (space separator)
/// - `680/340`, `680:340`, `680,340`
/// - Any combination with extra spaces
///
/// - Parameter text: The input string potentially containing dimensions
/// - Returns: A tuple `(width: String, height: String)` if valid dimensions are found, otherwise `nil`
func parseDimensions(from text: String) -> (width: String, height: String)? {
    // Pattern matches: <number><separator><number>
    // Separators: x, X, ×, *, /, :, comma, dot, underscore, hyphen, space, or combinations with spaces
    let pattern = #"^\s*(\d+)\s*[xX×/:,*._\s-]+\s*(\d+)\s*$"#
    
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
          match.numberOfRanges == 3 else {
        return nil
    }
    
    // Extract width and height
    guard let widthRange = Range(match.range(at: 1), in: text),
          let heightRange = Range(match.range(at: 2), in: text) else {
        return nil
    }
    
    let width = String(text[widthRange])
    let height = String(text[heightRange])
    
    return (width: width, height: height)
}

