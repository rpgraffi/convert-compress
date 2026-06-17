import Foundation

struct ExportRenameSettings: Equatable {
    var isEnabled: Bool
    var template: String
    var dateFormatPreset: RenameDateFormatPreset

    static let disabled = ExportRenameSettings(
        isEnabled: false,
        template: "",
        dateFormatPreset: .dayMonthYearDots
    )

    var sanitizedTemplate: String {
        FilenameSanitizer.sanitizeTemplateInput(template)
    }
}

