import SwiftUI

/// The notch-anchored pill. Resting state is a small idle capsule centered in
/// the panel; on every other state it expands and shows a glyph + label.
struct OrbView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        // Anchor the pill to the TOP of the panel so it visually hugs the
        // menu bar bottom (Dynamic-Island feel) rather than floating in the middle.
        VStack(spacing: 0) {
            pill
                .padding(.top, 2)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.phase)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.lastReply)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: 10) {
            OrbDot(phase: state.phase)
                .frame(width: 18, height: 18)

            if showsLabel {
                Text(labelText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, showsLabel ? 14 : 8)
        .frame(height: pillHeight)
        .frame(minWidth: pillMinWidth)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.86))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - State-dependent metrics

    /// Idle keeps a small, glanceable resting pill — no label.
    private var showsLabel: Bool {
        state.phase != .idle
    }

    private var pillHeight: CGFloat {
        switch state.phase {
        case .idle:     return 22
        default:        return 36
        }
    }

    private var pillMinWidth: CGFloat {
        switch state.phase {
        case .idle:        return 90
        case .listening:   return 200
        case .transcribing: return 220
        case .thinking:    return 200
        case .executing:   return 200
        case .speaking:    return 240
        }
    }

    private var labelText: String {
        switch state.phase {
        case .idle:         return ""
        case .listening:    return "Listening…"
        case .transcribing: return "Transcribing…"
        case .thinking:     return "Thinking…"
        case .executing:    return "Doing it…"
        case .speaking:
            let r = state.lastReply.trimmingCharacters(in: .whitespacesAndNewlines)
            return r.isEmpty ? "Speaking…" : r
        }
    }
}

// MARK: - Orb dot

private struct OrbDot: View {
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
                .scaleEffect(pulseScale)

            if isSpinning {
                Circle()
                    .trim(from: 0, to: 0.30)
                    .stroke(.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(rotation))
                    .padding(-3)
            }
        }
        .onAppear { drive(phase) }
        .onChange(of: phase) { _, newPhase in drive(newPhase) }
    }

    private var isSpinning: Bool {
        phase == .transcribing || phase == .thinking || phase == .executing
    }

    private func drive(_ phase: AppState.Phase) {
        if phase == .listening {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.22
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pulseScale = 1.0 }
        }

        if isSpinning {
            rotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { rotation = 0 }
        }
    }

    private var gradientColors: [Color] {
        switch phase {
        case .idle:         return [Color.white.opacity(0.55), Color.white.opacity(0.25)]
        case .listening:    return [.cyan, .blue]
        case .transcribing: return [.purple, .indigo]
        case .thinking:     return [.orange, .pink]
        case .executing:    return [.green, .mint]
        case .speaking:     return [.yellow, .orange]
        }
    }
}
