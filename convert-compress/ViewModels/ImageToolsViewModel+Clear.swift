import SwiftUI

extension ImageToolsViewModel {
    var hasExportedAndNewImages: Bool {
        let hasExported = images.contains { $0.isEdited }
        let hasNew = images.contains { !$0.isEdited }
        return hasExported && hasNew
    }

    func clearAll() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
            images.removeAll()
        }
        encodedOutputCache.removeAll()
        if exportDirectory == nil {
            sourceDirectory = nil
        }
        comparisonSelection = nil
    }

    func clearExported() {
        let exportedIDs = Set(images.filter(\.isEdited).map(\.id))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
            images.removeAll { $0.isEdited }
        }
        for id in exportedIDs {
            encodedOutputCache.removeValue(forKey: id)
        }
        if comparisonSelection.map({ exportedIDs.contains($0.assetID) }) == true {
            comparisonSelection = nil
        }
    }
}
