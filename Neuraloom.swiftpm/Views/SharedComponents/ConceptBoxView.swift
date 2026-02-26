import SwiftUI

/// A pill-shaped box showing a numeric value with a descriptive label.
/// Used in inspect mode to make every term in a formula tappable and traceable.
struct ConceptBoxView: View {
    let value: String
    let label: String
    var tint: Color = .orange
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(tint.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Operator symbol between concept boxes (×, −, =)
struct ConceptOperator: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}
