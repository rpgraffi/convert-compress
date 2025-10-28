import AppKit
import UniformTypeIdentifiers

enum ClipboardService {
    
    static func copyEncodedImage(data: Data, uti: UTType) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Create pasteboard item with raw data
        let item = NSPasteboardItem()
        let imageType = NSPasteboard.PasteboardType(uti.identifier)
        item.setData(data, forType: imageType)
        
        var objects: [NSPasteboardWriting] = [item]
        
        // Create temporary file for apps that prefer file-based paste
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: uti)
        let filename = "copy-\(String(UUID().uuidString.prefix(8))).\(ext)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        if (try? data.write(to: fileURL, options: [.atomic])) != nil {
            objects.append(fileURL as NSURL)
        }
        
        pasteboard.writeObjects(objects)
    }
    
    /// Reveal file in Finder
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

