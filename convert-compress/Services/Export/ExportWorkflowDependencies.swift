import Foundation

struct ExportWorkflowDependencies {
    var confirmReplace: @MainActor (_ conflictingURLs: [URL]) -> Bool
    var requestAccess: (_ directory: URL, _ message: String) async -> Bool
    var beginAccess: (_ directory: URL) -> SandboxAccessToken?
    var presentAccessDenied: @MainActor (_ directory: URL) -> Void
    var beginProgress: @MainActor (_ total: Int) -> Void
    var incrementProgress: @MainActor () -> Void
    var recordUsage: @MainActor (_ imageCount: Int) -> Void
    var checkRatingPrompt: @MainActor () -> Void
    var revealInFinder: @MainActor (_ urls: [URL]) -> Void
}
