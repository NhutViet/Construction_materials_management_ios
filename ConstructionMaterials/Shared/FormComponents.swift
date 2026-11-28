import SwiftUI
import UIKit

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
        }
    }
}

struct FormField: View {
    let title: String
    let placeholder: String
    var icon: String?
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 18)
                }

                TextField(placeholder, text: $text, axis: axis)
                    .font(.subheadline)
                    .keyboardType(keyboard)
                    .lineLimit(lineLimit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct FormNumberRow: View {
    let title: String
    @Binding var value: Double
    var suffix: String?
    var width: CGFloat = 100

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)

            Spacer()

            TextField("0", value: $value, format: .number)
                .font(.subheadline.weight(.medium))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            if let suffix {
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FormPickerRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            content
        }
    }
}

struct FormSelectField: View {
    let title: String
    var icon: String?
    @Binding var selection: String
    let options: [String]
    var placeholder: String = "Chọn..."

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if selection == option {
                            Label(option, systemImage: "checkmark")
                        } else {
                            Text(option)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 18)
                    }

                    Text(selection.isEmpty ? placeholder : selection)
                        .font(.subheadline)
                        .foregroundStyle(selection.isEmpty ? .secondary : .primary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

struct FormTotalRow: View {
    let title: String
    let value: String
    var isTotal: Bool = false
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(title)
                .font(isTotal ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(isTotal ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(isTotal ? .headline.weight(.bold) : .subheadline.weight(.medium))
                .foregroundStyle(color)
        }
    }
}
