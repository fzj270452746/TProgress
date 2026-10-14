import SwiftUI

// MARK: - Waterfall
//
// A masonry layout. LazyVGrid forces uniform rows, which flattens a feed of
// mixed media; this distributes by running height instead so art of different
// ratios interlocks.

struct TPWaterfall<Item: Identifiable, Content: View>: View {

    var items: [Item]
    var columns: Int = 2
    var spacing: CGFloat = 12
    var aspect: (Item) -> CGFloat
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columns, id: \.self) { column in
                LazyVStack(spacing: spacing) {
                    ForEach(bucket(column)) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// Greedy shortest-column packing, evaluated once per render.
    private func bucket(_ column: Int) -> [Item] {
        var heights = Array(repeating: CGFloat.zero, count: columns)
        var buckets = Array(repeating: [Item](), count: columns)

        for item in items {
            var target = 0
            for index in 1..<columns where heights[index] < heights[target] {
                target = index
            }
            buckets[target].append(item)
            heights[target] += aspect(item)
        }

        return buckets.indices.contains(column) ? buckets[column] : []
    }
}
