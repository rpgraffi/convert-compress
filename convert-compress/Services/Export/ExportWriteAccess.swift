import Foundation

struct ExportWriteAccess: Sendable {
    private let scopePaths: Set<String>

    init(scopeDirectories: [URL]) {
        self.scopePaths = Set(scopeDirectories.map { $0.standardizedFileURL.path })
    }

    func allowsWriting(to directory: URL) -> Bool {
        let path = directory.standardizedFileURL.path
        return scopePaths.contains { scopePath in
            path == scopePath || path.hasPrefix(scopePath + "/")
        }
    }
}
