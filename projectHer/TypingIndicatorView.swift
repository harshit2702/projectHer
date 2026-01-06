import SwiftUI

struct TypingIndicatorView: View {
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.4).repeatForever().delay(0.0),
                    value: scale
                )
            Circle()
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.4).repeatForever().delay(0.2),
                    value: scale
                )
            Circle()
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.4).repeatForever().delay(0.4),
                    value: scale
                )
        }
        .frame(width: 40, height: 20)
        .padding(12)
        .background(Color.pink.opacity(0.2))
        .cornerRadius(16)
        .onAppear {
            self.scale = 1.0
        }
    }
}
