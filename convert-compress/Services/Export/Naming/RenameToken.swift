import Foundation

enum RenameToken: Equatable {
    case originalName
    case today
    case created
    case modified
    case indexUp(width: Int)
    case indexDown(width: Int)
    case width
    case height
    case quality

    var text: String {
        switch self {
        case .originalName:
            "$&"
        case .today:
            "$today"
        case .created:
            "$created"
        case .modified:
            "$modified"
        case .indexUp(let width):
            "$" + String(repeating: "n", count: width)
        case .indexDown(let width):
            "$" + String(repeating: "N", count: width)
        case .width:
            "$w"
        case .height:
            "$h"
        case .quality:
            "$q"
        }
    }
}

struct RenameTokenMatch: Equatable {
    let token: RenameToken
    let range: Range<String.Index>
}

enum RenameTokenParser {
    static func matches(in template: String) -> [RenameTokenMatch] {
        var result: [RenameTokenMatch] = []
        var index = template.startIndex

        while index < template.endIndex {
            guard template[index] == "$" else {
                index = template.index(after: index)
                continue
            }

            if let match = matchToken(in: template, at: index) {
                result.append(match)
                index = match.range.upperBound
            } else {
                index = template.index(after: index)
            }
        }

        return result
    }

    private static func matchToken(in template: String, at dollarIndex: String.Index) -> RenameTokenMatch? {
        let afterDollar = template.index(after: dollarIndex)
        guard afterDollar < template.endIndex else { return nil }

        if template[afterDollar] == "&" {
            let end = template.index(after: afterDollar)
            return RenameTokenMatch(token: .originalName, range: dollarIndex..<end)
        }

        if template[afterDollar] == "n" || template[afterDollar] == "N" {
            let marker = template[afterDollar]
            var end = afterDollar
            var width = 0
            while end < template.endIndex, template[end] == marker {
                width += 1
                end = template.index(after: end)
            }
            return RenameTokenMatch(
                token: marker == "n" ? .indexUp(width: width) : .indexDown(width: width),
                range: dollarIndex..<end
            )
        }

        for (literal, token) in wordTokens {
            guard template[afterDollar...].hasPrefix(literal) else { continue }
            let end = template.index(afterDollar, offsetBy: literal.count)
            return RenameTokenMatch(token: token, range: dollarIndex..<end)
        }

        return nil
    }

    private static let wordTokens: [(String, RenameToken)] = [
        ("today", .today),
        ("created", .created),
        ("modified", .modified),
        ("w", .width),
        ("h", .height),
        ("q", .quality)
    ]
}

