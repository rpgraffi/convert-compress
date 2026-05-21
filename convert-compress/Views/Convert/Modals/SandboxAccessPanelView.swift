import AppKit
import Foundation

struct SandboxAccessPanelView: Sendable {
    @MainActor
    func requestAccess(to directory: URL, message: String?) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message ?? String(localized: "Allow access to this folder.")
        panel.prompt = String(localized: "Allow")
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = directory

        guard panel.runModal() == .OK, let url = panel.urls.first else {
            return nil
        }
        return url.standardizedFileURL
    }
}
