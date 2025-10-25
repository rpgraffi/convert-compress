import Foundation

struct PipelineBuilder {
    func build(configuration: ProcessingConfiguration, exportDirectory: URL?) -> ProcessingPipeline {
        var pipeline = ProcessingPipeline()
        pipeline.removeMetadata = configuration.removeMetadata
        pipeline.exportDirectory = exportDirectory
        pipeline.finalFormat = configuration.selectedFormat
        pipeline.compressionPercent = configuration.compressionPercent

        let widthInt = Int(configuration.resizeWidth)
        let heightInt = Int(configuration.resizeHeight)
        let longEdgeInt = Int(configuration.resizeLongEdge)
        
        // Handle resize or crop based on mode
        if configuration.resizeMode == .crop, let w = widthInt, let h = heightInt {
            // Both dimensions filled in crop mode: CropOperation handles resize + crop internally
            pipeline.add(CropOperation(targetWidth: w, targetHeight: h))
        } else if let longEdge = longEdgeInt {
            // Long side mode: resize based on the longest dimension
            pipeline.add(ResizeOperation(mode: .longEdge(longEdge)))
        } else if widthInt != nil || heightInt != nil {
            // One or both dimensions filled in resize mode, or only one dimension in crop mode: resize maintaining aspect ratio
            pipeline.add(ResizeOperation(mode: .pixels(width: widthInt, height: heightInt)))
        }

        // Enforce format-specific size constraints before conversion
        if let fmt = configuration.selectedFormat {
            let caps = ImageIOCapabilities.shared
            if caps.sizeRestrictions(forUTType: fmt.utType) != nil {
                pipeline.add(ConstrainSizeOperation(targetFormat: fmt))
            }
        }

        // Compression handled at final export via pipeline.compressionPercent

        // Flip
        if configuration.flipV { pipeline.add(FlipVerticalOperation()) }

        // Remove background
        if configuration.removeBackground { pipeline.add(RemoveBackgroundOperation()) }

        return pipeline
    }
}


