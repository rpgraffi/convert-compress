import AppKit
import Foundation

struct ExportAlertView {
    @MainActor
    func confirmReplace(conflictingURLs: [URL]) -> Bool {
        let parentDirs = Set(conflictingURLs.map { $0.deletingLastPathComponent().path })
        let folderHintPath = parentDirs.count == 1 ? parentDirs.first : nil
        let message = String(localized: "Replace existing files?")
        let count = conflictingURLs.count
        let info = replacementInfoText(folderHintPath: folderHintPath, count: count)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = info

        let replaceButton = alert.addButton(withTitle: String(localized: "Replace"))
        replaceButton.hasDestructiveAction = true

        alert.addButton(withTitle: String(localized: "Cancel"))
        if let icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
            alert.icon = icon
        }

        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    func presentAccessDenied(for directory: URL) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(localized: "Permission needed")
        alert.informativeText = String(localized: "\(AppConstants.localizedAppName) needs access to save files in \(directory.lastPathComponent). Please choose Allow when prompted.")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func replacementInfoText(folderHintPath: String?, count: Int) -> String {
        if let folderHintPath {
            let folderName = FileManager.default.displayName(atPath: folderHintPath)
            if count == 1 {
                return String(format: String(localized: "1 file already exists in \"%@\". Replacing will overwrite it."), folderName)
            }
            return String(format: String(localized: "%d files already exist in \"%@\". Replacing will overwrite them."), count, folderName)
        }

        if count == 1 {
            return String(localized: "1 file with the same name already exists. Replacing will overwrite it.")
        }
        return String(format: String(localized: "%d files with the same name already exist. Replacing will overwrite them."), count)
    }
}
