import Foundation

/// Manages security-scoped access to a URL. Automatically stops access on deinit.
final class SandboxAccessToken {
    let url: URL
    private var isAccessing = false

    init?(url: URL) {
        guard url.isFileURL else { return nil }
        self.url = url.standardizedFileURL
        self.isAccessing = self.url.startAccessingSecurityScopedResource()
    }

    func stop() {
        if isAccessing {
            url.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    deinit {
        stop()
    }
}

/// Manages directory access permissions for macOS App Sandbox.
/// Prompts users when write access is needed.
actor SandboxAccessManager {
    static let shared = SandboxAccessManager()

    private var grantedDirectories: Set<String> = []

    private init() {}

    /// Begins security-scoped access to a URL.
    nonisolated func beginAccess(for url: URL) -> SandboxAccessToken? {
        SandboxAccessToken(url: url.standardizedFileURL)
    }

    /// Ensures we have write access to a directory, prompting user if needed.
    @discardableResult
    func requestAccessIfNeeded(
        to directory: URL,
        message: String?,
        panelView: SandboxAccessPanelView = SandboxAccessPanelView()
    ) async -> Bool {
        let dir = directory.standardizedFileURL
        
        // Already granted in this session?
        if isGranted(dir.path) {
            return true
        }
        
        // Can we already write here?
        if canWrite(to: dir) {
            markGranted(dir.path)
            AppLogger.sandbox.info("Directory accessible: \(dir.path, privacy: .public)")
            return true
        }

        let selected = await panelView.requestAccess(to: dir, message: message)
        
        guard let selected else {
            AppLogger.sandbox.warning("Access denied: \(dir.path, privacy: .public)")
            return false
        }

        markGranted(selected.path)
        AppLogger.sandbox.info("Access granted: \(selected.path, privacy: .public)")
        return true
    }
    
    private func isGranted(_ path: String) -> Bool {
        grantedDirectories.contains(path)
    }
    
    private func markGranted(_ path: String) {
        grantedDirectories.insert(path)
    }

    /// Tests if we can write to a directory by attempting to create a temporary file.
    nonisolated private func canWrite(to directory: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        let testFile = directory.appendingPathComponent(".write_test_\(UUID().uuidString)")
        let token = SandboxAccessToken(url: directory)
        defer { token?.stop() }
        
        do {
            try Data().write(to: testFile)
            try FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            return false
        }
    }
}
