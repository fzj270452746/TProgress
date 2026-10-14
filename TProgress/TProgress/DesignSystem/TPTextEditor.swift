import SwiftUI
import UIKit

// MARK: - Text editor
//
// SwiftUI's TextEditor on iOS 15 keeps an opaque UITextView background and
// offers no API to clear it — the appearance proxy is unreliable once the view
// is inside a hosting controller, which is why the compose field rendered as a
// black slab. This wraps UITextView directly and owns its own placeholder so the
// text and the hint always share one coordinate space.

struct TPTextEditor: View {

    @Binding var text: String
    var placeholder: String
    var height: CGFloat = 140
    var fontSize: CGFloat = 15
    var maxLength: Int?
    var onFocusChange: ((Bool) -> Void)?

    var body: some View {
        // The height is honoured here rather than at the call site. A bare
        // `UIViewRepresentable` wrapping UITextView reports almost no intrinsic
        // height — an empty, scrolled text view measures about one line — so a
        // caller that passed a height without also applying a frame got a
        // twelve-point slot where the writing surface should have been.
        Surface(
            text: $text,
            placeholder: placeholder,
            fontSize: fontSize,
            maxLength: maxLength,
            onFocusChange: onFocusChange
        )
        .frame(height: height)
    }
}

private struct Surface: UIViewRepresentable {

    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat = 15
    var maxLength: Int?
    var onFocusChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = true
        view.showsVerticalScrollIndicator = false
        view.keyboardDismissMode = .interactive
        view.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.font = .systemFont(ofSize: fontSize)
        view.textColor = UIColor(Color.tpCream)
        view.tintColor = UIColor(Color.tpEmber)
        view.delegate = context.coordinator
        view.text = text

        let label = UILabel()
        label.text = placeholder
        label.font = .systemFont(ofSize: fontSize)
        label.textColor = UIColor(Color.tpCreamFaint)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        label.isHidden = !text.isEmpty

        context.coordinator.placeholder = label
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
        }
        context.coordinator.placeholder?.isHidden = !text.isEmpty
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, maxLength: maxLength, onFocusChange: onFocusChange)
    }

    final class Coordinator: NSObject, UITextViewDelegate {

        @Binding private var text: String
        private let maxLength: Int?
        private let onFocusChange: ((Bool) -> Void)?
        weak var placeholder: UILabel?

        init(text: Binding<String>, maxLength: Int?, onFocusChange: ((Bool) -> Void)?) {
            self._text = text
            self.maxLength = maxLength
            self.onFocusChange = onFocusChange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            onFocusChange?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            onFocusChange?(false)
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            placeholder?.isHidden = !textView.text.isEmpty
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            guard let maxLength else { return true }
            let current = textView.text as NSString
            let updated = current.replacingCharacters(in: range, with: replacement)
            return updated.count <= maxLength
        }
    }
}
