import Foundation
import UniformTypeIdentifiers

struct ExportDestinationResolver {
    let exportDirectory: URL?
    let folderStructureRoot: URL?

    func destinationURL(for asset: ImageAsset, uti: UTType) -> URL {
        let currentURL = asset.originalURL
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: uti)
        let tempDirPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let isTempSource = currentURL.standardizedFileURL.path.hasPrefix(tempDirPath)

        let destinationURL: URL
        if let exportDirectory {
            let base = currentURL.deletingPathExtension().lastPathComponent
            if let folderStructureRoot {
                let assetDirectory = currentURL.deletingLastPathComponent().standardizedFileURL
                let sourcePath = folderStructureRoot.standardizedFileURL.path
                let assetPath = assetDirectory.path
                let relative = assetPath.hasPrefix(sourcePath)
                    ? String(assetPath.dropFirst(sourcePath.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    : ""
                let targetDirectory = relative.isEmpty
                    ? exportDirectory
                    : exportDirectory.appendingPathComponent(relative)
                destinationURL = targetDirectory.appendingPathComponent(base + "." + ext)
            } else {
                destinationURL = exportDirectory.appendingPathComponent(base + "." + ext)
            }
        } else if isTempSource {
            let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            let base = currentURL.deletingPathExtension().lastPathComponent
            destinationURL = downloadsDirectory.appendingPathComponent(base + "." + ext)
        } else {
            let directory = currentURL.deletingLastPathComponent()
            let base = currentURL.deletingPathExtension().lastPathComponent
            destinationURL = directory.appendingPathComponent(base + "." + ext)
        }

        return destinationURL
    }
}
