import SwiftUI

struct TourStep {
    let title: String
    let body: String
}

struct TourMessageBoxView: View {
    let steps: [TourStep]
    @Binding var currentStep: Int
    let onDismiss: () -> Void

    private var step: TourStep { steps[currentStep] }
    private var isFirst: Bool { currentStep == 0 }
    private var isLast: Bool { currentStep == steps.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack(alignment: .top) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                Text(step.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Body
            Text(step.body)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Footer navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFirst ? .tertiary : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isFirst)

                Spacer()

                Text("\(currentStep + 1) of \(steps.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    if isLast {
                        onDismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep += 1
                        }
                    }
                } label: {
                    Text(isLast ? "Done" : "Next")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    if !isLast {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 12)
    }
}
