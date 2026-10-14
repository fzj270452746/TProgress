import SwiftUI
import UIKit

// MARK: - Icon
//
// Every icon in the app resolves as: asset catalogue first, SF Symbol second.
// That single rule is what makes the artwork pack a drop-in — add
// `circle_deep_reading` to the catalogue and the circle picks it up on the next
// launch, with the symbol still carrying the design until then.

enum TPIconResolver {

    static func image(named name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        return UIImage(named: name)
    }

    /// A picked photo arrives as an absolute path; packaged art arrives as a
    /// catalogue name. Both land here.
    static func image(pathOrName value: String?) -> UIImage? {
        guard let value, !value.isEmpty else { return nil }

        if value.contains("/") {
            guard FileManager.default.fileExists(atPath: value) else { return nil }
            return UIImage(contentsOfFile: value)
        }
        return UIImage(named: value)
    }
}

struct TPIcon: View {

    /// A catalogue asset name, or an SF Symbol name.
    let name: String
    /// Used when `name` is a catalogue name that has not been supplied yet, so
    /// the design keeps a real glyph until the artwork pack lands.
    var fallbackSymbol: String?
    var size: CGFloat = 17
    var tint: Color = .tpCream

    var body: some View {
        Group {
            if let image = TPIconResolver.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(tint)
                    .frame(width: size, height: size)
            } else if UIImage(systemName: name) != nil {
                symbol(name)
            } else if let fallbackSymbol, UIImage(systemName: fallbackSymbol) != nil {
                symbol(fallbackSymbol)
            } else {
                symbol("circle")
            }
        }
    }

    private func symbol(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.92, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
    }
}
