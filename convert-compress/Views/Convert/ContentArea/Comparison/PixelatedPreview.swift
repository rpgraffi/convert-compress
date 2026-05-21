import SwiftUI

/// Shows a diagonal pixelated blur wave over the source image while
/// the processed result is being rendered. Uses a Metal shader for
/// GPU-accelerated sampling — no CPU-side image work at all.
struct PixelatedPreview: View {
    let sourceImage: NSImage
    let cropRegion: CGRect?
    let displaySize: CGSize
    let displayOffset: CGPoint
    let imageFrameSize: CGSize
    let sliderPosition: CGFloat
    @ObservedObject var zoomPanState: ZoomPanState

    private let pixelSize: CGFloat = 10
    private let minBlurRadius: CGFloat = 0.75
    private let maxBlurRadius: CGFloat = 18
    private let waveLength: CGFloat = 180

    @State private var startDate = Date()

    private var sampleOffset: CGFloat {
        pixelSize / 2 + maxBlurRadius
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)

            GeometryReader { geo in
                imageContent
                    .layerEffect(
                        ShaderLibrary.pixelate(
                            .float(Float(elapsed)),
                            .float(Float(pixelSize)),
                            .float(Float(minBlurRadius)),
                            .float(Float(maxBlurRadius)),
                            .float(Float(waveLength)),
                            .float2(Float(displaySize.width), Float(displaySize.height))
                        ),
                        maxSampleOffset: CGSize(width: sampleOffset, height: sampleOffset)
                    )
                    .clipped()
                    .overlay {
                        if cropRegion != nil {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .strokeBorder(.secondary, lineWidth: 0.5)
                        }
                    }
                    .offset(x: displayOffset.x, y: displayOffset.y)
                    .scaleEffect(zoomPanState.scale, anchor: .center)
                    .offset(x: zoomPanState.offset.x, y: zoomPanState.offset.y)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .drawingGroup(opaque: false, colorMode: .nonLinear)
                    .mask(alignment: .trailing) {
                        Rectangle()
                            .frame(width: (1.0 - sliderPosition) * geo.size.width)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let cropRegion {
            Image(nsImage: sourceImage)
                .resizable()
                .scaledToFit()
                .frame(width: imageFrameSize.width, height: imageFrameSize.height)
                .offset(
                    x: imageFrameSize.width * (0.5 - cropRegion.midX),
                    y: imageFrameSize.height * (0.5 - cropRegion.midY)
                )
                .frame(width: displaySize.width, height: displaySize.height)
        } else {
            Image(nsImage: sourceImage)
                .resizable()
                .scaledToFit()
                .frame(width: displaySize.width, height: displaySize.height)
        }
    }
}
