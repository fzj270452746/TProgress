import SwiftUI

// MARK: - Check-in row
//
// One entry as it appears in a timeline. Shared rather than written twice,
// because this is the one place the log's vocabulary has to be legible: a single
// checkmark would make five different kinds of day look identical, and the whole
// point of the vocabulary is that they are not.

struct CheckInRow: View {

    let entry: CDCheckIn
    var accent: Color = .tpEmber

    private var kind: CheckInKind { entry.kind }

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 34, height: 34)

                Image(systemName: kind.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(TPFont.ui(13.5, .semibold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)

                    // The one kind that needs saying out loud, because the rest
                    // of the row would otherwise read as an ordinary log.
                    if kind == .backfill {
                        TPTag(text: "Added later", color: .tpSky)
                    }
                }

                if entry.hasNote {
                    Text(entry.noteText)
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                        .lineLimit(2)
                } else if let detail {
                    Text(detail)
                        .font(TPFont.ui(11.5))
                        .foregroundColor(.tpCreamFaint)
                }
            }

            Spacer(minLength: 6)

            Text(entry.relativeTime)
                .font(TPFont.ui(11))
                .foregroundColor(.tpCreamFaint)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Copy

    private var title: String {
        switch kind {
        case .standard: return "Logged \(entry.amountLabel)"
        case .minimum:  return "Only the minimum"
        case .rest:     return "Rested — planned"
        case .backfill: return "Logged \(entry.amountLabel)"
        case .freeze:   return "Restored with a freeze card"
        }
    }

    /// A line under the title when there is no note to show instead. The two are
    /// alternatives rather than both, so a short row stays short.
    private var detail: String? {
        switch kind {
        case .minimum:  return "The smallest version. It still counts."
        case .rest:     return "Set aside in advance."
        case .freeze:   return "The day was bought back."
        default:        return nil
        }
    }
}
