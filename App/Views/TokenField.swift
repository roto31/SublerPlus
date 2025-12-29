import SwiftUI
import AppKit
import Foundation
import SublerPlusCore

/// SwiftUI wrapper for NSTokenField
/// Provides token-based input similar to Subler's filename pattern configuration
struct TokenField: NSViewRepresentable {
    @Binding var tokens: [Token]
    
    /// Available tokens for auto-completion
    let availableTokens: [Token]
    
    /// Placeholder text
    let placeholder: String
    
    /// Initialize the token field
    /// - Parameters:
    ///   - tokens: Binding to the token array
    ///   - availableTokens: Available tokens for completion (default: standard filename tokens)
    ///   - placeholder: Placeholder text
    init(tokens: Binding<[Token]>, 
         availableTokens: [Token] = TokenFieldDelegate.defaultTokens,
         placeholder: String = "Enter pattern...") {
        self._tokens = tokens
        self.availableTokens = availableTokens
        self.placeholder = placeholder
    }
    
    func makeNSView(context: Context) -> NSTokenField {
        let tokenField = NSTokenField()
        tokenField.delegate = context.coordinator.tokenDelegate
        tokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        tokenField.placeholderString = placeholder
        
        // Set initial value
        tokenField.objectValue = tokens
        
        // Accessibility support
        tokenField.setAccessibilityLabel("Token field")
        tokenField.setAccessibilityRole(.textField)
        if !placeholder.isEmpty {
            tokenField.setAccessibilityHelp(placeholder)
        }
        
        return tokenField
    }
    
    func updateNSView(_ nsView: NSTokenField, context: Context) {
        // Update tokens if they've changed externally
        if let currentValue = nsView.objectValue as? [Token],
           currentValue != tokens {
            nsView.objectValue = tokens
        }
        
        // Update accessibility value with current token count
        let tokenCount = tokens.filter { $0.isPlaceholder }.count
        let textCount = tokens.filter { !$0.isPlaceholder }.count
        if tokenCount > 0 || textCount > 0 {
            let value = "\(tokenCount) token\(tokenCount == 1 ? "" : "s"), \(textCount) text segment\(textCount == 1 ? "" : "s")"
            nsView.setAccessibilityValue(value)
        } else {
            nsView.setAccessibilityValue(nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tokens: $tokens, availableTokens: availableTokens)
    }
    
    class Coordinator: NSObject, TokenChangeObserver {
        @Binding var tokens: [Token]
        let tokenDelegate: TokenFieldDelegate
        
        init(tokens: Binding<[Token]>, availableTokens: [Token]) {
            self._tokens = tokens
            self.tokenDelegate = TokenFieldDelegate(
                displayMenu: true,
                displayString: { token in
                    // Format token names for display (remove braces, add spaces)
                    let name = token.tokenName
                    // Convert camelCase to "Title Case"
                    let formatted = name.replacingOccurrences(
                        of: "([a-z])([A-Z])",
                        with: "$1 $2",
                        options: .regularExpression
                    )
                    return formatted.capitalized
                },
                availableTokens: availableTokens
            )
            super.init()
            self.tokenDelegate.delegate = self
        }
        
        @MainActor
        func tokenDidChange(_ obj: Notification?) {
            // Extract tokens from the notification's object (the NSTokenField)
            if let tokenField = obj?.object as? NSTokenField,
               let newTokens = tokenField.objectValue as? [Token] {
                tokens = newTokens
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TokenField_Previews: PreviewProvider {
    @State static var tokens: [Token] = [
        Token(text: "{ShowName}", isPlaceholder: true),
        Token(text: " - S", isPlaceholder: false),
        Token(text: "{Season}", isPlaceholder: true),
        Token(text: "E", isPlaceholder: false),
        Token(text: "{Episode}", isPlaceholder: true),
        Token(text: " - ", isPlaceholder: false),
        Token(text: "{Title}", isPlaceholder: true)
    ]
    
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TV Naming Pattern")
                .font(.headline)
            TokenField(tokens: $tokens, placeholder: "Enter pattern...")
                .frame(height: 24)
            Text("Example: Breaking Bad - S01E02 - Cat's in the Bag")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 500)
    }
}
#endif

