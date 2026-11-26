import SwiftUI

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.13))
                    .clipShape(Circle())
                Spacer()
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 14)
    }
}
