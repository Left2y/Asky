import AppKit
import SwiftUI
import ToolService

extension View {
    func appDialog(_ title: String, isPresented: Binding<Bool>, message: String,
                   buttons: [String], onResponse: @escaping (Int) -> Void = { _ in }) -> some View {
        modifier(AppDialogModifier(title: title, isPresented: isPresented,
                                   message: message, buttons: buttons, onResponse: onResponse))
    }
}

private struct AppDialogModifier: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    let message: String
    let buttons: [String]
    let onResponse: (Int) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: isPresented) { _, presented in
            guard presented else { return }
            Task { @MainActor in
                guard isPresented else { return }
                let alert = AppDialog.make()
                alert.messageText = title
                alert.informativeText = message
                for (index, title) in buttons.enumerated() {
                    let button = alert.addButton(withTitle: title)
                    if index == 0 { button.keyEquivalent = "\r" }
                    else if index == buttons.count - 1 { button.keyEquivalent = "\u{1b}" }
                }
                NSApp.activate()
                let response = await AppDialog.present(alert)
                isPresented = false
                onResponse(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
            }
        }
    }
}
