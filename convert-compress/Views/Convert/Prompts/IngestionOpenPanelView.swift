import AppKit
import Foundation
import UniformTypeIdentifiers

struct IngestionOpenPanelView: Sendable {
    @MainActor
    func present(
        allowsDirectories: Bool = true,
        allowsMultiple: Bool = true,
        allowedContentTypes: [UTType] = [.image],
        completion: @escaping ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowsDirectories
        panel.allowedContentTypes = allowedContentTypes

        guard panel.runModal() == .OK else { return }

        let expanded = panel.urls.flatMap { url in
            IngestionCoordinator.expandToSupportedImageURLs(from: url.standardizedFileURL)
        }
        completion(expanded)
    }
}
