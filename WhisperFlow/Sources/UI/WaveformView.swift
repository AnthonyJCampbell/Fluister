import SwiftUI

struct WaveformView: View {
    @EnvironmentObject var appState: AppState

    private let barCount = 24
    /// Rolling buffer of audio levels — each new sample shifts bars left, newest on the right.
    @State private var levels: [CGFloat] = Array(repeating: 0.05, count: 24)

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(barGradient)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.08), value: levels[index])
            }
        }
        .onChange(of: appState.audioLevel) { newLevel in
            // Shift all bars left and push new level on the right — creates a scrolling waveform
            var updated = Array(levels.dropFirst())
            updated.append(CGFloat(max(0.05, min(1.0, newLevel))))
            levels = updated
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let maxHeight: CGFloat = 20
        let minHeight: CGFloat = 2
        let level = levels[index]
        return minHeight + level * (maxHeight - minHeight)
    }

    private var barGradient: some ShapeStyle {
        Color.red.opacity(0.85)
    }
}
