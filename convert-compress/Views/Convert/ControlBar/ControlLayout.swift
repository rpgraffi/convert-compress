import CoreGraphics

/// Derived layout sizes for the convert control bar and main window minimum width.
enum ControlLayout {
    private static let mainWindowMinWidthFloor: CGFloat = 760
    private static let formatPlaceholderMinWidth: CGFloat = 92
    private static let controlsBarSpacingCount: CGFloat = 6

    static var defaultControlsBarMinWidth: CGFloat {
        ControlsBar.Layout.horizontalPadding * 2
            + ControlsBar.Layout.spacing * controlsBarSpacingCount
            + Theme.Metrics.controlHeight
            + formatPlaceholderMinWidth
            + resizeControlMinWidth(includesModeToggle: true)
            + Theme.Metrics.controlMinWidth
            + Theme.Metrics.controlHeight
            + Theme.Metrics.controlHeight
            + MetadataControl.Layout.minWidth
    }

    static var mainWindowMinWidth: CGFloat {
        max(mainWindowMinWidthFloor, defaultControlsBarMinWidth)
    }

    static func resizeControlMinWidth(includesModeToggle: Bool) -> CGFloat {
        ResizeControl.Layout.pillMinWidth + modeToggleWidth(includesModeToggle: includesModeToggle)
    }

    static func resizeControlMaxWidth(includesModeToggle: Bool) -> CGFloat {
        Theme.Metrics.controlMaxWidth + modeToggleWidth(includesModeToggle: includesModeToggle)
    }

    private static func modeToggleWidth(includesModeToggle: Bool) -> CGFloat {
        guard includesModeToggle else { return 0 }
        return ResizeControl.Layout.pillSpacing + Theme.Metrics.controlHeight
    }
}
