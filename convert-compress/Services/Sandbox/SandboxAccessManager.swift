import Foundation
import AppKit
import OSLog

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

/// Simplified sandbox access manager for macOS App Sandbox.
/// Only stores bookmarks from user-selected directories via NSOpenPanel.
final class SandboxAccessManager {
    static let shared = SandboxAccessManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "raffistudio.image-tools", category: "Sandbox")
    private let bookmarksKey = "sandbox.bookmarks.v2"
    private var bookmarks: [String: Data] = [:]

    private init() {
        if let stored = UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] {
            bookmarks = stored
        }
    }

    // MARK: - Public API

    /// Begins security-scoped access to a directory.
    /// - Returns: Token that must be stopped when done, or nil if access unavailable
    func beginAccess(for directory: URL) -> SandboxAccessToken? {
        let dir = directory.standardizedFileURL
        
        // Try to resolve existing bookmark
        if let bookmarkData = bookmarks[key(for: dir)] {
            if let token = resolveBookmark(bookmarkData, for: dir) {
                return token
            }
        }
        
        // No bookmark or resolution failed - try direct access (works for user-selected files in same session)
        return SandboxAccessToken(url: dir)
    }

    /// Attempts to store a bookmark for a directory if we currently have access to it.
    /// This should be called when files are first imported to preserve access for future exports.
    /// - Parameter directory: The directory to store a bookmark for
    func storeBookmarkIfAccessible(for directory: URL) {
        let dir = directory.standardizedFileURL
        
        // Skip if we already have a bookmark
        if bookmarks[key(for: dir)] != nil {
            return
        }
        
        // Try to create and store a bookmark
        guard let token = SandboxAccessToken(url: dir) else {
            return
        }
        defer { token.stop() }
        
        storeBookmark(for: dir)
    }

    /// Requests access to a directory via NSOpenPanel if needed.
    /// - Parameters:
    ///   - directory: The directory to access
    ///   - message: Custom message for the permission dialog
    /// - Returns: True if access was granted
    @MainActor
    @discardableResult
    func requestAccessIfNeeded(to directory: URL, message: String?) async -> Bool {
        let dir = directory.standardizedFileURL
        
        // Check if we already have access
        if let token = beginAccess(for: dir) {
            token.stop()
            return true
        }

        // Show permission dialog
        let panel = NSOpenPanel()
        panel.message = message ?? String(localized: "Allow access to this folder.")
        panel.prompt = String(localized: "Allow")
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = dir

        guard panel.runModal() == .OK, let selectedURL = panel.urls.first else {
            return false
        }

        // Store bookmark from user-selected directory
        storeBookmark(for: selectedURL.standardizedFileURL)
        
        return true
    }

    // MARK: - Private Helpers

    private func key(for directory: URL) -> String {
        directory.standardizedFileURL.path
    }

    private func resolveBookmark(_ data: Data, for directory: URL) -> SandboxAccessToken? {
        do {
            var isStale = false
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                logger.info("Bookmark stale for \(directory.path, privacy: .public), refreshing...")
                storeBookmark(for: resolved)
            }
            
            return SandboxAccessToken(url: resolved)
        } catch {
            logger.error("Failed to resolve bookmark for \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            removeBookmark(for: directory)
            return nil
        }
    }

    private func storeBookmark(for directory: URL) {
        let dir = directory.standardizedFileURL
        do {
            let data = try dir.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            bookmarks[key(for: dir)] = data
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
            logger.info("Stored bookmark for \(dir.path, privacy: .public)")
        } catch {
            logger.error("Failed to create bookmark for \(dir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeBookmark(for directory: URL) {
        let k = key(for: directory)
        if bookmarks.removeValue(forKey: k) != nil {
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
            logger.info("Removed invalid bookmark for \(directory.path, privacy: .public)")
        }
    }
}

