import AppKit
import SwiftUI

/// Comparison view with zoom, pan, and slider functionality
///
/// Gestures:
/// - Pinch: Zoom toward cursor position
/// - Two-finger scroll (trackpad): Pan in all directions
/// - Drag: Pan when zoomed
/// - Handle drag: Move comparison slider
/// - Mouse wheel + Option: Zoom (for mouse users)
/// - Keyboard: Space/Esc (close), arrows (navigate), C (toggle comparison)
struct ComparisonView: View {
    @Environment(EncodedOutputModule.self) private var encodedOutput
    @Environment(ComparisonSessionModule.self) private var comparison
    let asset: ImageAsset
    let heroNamespace: Namespace.ID
    
    @State private var sliderPosition: CGFloat = 0.5
    @State private var showUI: Bool = false
    @State private var previousPosition: CGFloat = 0.5
    @State private var keyEventMonitor: LocalEventMonitor?
    @StateObject private var zoomPanState = ZoomPanState()
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastPointerLocation: CGPoint = .zero
    @State private var handleDragStartPosition: CGFloat? = nil
    @State private var longPressActive: Bool = false
    
    private var preview: ComparisonPreviewState { comparison.comparisonPreview }
    private var fileName: String { asset.originalURL.lastPathComponent }
    
    private var mainContent: some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let imageFrame = calculateImageFrame(containerSize: containerSize)
            
            ZStack {
                // Main content with clipping
                ZStack {
                    comparisonContent(
                        containerSize: containerSize,
                        imageFrame: imageFrame
                    )
                }
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .matchedGeometryEffect(
                    id: "hero-\(asset.id)",
                    in: heroNamespace,
                )
                
                // Handle overlay
                if showUI {
                    ComparisonSplitHandle()
                    .position(
                        x: sliderPosition * containerSize.width,
                        y: containerSize.height / 2
                    )
                    .gesture(
                        handleDragGesture(containerSize: containerSize)
                    )
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.8))
                    )
                    .allowsHitTesting(true)
                }
            }
            .overlay(alignment: .top) {
                if showUI {
                    ComparisonTop(
                        asset: asset,
                        heroNamespace: heroNamespace,
                        sliderPosition: $sliderPosition,
                        zoomPanState: zoomPanState
                    )
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if showUI {
                    ComparisonBottom(displayInfo: encodedOutput.displayInfo(for: asset))
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity)
                        )
                }
            }
            .onChange(of: containerSize) { _, newSize in
                updateZoomPanContainer(size: newSize, imageFrame: imageFrame)
            }
            .onChange(of: imageFrame.size) { _, _ in
                updateZoomPanContainer(size: containerSize, imageFrame: imageFrame)
            }
            .onChange(of: preview.processedSize) { _, _ in
                // Update 1:1 zoom calculation when processed size changes (e.g., resize)
                updateZoomPanContainer(size: containerSize, imageFrame: imageFrame)
            }
        }
    }
    
    var body: some View {
        mainContent
            .comparisonScrollHandler(zoomPanState: zoomPanState)
            .onAppear {
            sliderPosition = 0.5
            comparison.refreshComparisonPreview()
            withAnimation(Theme.Animations.fastSpring()) {
                showUI = true
            }
            installKeyMonitor()
        }
        .onChange(of: asset.id) { _, _ in
            sliderPosition = 0.5
            zoomPanState.reset(animated: false)
            comparison.refreshComparisonPreview()
        }
        .onChange(of: preview.processedImage) { _, newImage in
            if newImage != nil {
                encodedOutput.scheduleProcessing()
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .focusable()
        .focusEffectDisabled()
    }
    
    private func comparisonContent(containerSize: CGSize, imageFrame: CGRect) -> some View {
        ZStack {
            // Container for zoomed/panned images
            ZStack {
                // Original image layer with zoom/pan
                originalImageLayer(imageFrame: imageFrame)
                
                // Pixelated preview while processing
                if preview.isLoading && preview.processedImage == nil && showUI,
                   let originalImage = preview.originalImage {
                    pixelatedPreviewLayer(
                        sourceImage: originalImage,
                        imageFrame: imageFrame
                    )
                    .id(ObjectIdentifier(originalImage))
                    .transition(.opacity)
                }
                
                // Processed image layer with zoom/pan and crop alignment
                if let processedImage = preview.processedImage, showUI {
                    processedImageLayer(
                        image: processedImage,
                        imageFrame: imageFrame
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    lastPointerLocation = location
                case .ended:
                    break
                }
            }
            .onTapGesture(count: 1) {
                sliderPosition = min(max(0, lastPointerLocation.x / containerSize.width), 1)
            }
            .onTapGesture(count: 2) {
                // Toggle between fit and 1:1 pixel zoom
                zoomPanState.toggleActualSize(animated: true)
            }
            .onLongPressGesture(minimumDuration: 0.15, pressing: { isPressing in
                if !isPressing && longPressActive {
                    longPressActive = false
                    sliderPosition = 0.0
                }
            }, perform: {
                longPressActive = true
                sliderPosition = 1.0
            })
            .gesture(panGesture())
            .simultaneousGesture(magnificationGesture(containerSize: containerSize))
        }
    }
    
    private func originalImageLayer(imageFrame: CGRect) -> some View {
        GeometryReader { geo in
            Group {
                if let image = preview.originalImage ?? asset.thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .scaleEffect(zoomPanState.scale, anchor: .center)
                        .offset(x: zoomPanState.offset.x, y: zoomPanState.offset.y)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .drawingGroup(opaque: false, colorMode: .nonLinear)
                } else {
                    Color.clear
                }
            }
        }
    }
    
    private func processedImageLayer(image: NSImage, imageFrame: CGRect) -> some View {
        let cropAlignment = cropAlignment(
            imageFrame: imageFrame,
            cropRegion: preview.cropRegion,
            requireProcessedSize: true
        )
        let isCropped = preview.cropRegion != nil
        
        return GeometryReader { geo in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: cropAlignment.size.width, height: cropAlignment.size.height)
                .overlay {
                    if isCropped {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.secondary, lineWidth: 0.5)
                            .frame(width: cropAlignment.size.width, height: cropAlignment.size.height)
                    }
                }
                .offset(x: cropAlignment.offset.x, y: cropAlignment.offset.y)
                .scaleEffect(zoomPanState.scale, anchor: .center)
                .offset(x: zoomPanState.offset.x, y: zoomPanState.offset.y)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .drawingGroup(opaque: false, colorMode: .nonLinear)
                .mask(alignment: .trailing) {
                    Rectangle()
                        .frame(width: (1.0 - sliderPosition) * geo.size.width)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .trailing
                        )
                }
        }
    }
    
    // MARK: - Pixelated Preview Layer
    
    private func pixelatedPreviewLayer(sourceImage: NSImage, imageFrame: CGRect) -> some View {
        let cropAlignment = cropAlignment(imageFrame: imageFrame, cropRegion: preview.cropRegion)
        
        return PixelatedPreview(
            sourceImage: sourceImage,
            cropRegion: preview.cropRegion,
            displaySize: cropAlignment.size,
            displayOffset: cropAlignment.offset,
            imageFrameSize: imageFrame.size,
            sliderPosition: sliderPosition,
            zoomPanState: zoomPanState
        )
    }
    
    // MARK: - Crop Alignment
    
    /// Maps a normalized crop region onto the displayed image frame.
    /// Returns the full image size with zero offset when there is no crop.
    private func cropAlignment(imageFrame: CGRect, cropRegion: CGRect?, requireProcessedSize: Bool = false) -> (size: CGSize, offset: CGPoint) {
        guard let cropRegion,
              let originalSize = preview.originalSize,
              !requireProcessedSize || preview.processedSize != nil else {
            return (size: imageFrame.size, offset: .zero)
        }
        
        let scale = CGSize(
            width: imageFrame.width / originalSize.width,
            height: imageFrame.height / originalSize.height
        )
        
        let cropDisplaySize = CGSize(
            width: originalSize.width * cropRegion.width * scale.width,
            height: originalSize.height * cropRegion.height * scale.height
        )
        
        let offset = CGPoint(
            x: cropRegion.origin.x * imageFrame.width + cropDisplaySize.width / 2 - imageFrame.width / 2,
            y: cropRegion.origin.y * imageFrame.height + cropDisplaySize.height / 2 - imageFrame.height / 2
        )
        
        return (size: cropDisplaySize, offset: offset)
    }
    
    // MARK: - Zoom/Pan Helpers
    
    private func updateZoomPanContainer(size: CGSize, imageFrame: CGRect) {
        // Use processed size for 1:1 zoom when available (e.g., after resize)
        // Fall back to original size if no processed image yet
        let actualSize = preview.processedSize ?? preview.originalSize
        
        zoomPanState.updateContainerAndImage(
            containerSize: size,
            imageSize: imageFrame.size,
            actualPixelSize: actualSize
        )
    }
    
    // MARK: - Gesture Handlers
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = CGSize(
                    width: value.location.x - lastDragLocation.x,
                    height: value.location.y - lastDragLocation.y
                )
                if lastDragLocation != .zero {
                    zoomPanState.pan(by: delta)
                }
                lastDragLocation = value.location
            }
            .onEnded { _ in
                lastDragLocation = .zero
            }
    }
    
    private func handleDragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Calculate position relative to container, accounting for initial click offset
                let adjustedX = value.location.x - (handleDragStartPosition ?? 0)
                let normalized = min(max(0, adjustedX / containerSize.width), 1)
                
                // Trigger haptic when reaching a boundary
                if (normalized == 0 && previousPosition > 0) || (normalized == 1 && previousPosition < 1) {
                    Haptics.alignment()
                }
                
                previousPosition = normalized
                sliderPosition = normalized
            }
            .onEnded { _ in
                handleDragStartPosition = nil
            }
    }
    
    private func magnificationGesture(containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { [zoomPanState] value in
                // Use last tracked pointer location, or center (0,0) if not tracked
                let centerX = containerSize.width / 2
                let centerY = containerSize.height / 2
                let pointerInView = lastPointerLocation != .zero ? lastPointerLocation : CGPoint(x: centerX, y: centerY)
                
                // Convert to offset from center for the zoom calculation
                let offsetFromCenter = CGPoint(
                    x: pointerInView.x - centerX,
                    y: pointerInView.y - centerY
                )
                
                // Initialize magnification on first change
                if zoomPanState.lastMagnification == 1.0 && value != 1.0 {
                    zoomPanState.beginMagnification()
                }
                
                zoomPanState.updateMagnification(value, atOffsetFromCenter: offsetFromCenter)
            }
            .onEnded { [zoomPanState] _ in
                zoomPanState.endMagnification()
                
                // Haptic feedback when crossing 100% zoom
                if abs(zoomPanState.scale - zoomPanState.baseScale) < 0.05 {
                    Haptics.alignment()
                }
            }
    }
    
    // MARK: - Image Frame Calculation
    
    /// Calculates the frame of the fitted image within the container.
    /// Always uses original image to prevent view shrinking when cropping.
    private func calculateImageFrame(containerSize: CGSize) -> CGRect {
        guard let image = preview.originalImage ?? asset.thumbnail,
              image.size.width > 0, image.size.height > 0
        else {
            return CGRect(origin: .zero, size: containerSize)
        }
        
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        let fittedSize = imageAspect > containerAspect
            ? CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
            : CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
        
        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )
        
        return CGRect(origin: origin, size: fittedSize)
    }
    
    // MARK: - Keyboard Handling
    
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = LocalEventMonitor(mask: .keyDown) { event in
            if KeyWindowEditing.isTextInputFocused {
                return event
            }
            
            switch event.keyCode {
            case 49, 53: // Spacebar or Escape
                comparison.dismissComparison()
                return nil
            case 123: // Left arrow
                comparison.navigateToPreviousImage()
                return nil
            case 124: // Right arrow
                comparison.navigateToNextImage()
                return nil
            case 8: // C key - toggle comparison slider
                sliderPosition = sliderPosition < 0.5 ? 1.0 : 0.0
                return nil
            case 18: // 1 key - toggle 1:1 actual size zoom
                zoomPanState.toggleActualSize()
                Haptics.alignment()
                return nil
            default:
                return event
            }
        }
        keyEventMonitor?.start()
    }
    
    private func removeKeyMonitor() {
        keyEventMonitor?.stop()
        keyEventMonitor = nil
    }
}
