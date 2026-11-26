import SwiftUI

struct StatusChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
