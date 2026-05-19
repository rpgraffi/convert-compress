import AppKit

enum KeyWindowEditing {
    static var isTextInputFocused: Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else {
            return false
        }
        return firstResponder is NSText || firstResponder is NSTextField
    }

    /// Selects all text in the currently focused text field.
    static func selectAllText() {
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
        }
    }
}
