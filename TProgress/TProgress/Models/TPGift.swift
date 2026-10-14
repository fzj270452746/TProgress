import Foundation
import SwiftUI

// MARK: - Gift
//
// Seven tokens, priced as consumables. The ladder climbs from a single spark to
// a supernova so the gesture scales with how much the post moved you.

struct TPGift: Identifiable, Equatable {

    let key: String
    let name: String
    let blurb: String
    let symbol: String
    let priceCents: Int
    let accentIndex: Int
    let tier: Int

    /// The App Store Connect identifier this token is sold under. Each tier has
    /// its own opaque identifier, so it is carried here rather than derived
    /// from the key.
    let productID: String

    var id: String { key }

    var accent: Color { .tpAccent(accentIndex) }

    var priceLabel: String { TPGift.priceLabel(cents: priceCents) }

    var priceDecimal: Decimal {
        Decimal(priceCents) / 100
    }

    static func priceLabel(cents: Int) -> String {
        String(format: "$%d.%02d", cents / 100, cents % 100)
    }
}

// MARK: - Catalog

enum TPGiftCatalog {

    static let all: [TPGift] = [
        TPGift(
            key: "ember",
            name: "Ember",
            blurb: "One spark. Enough to start.",
            symbol: "sparkle",
            priceCents: 99,
            accentIndex: 0,
            tier: 1,
            productID: "xbpixioboenxcing"
        ),
        TPGift(
            key: "candle",
            name: "Candle",
            blurb: "Steady light for a short page.",
            symbol: "flame",
            priceCents: 199,
            accentIndex: 1,
            tier: 2,
            productID: "xislpazetkpczztn"
        ),
        TPGift(
            key: "lantern",
            name: "Lantern",
            blurb: "For the session you almost skipped.",
            symbol: "lightbulb.fill",
            priceCents: 499,
            accentIndex: 2,
            tier: 3,
            productID: "zgdbaqozbtwqrbqu"
        ),
        TPGift(
            key: "bonfire",
            name: "Bonfire",
            blurb: "A week of showing up, honoured.",
            symbol: "flame.fill",
            priceCents: 999,
            accentIndex: 3,
            tier: 4,
            productID: "sqeepziytljcbbat"
        ),
        TPGift(
            key: "sunrise",
            name: "Sunrise",
            blurb: "You kept the streak alive. Rare.",
            symbol: "sunrise.fill",
            priceCents: 1999,
            accentIndex: 4,
            tier: 5,
            productID: "babwwywodauzplys"
        ),
        TPGift(
            key: "aurora",
            name: "Aurora",
            blurb: "For progress that changed something.",
            symbol: "moon.stars.fill",
            priceCents: 4999,
            accentIndex: 5,
            tier: 6,
            productID: "gbqgialtshxqiqmn"
        ),
        TPGift(
            key: "supernova",
            name: "Supernova",
            blurb: "The loudest thank you we have.",
            symbol: "sparkles",
            priceCents: 9999,
            accentIndex: 0,
            tier: 7,
            productID: "vrdjsfxdfzhhqpez"
        )
    ]

    static func gift(for key: String) -> TPGift? {
        all.first { $0.key == key }
    }

    static func gift(forProductID productID: String) -> TPGift? {
        all.first { $0.productID == productID }
    }
}

// MARK: - Token
//
// The gift's real face: a faceted token drawn in the accent colour, with the
// symbol set inside. Reads as an object rather than an icon.

struct TPGiftToken: View {

    let gift: TPGift
    var size: CGFloat = 58
    var showsPrice: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(TPGradient.accent(gift.accent))
                    .frame(width: size, height: size)
                    .tpEmberGlow(gift.accent, strength: 0.30)

                Circle()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    .frame(width: size, height: size)

                TPBurst(points: gift.tier + 2, innerRatio: 0.80)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: size * 0.92, height: size * 0.92)
                    .rotationEffect(.degrees(Double(gift.tier) * 12))

                Image(systemName: gift.symbol)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.tpInk.opacity(0.86))
            }

            VStack(spacing: 1) {
                Text(gift.name)
                    .font(TPFont.ui(12, .semibold))
                    .foregroundColor(.tpCream)

                if showsPrice {
                    Text(gift.priceLabel)
                        .font(TPFont.figure(11.5, .bold))
                        .foregroundColor(.tpCreamDim)
                }
            }
        }
    }
}
