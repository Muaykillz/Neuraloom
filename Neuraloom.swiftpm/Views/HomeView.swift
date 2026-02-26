import SwiftUI

struct HomeView: View {
    var onOpenPlayground: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Neuraloom")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("Drag, Drop, Draw — Neural Networks Made Simple")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onOpenPlayground()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Open Playground")
                        .font(.title3.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}
