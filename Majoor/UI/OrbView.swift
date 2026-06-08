import SwiftUI

/// The notch-anchored pill. Resting state is a small idle capsule centered in
/// the panel; on every other state it expands and shows a glyph + label.
///
/// Phase B v2 — the orb visually IS the app icon. Recessed pill body, radial
/// gradient dot with off-center bright spot, specular highlight, soft glow halo.
/// State changes swap the dot's color palette while keeping the icon language
/// intact, so Majoor's brand is always present.
struct OrbView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
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
            IconicDot(phase: state.phase)
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
        .background(RecessedPillBackground())
    }

    private var showsLabel: Bool { state.phase != .idle }

    private var pillHeight: CGFloat {
        switch state.phase {
        case .idle: return 22
        default:    return 36
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

// MARK: - Recessed pill background (mirrors the icon's pill)

private struct RecessedPillBackground: View {
    var body: some View {
        ZStack {
            // Base body — top-to-bottom dark gradient (#000 → #16161a)
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(red: 0.086, green: 0.086, blue: 0.102)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Inner shadow at top edge (deep) — slightly recessed feel
            Capsule(style: .continuous)
                .strokeBorder(Color.black.opacity(0.85), lineWidth: 1)

            // Faint inner highlight rim along the bottom
            Capsule(style: .continuous)
                .inset(by: 1)
                .strokeBorder(Color(red: 0.227, green: 0.227, blue: 0.259).opacity(0.45), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Iconic dot (radial gradient + specular highlight + glow halo)

private struct IconicDot: View {
    let phase: AppState.Phase

    @State private var pulseScale: CGFloat = 1.0
    @State private var glowScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Outer glow halo — colored, soft, much larger than dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.mid.opacity(0.55),
                            palette.deep.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 18
                    )
                )
                .blur(radius: 3)
                .scaleEffect(glowScale)
                .opacity(phase == .idle ? 0.55 : 1.0)

            // Main dot — radial gradient with off-center bright spot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.bright, palette.mid, palette.deep],
                        center: UnitPoint(x: 0.42, y: 0.35),  // matches icon's bright-spot position
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .scaleEffect(pulseScale)
                .overlay(
                    // Specular highlight — small soft white ellipse on upper-left
                    Ellipse()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: 6, height: 3.6)
                        .blur(radius: 1.2)
                        .offset(x: -3, y: -3)
                        .scaleEffect(pulseScale)
                )

            // Spinning arc for active processing states
            if isSpinning {
                Circle()
                    .trim(from: 0, to: 0.30)
                    .stroke(
                        Color.white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation))
                    .padding(-4)
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
                glowScale  = 1.50
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseScale = 1.0
                glowScale  = phase == .idle ? 1.0 : 1.15
            }
        }

        // Spin — during async work
        if isSpinning {
            rotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { rotation = 0 }
        }
    }

    // MARK: - Per-state palettes
    //
    // Idle uses the icon's exact cyan/blue palette so the orb literally looks
    // like a smaller, more-relaxed version of the app icon at rest. Active
    // states keep their existing distinctive hues — that's the only way the
    // user can glance and know whether Majoor is listening / thinking /
    // speaking — but each state palette now has matching bright/mid/deep
    // stops so the radial gradient + highlight still reads as "the icon."

    private var palette: Palette {
        switch phase {
        case .idle, .listening:
            // Icon's literal colors: #7fe3ff → #00C2FF → #0066FF
            return Palette(
                bright: Color(red: 0.498, green: 0.890, blue: 1.000),
                mid:    Color(red: 0.000, green: 0.760, blue: 1.000),
                deep:   Color(red: 0.000, green: 0.400, blue: 1.000)
            )
        case .transcribing:
            return Palette(
                bright: Color(red: 0.840, green: 0.580, blue: 1.000),
                mid:    Color(red: 0.580, green: 0.310, blue: 0.940),
                deep:   Color(red: 0.290, green: 0.150, blue: 0.620)
            )
        case .thinking:
            return Palette(
                bright: Color(red: 1.000, green: 0.700, blue: 0.620),
                mid:    Color(red: 1.000, green: 0.420, blue: 0.510),
                deep:   Color(red: 0.840, green: 0.220, blue: 0.380)
            )
        case .executing:
            return Palette(
                bright: Color(red: 0.620, green: 1.000, blue: 0.820),
                mid:    Color(red: 0.250, green: 0.880, blue: 0.620),
                deep:   Color(red: 0.000, green: 0.600, blue: 0.420)
            )
        case .speaking:
            return Palette(
                bright: Color(red: 1.000, green: 0.940, blue: 0.520),
                mid:    Color(red: 1.000, green: 0.760, blue: 0.220),
                deep:   Color(red: 0.840, green: 0.500, blue: 0.100)
            )
        }
    }

    private struct Palette {
        let bright: Color  // small bright spot at upper-left
        let mid: Color     // mid-tone — most of the visible color
        let deep: Color    // edge tone — darkens at the rim
    }
}
