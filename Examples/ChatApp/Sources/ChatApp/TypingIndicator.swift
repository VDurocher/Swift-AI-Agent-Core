import SwiftUI

/// Animation de typing — trois points qui pulsent en séquence
struct TypingIndicator: View {

    // Nombre de points de l'animation
    private static let dotCount = 3
    private static let animationDuration = 0.4
    private static let dotSize: CGFloat = 8

    @State private var animationPhase: Int = 0

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 4) {
                ForEach(0..<Self.dotCount, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: Self.dotSize, height: Self.dotSize)
                        .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                        .opacity(animationPhase == index ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: Self.animationDuration),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            )

            Spacer(minLength: 60)
        }
        .task {
            await runAnimation()
        }
    }

    // MARK: - Animation séquentielle

    private func runAnimation() async {
        // Boucle indéfinie jusqu'à annulation de la tâche
        while !Task.isCancelled {
            for index in 0..<Self.dotCount {
                animationPhase = index
                try? await Task.sleep(for: .seconds(Self.animationDuration))
            }
        }
    }
}
