import SwiftUI

// MARK: - Buttons

/// The single call to action. Ember gradient, capsule, springs under the finger.
struct TPPrimaryButton: View {

    let title: String
    var symbol: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var fullWidth: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard isEnabled, !isLoading else { return }
            TPHaptic.thump()
            action()
        }) {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.tpOnAccent)
                        .scaleEffect(0.8)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .bold))
                }

                Text(title)
                    .font(TPFont.ui(17, .bold))
            }
            .foregroundColor(isEnabled ? .tpOnAccent : .tpCreamFaint)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 56)
            .padding(.horizontal, fullWidth ? 0 : 30)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled
                          ? AnyShapeStyle(TPGradient.ember)
                          : AnyShapeStyle(Color.tpGlassWell))
                    .overlay(
                        // A highlight across the top edge, so the pill reads as
                        // a lit object rather than a flat fill.
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.10)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .tpEmberGlow(isEnabled ? .tpEmber : .clear, strength: isEnabled ? 0.45 : 0)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(TPMotion.snappy, value: isEnabled)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    withAnimation(TPMotion.press) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(TPMotion.press) { pressed = false }
                }
        )
    }
}

/// Outline companion for secondary actions.
struct TPOutlineButton: View {

    let title: String
    var symbol: String?
    var fullWidth: Bool = true
    var tint: Color = .tpCream
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            TPHaptic.tap()
            action()
        }) {
            HStack(spacing: 9) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(TPFont.ui(16, .semibold))
            }
            .foregroundColor(tint)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 56)
            .padding(.horizontal, fullWidth ? 0 : 26)
            .tpGlass(radius: 28, strength: 0.13)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(TPMotion.press) { pressed = true } }
                .onEnded { _ in withAnimation(TPMotion.press) { pressed = false } }
        )
    }
}

/// Text-only action for tertiary affordances.
struct TPQuietButton: View {

    let title: String
    var tint: Color = .tpEmber
    var size: CGFloat = 14.5
    let action: () -> Void

    var body: some View {
        Button(action: {
            TPHaptic.tap()
            action()
        }) {
            Text(title)
                .font(TPFont.ui(size, .semibold))
                .foregroundColor(tint)
        }
        .buttonStyle(.plain)
    }
}

/// Circular icon button used in headers and toolbars.
struct TPIconButton: View {

    let symbol: String
    var size: CGFloat = 38
    var tint: Color = .tpCream
    var background: Color = .tpGlass
    var bordered: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            TPHaptic.tap()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(background)
                    }
                    .overlay(
                        Circle().strokeBorder(
                            bordered ? Color.white.opacity(0.30) : Color.clear,
                            lineWidth: 1
                        )
                    )
                )
                .scaleEffect(pressed ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(TPMotion.press) { pressed = true } }
                .onEnded { _ in withAnimation(TPMotion.press) { pressed = false } }
        )
    }
}

// MARK: - Fields

/// Underlined input. The rule warms to ember while the field holds focus.
struct TPTextField: View {

    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .next
    var symbol: String?
    var errorText: String?
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text.tpLabel(label, size: 10.5, tracking: 1.9)

            HStack(spacing: 11) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(focused ? .tpEmber : .tpCreamFaint)
                        .frame(width: 18)
                }

                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(TPFont.ui(15.5))
                            .foregroundColor(.tpCreamFaint)
                    }

                    Group {
                        if isSecure {
                            SecureField("", text: $text)
                        } else {
                            TextField("", text: $text)
                        }
                    }
                    .font(TPFont.ui(15.5))
                    .foregroundColor(.tpCream)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(isSecure ? .never : capitalization)
                    .autocorrectionDisabled(true)
                    .focused($focused)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .tint(.tpEmber)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .tpGlass(radius: 17, strength: focused ? 0.19 : 0.11, shadowed: false)
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(
                        errorText != nil
                            ? AnyShapeStyle(Color.tpBloom.opacity(0.85))
                            : (focused
                               ? AnyShapeStyle(TPGradient.ember)
                               : AnyShapeStyle(Color.clear)),
                        lineWidth: 1.4
                    )
                    .animation(TPMotion.snappy, value: focused)
            )

            if let errorText {
                Text(errorText)
                    .font(TPFont.ui(12, .medium))
                    .foregroundColor(.tpDanger)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Tags, chips, segments

struct TPTag: View {

    let text: String
    var color: Color = .tpEmber
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            // Unfilled tags carry their colour in a dot rather than in the
            // glyphs. Coloured text on a bare 13% wash was invisible the moment
            // the tag colour and the backdrop happened to agree.
            if !filled {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }

            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.tpCream)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            if filled {
                Capsule(style: .continuous).fill(TPGradient.accent(color))
            } else {
                ZStack {
                    Capsule(style: .continuous).fill(.ultraThinMaterial)
                    Capsule(style: .continuous).fill(Color.white.opacity(0.12))
                }
            }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(filled ? 0.38 : 0.22), lineWidth: 1)
        }
    }
}

struct TPSelectableChip: View {

    let text: String
    let isSelected: Bool
    var symbol: String?
    var assetName: String?
    let action: () -> Void

    var body: some View {
        Button(action: {
            TPHaptic.tap()
            action()
        }) {
            HStack(spacing: 6) {
                if assetName != nil || symbol != nil {
                    TPIcon(
                        name: assetName ?? symbol ?? "",
                        fallbackSymbol: symbol,
                        size: 14,
                        tint: isSelected ? .tpOnAccent : .tpCreamDim
                    )
                }
                Text(text)
                    .font(.system(size: 13.5, weight: .bold))
            }
            .foregroundColor(isSelected ? .tpOnAccent : .tpCreamDim)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background {
                // Selected chips are the gradient itself, never glass — a
                // material over the fill would frost the one element that is
                // meant to read as a solid lit object.
                if isSelected {
                    Capsule(style: .continuous).fill(TPGradient.ember)
                } else {
                    ZStack {
                        Capsule(style: .continuous).fill(.ultraThinMaterial)
                        Capsule(style: .continuous).fill(Color.white.opacity(0.11))
                    }
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.40 : 0.26), lineWidth: 1)
            }
            .tpEmberGlow(isSelected ? .tpEmber : .clear, strength: isSelected ? 0.35 : 0)
        }
        .buttonStyle(.plain)
    }
}

/// Sliding segmented control. The indicator travels with matched geometry.
struct TPSegmented<Item: Hashable & Identifiable>: View {

    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items) { item in
                let isSelected = item == selection
                Button(action: {
                    TPHaptic.tap()
                    withAnimation(TPMotion.spring) { selection = item }
                }) {
                    Text(title(item))
                        .font(TPFont.ui(13.5, .bold))
                        .foregroundColor(isSelected ? .tpOnAccent : .tpCreamDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule(style: .continuous)
                                        .fill(TPGradient.ember)
                                        .matchedGeometryEffect(id: "tp.segment", in: namespace)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .tpGlass(radius: 21, strength: 0.10, shadowed: false)
    }
}

// MARK: - Structure

struct TPSectionHeader: View {

    let label: String
    var title: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text.tpLabel(label)
                if let title {
                    Text(title)
                        .font(TPFont.display(24, .bold))
                        .foregroundColor(.tpCream)
                }
            }
            Spacer(minLength: 12)
            if let actionTitle, let action {
                TPQuietButton(title: actionTitle, tint: .tpEmber, size: 13, action: action)
            }
        }
    }
}

struct TPStatTile: View {

    let value: String
    let caption: String
    var color: Color = .tpCream
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                }
                Text.tpFigure(value, size: 25, color: color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Four tiles across a phone leaves little room; the caption shrinks
            // rather than colliding with its neighbour.
            Text.tpLabel(caption, size: 9, tracking: 0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TPEmptyState: View {

    var glyph: AnyView?
    var symbol: String?
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var accent: Color = .tpEmber

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                TPHalo(color: accent, diameter: 150)

                if let glyph {
                    glyph
                        .foregroundColor(accent)
                        .frame(width: 46, height: 46)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(accent)
                }
            }

            VStack(spacing: 7) {
                Text(title)
                    .font(TPFont.display(21, .bold))
                    .foregroundColor(.tpCream)

                Text(message)
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)

            if let actionTitle, let action {
                TPPrimaryButton(title: actionTitle, fullWidth: false, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Bottom sheet
//
// `.presentationDetents` is iOS 16, so the app carries its own panel. Same
// spring, same grabber, same dimming everywhere.

private struct BottomSheetModifier<Panel: View>: ViewModifier {

    @Binding var isPresented: Bool
    let panel: Panel

    @State private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                // Tinted with the app's own violet rather than neutral black:
                // black drains the saturation out of the backdrop instead of
                // pushing it back.
                Color(hex: 0x14082B).opacity(0.42)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { close() }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.tpCreamFaint.opacity(0.5))
                            .frame(width: 40, height: 4.5)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                        panel
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        // Glass, not paint. An opaque panel under a dimmed
                        // backdrop put a hard edge across the gradient and
                        // broke the one rule the palette sets for itself.
                        ZStack {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color(hex: 0x2A1170).opacity(0.60))
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(TPGradient.glassEdge, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .offset(y: max(0, dragOffset))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = max(0, value.translation.height)
                            }
                            .onEnded { value in
                                if value.translation.height > 110 || value.predictedEndTranslation.height > 240 {
                                    close()
                                } else {
                                    withAnimation(TPMotion.spring) { dragOffset = 0 }
                                }
                            }
                    )
                    .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(900)
            }
        }
        .animation(TPMotion.gentle, value: isPresented)
    }

    private func close() {
        withAnimation(TPMotion.gentle) {
            dragOffset = 0
            isPresented = false
        }
    }
}

extension View {

    func tpSheet<Panel: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder panel: () -> Panel
    ) -> some View {
        modifier(BottomSheetModifier(isPresented: isPresented, panel: panel()))
    }
}

// MARK: - Sheet page

extension View {

    /// A sheet centres a root view that has no flexible height, which leaves a
    /// short panel floating in the middle of a full height sheet. This pins the
    /// content to the top and gives it the app's ground.
    func tpSheetPage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .tpBackdrop(.deep)
            .preferredColorScheme(.dark)
    }
}

// MARK: - Rows

/// Standard settings-style row: icon well, title, optional detail, chevron.
struct TPRow: View {

    let symbol: String
    let title: String
    var detail: String?
    var accent: Color = .tpCreamDim
    var showsChevron: Bool = true
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            TPHaptic.tap()
            action()
        }) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(accent.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accent)
                }

                Text(title)
                    .font(TPFont.ui(15, .medium))
                    .foregroundColor(isDestructive ? .tpDanger : .tpCream)

                Spacer(minLength: 8)

                if let detail {
                    Text(detail)
                        .font(TPFont.ui(13.5))
                        .foregroundColor(.tpCreamFaint)
                        .lineLimit(1)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.tpCreamFaint)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation chrome

/// Header used by every pushed page. Keeps the custom dock-free look consistent.
struct TPPageHeader: View {

    let title: String
    var subtitle: String?
    var onBack: (() -> Void)?
    var trailing: AnyView?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack {
                TPIconButton(symbol: "chevron.left", size: 38, action: onBack)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TPFont.display(25, .bold))
                    .foregroundColor(.tpCream)
                    .lineLimit(1)
                if let subtitle {
                    Text.tpLabel(subtitle, size: 10, tracking: 1.6)
                }
            }

            Spacer(minLength: 8)

            if let trailing { trailing }
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }
}
