import SwiftUI
import AppKit

/// AppKit-backed single-line numeric field for controls that mix dragging and inline
/// text editing (e.g. slider pills). It reliably becomes first responder and selects
/// its full contents the moment it appears, draws its caret using the theme's primary
/// (black/white) `labelColor`, and commits on Return/Tab/Escape or focus loss.
///
/// SwiftUI's `TextField` on macOS focuses and selects asynchronously, producing the
/// "first click focuses, second click reveals the caret" behavior with no initial
/// selection. Driving focus and selection from `viewDidMoveToWindow` makes the field
/// behave like a normal text field: a single click selects all, the next click places
/// the caret. Dragging is unaffected because callers gate editing behind their own
/// drag/tap discrimination and only mount this field once editing has begun.
struct InlineNumberField: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
    var alignment: NSTextAlignment = .right
    var onCommit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    func makeNSView(context: Context) -> CaretColorTextField {
        let field = CaretColorTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.alignment = alignment
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        field.stringValue = text
        return field
    }

    func updateNSView(_ nsView: CaretColorTextField, context: Context) {
        context.coordinator.update(onCommit: onCommit)
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.alignment = alignment
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let text: Binding<String>
        private var onCommit: (() -> Void)?
        private var hasCommitted = false

        init(text: Binding<String>, onCommit: (() -> Void)?) {
            self.text = text
            self.onCommit = onCommit
        }

        func update(onCommit: (() -> Void)?) {
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        /// Fires on Return, Tab, Escape, and focus loss (clicking away).
        func controlTextDidEndEditing(_ notification: Notification) {
            guard !hasCommitted else { return }
            hasCommitted = true
            onCommit?()
        }
    }
}

/// `NSTextField` whose field editor draws its caret using the primary label color and
/// that grabs focus + selects all of its text as soon as it joins the window.
final class CaretColorTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome, let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = .labelColor
            // Numeric field: disable text-input services. This also avoids spinning
            // up the out-of-process spell/substitution views that emit the benign
            // "ViewBridge to RemoteViewService Terminated" console message.
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.isContinuousSpellCheckingEnabled = false
            editor.isGrammarCheckingEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticQuoteSubstitutionEnabled = false
        }
        return didBecome
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
            self.currentEditor()?.selectAll(nil)
        }
    }
}
