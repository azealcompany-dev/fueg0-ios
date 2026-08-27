import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var markVisible = false
    @State private var taglineVisible = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("FUEG0")
                    .font(.system(size: 52, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Palette.textPrimary)

                Text("NO EXCUSES. ONLY FIRE.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .opacity(taglineVisible ? 1 : 0)
            }
            .scaleEffect(markVisible ? 1 : 0.96)
            .opacity(markVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.95)) {
                markVisible = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                taglineVisible = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(2_200))
                onFinished()
            }
        }
    }
}
