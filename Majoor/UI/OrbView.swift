import SwiftUI

struct OrbView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            OrbCircle(phase: state.phase)
            Text(label(for: state.phase))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
        )
        .animation(.easeInOut(duration: 0.18), value: state.phase)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func label(for phase: AppState.Phase) -> String {
        switch phase {
        case .idle:         return "Idle"
        case .listening:    return "Listening…"
        case .transcribing: return "Transcribing…"
        case .thinking:     return "Thinking…"
        case .executing:    return "Doing it…"
        case .speaking:     return state.lastReply.isEmpty ? "Speaking…" : state.lastReply
        }
    }
}

private struct OrbCircle: View {
    let phase: AppState.Phase

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 26)
                .scaleEffect(pulseScale)

            if isSpinning {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .onAppear { drive(phase) }
        .onChange(of: phase) { _, newPhase in drive(newPhase) }
    }

    private var isSpinning: Bool {
        phase == .transcribing || phase == .thinking || phase == .executing
    }

    private func drive(_ phase: AppState.Phase) {
        // Pulse — only while listening
        if phase == .listening {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.18
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pulseScale = 1.0 }
        }

        // Spin — during async work
        if isSpinning {
            rotation = 0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { rotation = 0 }
        }
    }

    private var gradientColors: [Color] {
        switch phase {
        case .idle:         return [.gray, Color.gray.opacity(0.5)]
        case .listening:    return [.cyan, .blue]
        case .transcribing: return [.purple, .indigo]
        case .thinking:     return [.orange, .pink]
        case .executing:    return [.green, .mint]
        case .speaking:     return [.yellow, .orange]
        }
    }
}
