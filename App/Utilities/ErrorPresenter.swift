import SwiftUI
import AppKit

/// Utility for presenting user-friendly error dialogs following HIG guidelines
@MainActor
class ErrorPresenter {
    /// Present an error dialog to the user
    /// - Parameters:
    ///   - error: The error to display
    ///   - window: Optional window to present the error relative to
    ///   - title: Optional custom title (defaults to "Operation Failed")
    static func showError(_ error: Error, in window: NSWindow? = nil, title: String = "Operation Failed") {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        
        // Add recovery suggestion if available
        if let localizedError = error as? LocalizedError,
           let recoverySuggestion = localizedError.recoverySuggestion {
            alert.informativeText += "\n\n\(recoverySuggestion)"
        }
        
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        // Present relative to window if provided
        if let window = window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
    
    /// Present a confirmation dialog
    /// - Parameters:
    ///   - message: The message to display
    ///   - informativeText: Additional informative text
    ///   - window: Optional window to present relative to
    ///   - completion: Completion handler with the response (true for OK/Yes, false for Cancel/No)
    static func showConfirmation(
        message: String,
        informativeText: String = "",
        in window: NSWindow? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if let window = window {
            alert.beginSheetModal(for: window) { response in
                completion(response == .alertFirstButtonReturn)
            }
        } else {
            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn)
        }
    }
    
    /// Present a warning dialog
    /// - Parameters:
    ///   - message: The warning message
    ///   - informativeText: Additional informative text
    ///   - window: Optional window to present relative to
    static func showWarning(
        message: String,
        informativeText: String = "",
        in window: NSWindow? = nil
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if let window = window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
}

/// Wrapper for Error that conforms to Equatable for use in SwiftUI onChange
struct ErrorWrapper: Equatable {
    let id: UUID
    let description: String
    
    static func == (lhs: ErrorWrapper, rhs: ErrorWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

/// SwiftUI view modifier for error presentation
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    let title: String
    @State private var errorWrapper: ErrorWrapper?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: errorWrapper) { newWrapper in
                if let wrapper = newWrapper, let currentError = error {
                    ErrorPresenter.showError(currentError, title: title)
                    // Clear error after presentation
                    DispatchQueue.main.async {
                        self.error = nil
                        self.errorWrapper = nil
                    }
                }
            }
            .onChange(of: error?.localizedDescription) { newDescription in
                if let newDescription = newDescription, let currentError = error {
                    errorWrapper = ErrorWrapper(id: UUID(), description: newDescription)
                } else {
                    errorWrapper = nil
                }
            }
    }
}

extension View {
    /// Add error alert presentation to a view
    /// - Parameters:
    ///   - error: Binding to optional error
    ///   - title: Title for error dialog
    func errorAlert(error: Binding<Error?>, title: String = "Operation Failed") -> some View {
        modifier(ErrorAlertModifier(error: error, title: title))
    }
}

