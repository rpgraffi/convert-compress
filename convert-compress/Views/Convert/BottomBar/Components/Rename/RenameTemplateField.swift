import SwiftUI
import AppKit

struct RenameTemplateField: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorOffset: Int
    @Binding var requestedCursorOffset: Int?
    @Binding var isFocused: Bool
    let placeholder: String

    private let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            cursorOffset: $cursorOffset,
            requestedCursorOffset: $requestedCursorOffset,
            isFocused: $isFocused,
            font: font
        )
    }

    func makeNSView(context: Context) -> RenameTemplateNSTextField {
        let field = RenameTemplateNSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        field.placeholderString = placeholder
        field.stringValue = text
        context.coordinator.field = field
        context.coordinator.applyHighlighting(to: field)
        return field
    }

    func updateNSView(_ nsView: RenameTemplateNSTextField, context: Context) {
        context.coordinator.update(
            text: $text,
            cursorOffset: $cursorOffset,
            requestedCursorOffset: $requestedCursorOffset,
            isFocused: $isFocused
        )
        nsView.placeholderString = placeholder
        nsView.font = font

        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.currentEditor() == nil {
            context.coordinator.applyHighlighting(to: nsView)
        } else {
            context.coordinator.applyHighlightingToEditor(for: nsView)
        }

        let shouldFocus = isFocused && nsView.currentEditor() == nil
        if shouldFocus || requestedCursorOffset != nil {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                if shouldFocus {
                    window.makeFirstResponder(nsView)
                }

                guard let editor = nsView.currentEditor() as? NSTextView else { return }
                let fallbackOffset = (nsView.stringValue as NSString).length
                let offset = requestedCursorOffset ?? fallbackOffset
                let location = min(max(offset, 0), fallbackOffset)
                if editor.selectedRange() != NSRange(location: location, length: 0) {
                    editor.setSelectedRange(NSRange(location: location, length: 0))
                }
                cursorOffset = location
                requestedCursorOffset = nil
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var cursorOffset: Binding<Int>
        var requestedCursorOffset: Binding<Int?>
        var isFocused: Binding<Bool>
        let font: NSFont
        weak var field: RenameTemplateNSTextField?

        init(
            text: Binding<String>,
            cursorOffset: Binding<Int>,
            requestedCursorOffset: Binding<Int?>,
            isFocused: Binding<Bool>,
            font: NSFont
        ) {
            self.text = text
            self.cursorOffset = cursorOffset
            self.requestedCursorOffset = requestedCursorOffset
            self.isFocused = isFocused
            self.font = font
            super.init()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(selectionDidChange(_:)),
                name: NSTextView.didChangeSelectionNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func update(
            text: Binding<String>,
            cursorOffset: Binding<Int>,
            requestedCursorOffset: Binding<Int?>,
            isFocused: Binding<Bool>
        ) {
            self.text = text
            self.cursorOffset = cursorOffset
            self.requestedCursorOffset = requestedCursorOffset
            self.isFocused = isFocused
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isFocused.wrappedValue = true
            guard let field = notification.object as? RenameTemplateNSTextField else { return }
            applyHighlightingToEditor(for: field)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? RenameTemplateNSTextField else { return }
            let selectedRange = (field.currentEditor() as? NSTextView)?.selectedRange() ?? NSRange(location: field.stringValue.count, length: 0)
            let sanitized = FilenameSanitizer.sanitizeTemplateInput(field.stringValue)

            if sanitized != field.stringValue {
                field.stringValue = sanitized
                if let editor = field.currentEditor() as? NSTextView {
                    let location = min(selectedRange.location, (sanitized as NSString).length)
                    editor.setSelectedRange(NSRange(location: location, length: 0))
                }
            }

            text.wrappedValue = sanitized
            cursorOffset.wrappedValue = (field.currentEditor() as? NSTextView)?.selectedRange().location ?? (sanitized as NSString).length
            applyHighlightingToEditor(for: field)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            isFocused.wrappedValue = false
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return true
            }
            return false
        }

        func applyHighlighting(to field: NSTextField) {
            field.attributedStringValue = highlightedString(field.stringValue)
        }

        func applyHighlightingToEditor(for field: NSTextField) {
            guard let editor = field.currentEditor() as? NSTextView,
                  let storage = editor.textStorage else { return }
            let selected = editor.selectedRange()
            let text = editor.string
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            storage.setAttributes(baseAttributes, range: fullRange)

            for match in RenameTokenParser.matches(in: text) {
                storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: NSRange(match.range, in: text))
            }
            if editor.selectedRange() != selected {
                editor.setSelectedRange(selected)
            }
        }

        private func highlightedString(_ value: String) -> NSAttributedString {
            let attributed = NSMutableAttributedString(string: value, attributes: baseAttributes)
            for match in RenameTokenParser.matches(in: value) {
                attributed.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: NSRange(match.range, in: value))
            }
            return attributed
        }

        private var baseAttributes: [NSAttributedString.Key: Any] {
            [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        }

        @objc private func selectionDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView,
                  editor === field?.currentEditor() else { return }
            let location = editor.selectedRange().location
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cursorOffset.wrappedValue = location
            }
        }
    }
}

final class RenameTemplateNSTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome, let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = .labelColor
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.isContinuousSpellCheckingEnabled = false
            editor.isGrammarCheckingEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticQuoteSubstitutionEnabled = false
        }
        return didBecome
    }
}

