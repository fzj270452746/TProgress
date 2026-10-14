import SwiftUI

// MARK: - Report
//
// One reporting surface for posts, replies, profiles and threads. The outcome
// tells the caller whether the page underneath still has anything to show.

struct ReportView: View {

    let target: ReportTarget
    let onFinish: (ReportOutcome) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var isSubmitting = false

    @State private var noteFocused = false

    private var subjectLabel: String {
        switch target {
        case .post:         return "Post"
        case .comment:      return "Reply"
        case .user:         return "Profile"
        case .conversation: return "Conversation"
        }
    }

    var body: some View {
        ZStack {
            TPBackdropView(style: .deep)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    reasonList

                    if reason != nil {
                        noteField
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    submitButton
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.top, 8)
                .padding(.bottom, 44)
            }
            .tpDismissKeyboardOnTap()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text.tpLabel("Report \(subjectLabel)")
                    Text(target.subjectName)
                        .font(TPFont.display(24, .bold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                TPIconButton(symbol: "xmark", size: 36, tint: .tpCreamDim) { dismiss() }
            }

            Text("Reports are reviewed against our community rules. Choosing to block also removes everything this account posted from your view.")
                .font(TPFont.ui(13.5))
                .foregroundColor(.tpCreamDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    // MARK: Reasons

    private var reasonList: some View {
        VStack(spacing: 9) {
            ForEach(ReportReason.allCases) { option in
                reasonRow(option)
            }
        }
    }

    private func reasonRow(_ option: ReportReason) -> some View {
        let isSelected = reason == option

        return Button(action: {
            TPHaptic.tap()
            withAnimation(TPMotion.snappy) {
                reason = isSelected ? nil : option
            }
        }) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(option.isDestructive ? Color.tpBloom.opacity(0.14) : Color.tpEmber.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: option.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(option.isDestructive ? .tpBloom : .tpEmber)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(TPFont.ui(15, .semibold))
                        .foregroundColor(.tpCream)

                    Text(option.detail)
                        .font(TPFont.ui(12.5))
                        .foregroundColor(.tpCreamFaint)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                selectionMark(isSelected, destructive: option.isDestructive)
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(isSelected ? Color.tpInkWell : Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? (option.isDestructive ? Color.tpBloom.opacity(0.6) : Color.tpEmber.opacity(0.6))
                            : Color.tpLine,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func selectionMark(_ isSelected: Bool, destructive: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? (destructive ? Color.tpBloom : Color.tpEmber) : Color.tpLine,
                    lineWidth: 1.5
                )
                .frame(width: 21, height: 21)

            if isSelected {
                Circle()
                    .fill(destructive ? Color.tpBloom : Color.tpEmber)
                    .frame(width: 11, height: 11)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: Note

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text.tpLabel("Add a note")

            TPTextEditor(
                text: $note,
                placeholder: "Optional. Anything that helps us understand.",
                height: 104,
                fontSize: 14,
                maxLength: 400,
                onFocusChange: { noteFocused = $0 }
            )
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(noteFocused ? Color.tpEmber.opacity(0.55) : Color.tpLine, lineWidth: 1)
            )
        }
    }

    // MARK: Submit

    private var submitButton: some View {
        VStack(spacing: 10) {
            TPPrimaryButton(
                title: submitTitle,
                symbol: reason == .blockUser ? "person.crop.circle.badge.xmark" : "flag",
                isEnabled: reason != nil && !isSubmitting
            ) {
                submit()
            }

            if let reason, reason.isDestructive {
                Text("This cannot be undone. The content is removed immediately.")
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpBloom.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    private var submitTitle: String {
        switch reason {
        case .blockUser: return "Block and remove"
        case .none:      return "Choose a reason"
        default:         return "Submit report"
        }
    }

    private func submit() {
        guard let reason else { return }
        noteFocused = false
        isSubmitting = true

        TPHaptic.thump()

        Task {
            await TPLoadingRun.run(minimumDuration: 1.0, message: "Filing your report") {
                let outcome = CommunityService.fileReport(target: target, reason: reason, note: note)
                TPHaptic.success()
                isSubmitting = false
                withAnimation(TPMotion.gentle) { onFinish(outcome) }
            }
        }
    }
}
