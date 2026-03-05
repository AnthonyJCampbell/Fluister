import SwiftUI

struct PillView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            switch appState.currentState {
            case .recording:
                recordingView
            case .transcribing:
                transcribingView
            case .success:
                successView
            case .error(let message):
                errorView(message: message)
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }

    private var recordingView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(pulseAnimation ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulseAnimation)
                .onAppear { pulseAnimation = true }
                .onDisappear { pulseAnimation = false }

            WaveformView()
                .frame(width: 84, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recording…")
                    .font(.system(size: 11, weight: .medium))
                Text(formattedDuration)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.secondary)
            }

            if appState.showTimeWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
            }
        }
    }

    private var transcribingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)

            VStack(alignment: .leading, spacing: 2) {
                Text("Transcribing…")
                    .font(.system(size: 11, weight: .medium))
                if appState.totalChunks > 1 {
                    Text("Chunk \(appState.currentChunk)/\(appState.totalChunks)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var successView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            Text("Copied")
                .font(.system(size: 12, weight: .medium))
        }
    }

    private func errorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
                .fixedSize()
            Text(message)
                .font(.system(size: 11))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @State private var pulseAnimation = false

    private var formattedDuration: String {
        let total = Int(appState.recordingDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
