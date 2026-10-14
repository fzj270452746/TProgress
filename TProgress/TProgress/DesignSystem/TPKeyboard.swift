import SwiftUI
import UIKit

// MARK: - Keyboard
//
// `scrollDismissesKeyboard` is iOS 16, so dismissal is handled explicitly.

enum TPKeyboard {

    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {

    /// Tapping any non-interactive area of this view resigns first responder.
    /// Child controls keep their own taps — the parent gesture only fires on
    /// empty space, which is exactly the behaviour wanted.
    func tpDismissKeyboardOnTap() -> some View {
        contentShape(Rectangle())
            .onTapGesture { TPKeyboard.dismiss() }
    }

    /// Same, but also resigns when the user starts dragging the content.
    func tpDismissKeyboardOnScroll() -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { _ in TPKeyboard.dismiss() }
        )
    }
}
