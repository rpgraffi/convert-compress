import Foundation

enum FilenameSanitizer {
    static let templateMaxLength = 120
    static let maxFilenameUTF8Bytes = 255
    private static let replacement = "_"

    static func sanitizeTemplateInput(_ value: String, maxLength: Int = templateMaxLength) -> String {
        let sanitized = value.map { character in
            isAllowedFilenameCharacter(character) ? String(character) : replacement
        }.joined()
        return String(sanitized.prefix(maxLength))
    }

    static func sanitizeBasename(_ value: String) -> String {
        value.map { character in
            isAllowedFilenameCharacter(character) ? String(character) : replacement
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimBasename(_ basename: String, filenameExtension: String) -> String {
        let extensionBytes = filenameExtension.isEmpty ? 0 : filenameExtension.utf8.count + 1
        let maxBytes = max(1, maxFilenameUTF8Bytes - extensionBytes)
        var result = ""

        for character in basename {
            let next = String(character)
            guard result.utf8.count + next.utf8.count <= maxBytes else { break }
            result.append(character)
        }

        return result
    }

    private static func isAllowedFilenameCharacter(_ character: Character) -> Bool {
        guard character != "/" && character != ":" else { return false }
        return character.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
    }
}

