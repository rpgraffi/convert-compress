import Foundation
import AppKit
import SwiftUI
import ImageIO
import StoreKit
import Combine

@MainActor
final class ImageToolsViewModel: ObservableObject {
    
    // MARK: - Images & Comparison State
    
    @Published var images: [ImageAsset] = []
    @Published var comparisonSelection: ComparisonSelection? = nil
    @Published var comparisonPreview: ComparisonPreviewState = .empty
    var comparisonPreviewTask: Task<Void, Never>? = nil
    let liveRenderDebouncer = Debouncer()
    
    // MARK: - Export Configuration
    
    @Published var overwriteOriginals: Bool = false
    @Published var exportDirectory: URL? = nil
    @Published var sourceDirectory: URL? = nil
    
    var isExportingToSource: Bool {
        guard let source = sourceDirectory?.standardizedFileURL else {
            return false
        }
        guard let export = exportDirectory?.standardizedFileURL else {
            return true
        }
        return export == source
    }
    
    // MARK: - Resize Settings
    
    @Published var resizeMode: ResizeMode = .resize
    @Published var resizeWidth: String = ""
    @Published var resizeHeight: String = ""
    @Published var resizeLongEdge: String = ""
    
    // MARK: - Format Settings
    
    @Published var selectedFormat: ImageFormat? = nil
    @Published var allowedSquareSizes: [Int]? = nil
    @Published var restrictionHint: String? = nil
    @Published var recentFormats: [ImageFormat] = []
    
    // MARK: - Transform Settings
    
    @Published var compressionPercent: Double = 0.8
    @Published var flipV: Bool = false
    @Published var removeBackground: Bool = false
    @Published var removeMetadata: Bool = false
    
    // MARK: - Presets
    
    @Published var presets: [Preset] = []
    
    // MARK: - Processed Image Cache
    
    /// Cached processed results from estimation. Reused by clipboard,
    /// comparison, and export to avoid redundant processing.
    @Published var processedCache = ProcessingCache()
    var processingTask: Task<Void, Never>? = nil
    let processingDebouncer = Debouncer()
    
    /// IDs of assets currently visible in the grid, updated by ImagesGridView.
    var visibleAssetIDs: Set<UUID> = []
    
    // MARK: - Export Progress
    
    @Published var exportProgress = ProgressState()
    var exportTask: Task<Void, Never>? = nil

    var isExporting: Bool {
        exportProgress.isActive
    }

    var exportCompleted: Int {
        exportProgress.completed
    }

    var exportTotal: Int {
        exportProgress.total
    }
    
    var exportFraction: Double {
        exportProgress.fraction
    }
    
    // MARK: - Ingestion Progress
    
    @Published var ingestionProgress = ProgressState()

    var ingestFraction: Double {
        ingestionProgress.fraction
    }
    
    var ingestCounterText: String? {
        ingestionProgress.ingestCounterText
    }
    
    // MARK: - Subscriptions
    
    var cancellables = Set<AnyCancellable>()
    var lastConfigurationForSideEffects: ProcessingConfiguration?
    
    // MARK: - Initialization
    
    init() {
        loadPersistedState()
        setupConfigurationChangeObservation()
        setupComparisonObservation()
        setupPersistenceObservation()
        loadPresets()
    }

    // MARK: - Processing Configuration
    
    var currentConfiguration: ProcessingConfiguration {
        // Get format capabilities to normalize unsupported settings
        let caps = selectedFormat.map { ImageIOCapabilities.shared.capabilities(for: $0) }
        
        return ProcessingConfiguration(
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            resizeLongEdge: resizeLongEdge,
            selectedFormat: selectedFormat,
            compressionPercent: caps?.supportsQuality == false ? 0 : compressionPercent,
            flipV: flipV,
            removeMetadata: caps?.supportsMetadata == false ? false : removeMetadata,
            removeBackground: removeBackground
        )
    }
    
}

