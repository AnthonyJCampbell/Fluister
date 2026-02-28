import SwiftUI

struct WaveformView: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0.3, count: 5)

    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.red.opacity(0.8))
                    .frame(width: 3, height: barHeights[index] * 20)
                    .animation(.easeInOut(duration: 0.15), value: barHeights[index])
            }
        }
        .onReceive(timer) { _ in
            for i in 0..<5 {
                barHeights[i] = CGFloat.random(in: 0.2...1.0)
            }
        }
    }
}
