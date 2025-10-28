import SwiftUI

extension Binding where Value == String {
    /// Creates a binding that limits the string to a maximum character count
    func charLimit(_ maxLength: Int) -> Binding<String> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = String(newValue.prefix(maxLength))
            }
        )
    }
}

