import SwiftUI
import AVFoundation
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var state: OnboardingState
    /// Called by the demo step when the user finishes.
    var onFinish: () -> Void = {}
    /// Called by step 4 after a valid key is saved so AppDelegate can refresh the OpenAI client.
    var onAPIKeySaved: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            ProgressDots(currentStep: state.step.rawValue,
                         totalSteps: OnboardingState.Step.allCases.count)
                .padding(.top, 22)

            // Step content
            ZStack {
                switch state.step {
                case .welcome:       WelcomeStep()
                case .microphone:    MicrophoneStep()
                case .accessibility: AccessibilityStep()
                case .apiKey:        APIKeyStep(onSaved: onAPIKeySaved)
                case .demo:          DemoStep(onDone: onFinish)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.18), value: state.step)
        }
        .frame(width: 520, height: 480)
        .background(BackgroundGradient())
    }
}

// MARK: - Progress dots

private struct ProgressDots: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == currentStep ? Color.accentColor : Color.white.opacity(0.22))
                    .frame(width: i == currentStep ? 22 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }
}

// MARK: - Background

private struct BackgroundGradient: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.08), Color(white: 0.02)],
                           startPoint: .top, endPoint: .bottom)
            // Subtle blue glow behind the content
            RadialGradient(colors: [Color.blue.opacity(0.18), Color.clear],
                           center: .init(x: 0.5, y: 0.38),
                           startRadius: 30, endRadius: 280)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable().scaledToFit().frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)

            Text("Majoor")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("A voice-first assistant for your Mac.\nHold ⌃⌥, speak, get things done.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            PrimaryButton("Get started") { state.advance() }

            Spacer(minLength: 0)

            // Credit line — small, subtle, clickable to GitHub.
            Button {
                if let url = URL(string: "https://github.com/Vivek-Chaudhari30") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Built by Vivek Chaudhari")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .padding(.bottom, 4)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Mouse-cursor helper

private extension View {
    func pointingHandCursor() -> some View {
        self.onHover { inside in
            if inside { NSCursor.pointingHand.push() }
            else      { NSCursor.pop() }
        }
    }
}

// MARK: - Step 2: Microphone

private struct MicrophoneStep: View {
    @EnvironmentObject var state: OnboardingState
    @State private var requested = false

    var body: some View {
        StepLayout(
            icon: "mic.fill",
            title: "Microphone access",
            blurb: "Majoor records your voice while you hold ⌃⌥. The audio is sent to OpenAI for transcription and not stored on your Mac.",
            statusOK: state.micGranted,
            statusOKText: "Microphone granted",
            statusBadText: requested ? "Permission still missing — open System Settings → Privacy & Security → Microphone." : "Not granted yet",
            actionLabel: state.micGranted ? "Granted ✓" : "Request access",
            actionDisabled: state.micGranted,
            action: { request() }
        ) {
            NavRow(canContinue: state.micGranted)
        }
    }

    private func request() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                requested = true
                state.objectWillChange.send()
                if !granted {
                    state.lastError = "Microphone permission denied."
                }
            }
        }
    }
}

// MARK: - Step 3: Accessibility

private struct AccessibilityStep: View {
    @EnvironmentObject var state: OnboardingState
    @State private var checkTick = 0

    var body: some View {
        StepLayout(
            icon: "command",
            title: "Accessibility access",
            blurb: "The ⌃⌥ hotkey is global — Majoor uses CGEventTap to detect it, which requires Accessibility permission. Without this, the hotkey silently does nothing.",
            statusOK: state.accessibilityGranted,
            statusOKText: "Accessibility granted",
            statusBadText: "Not granted yet — click below to open Settings.",
            actionLabel: state.accessibilityGranted ? "Granted ✓" : "Open System Settings",
            actionDisabled: state.accessibilityGranted,
            action: { openSettings() },
            footnote: state.accessibilityGranted ? nil : "After enabling Majoor in the list, quit and relaunch Majoor for the change to take effect."
        ) {
            NavRow(canContinue: state.accessibilityGranted)
        }
        // Re-check periodically so the UI updates without a button click.
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            checkTick &+= 1
            // Force a re-render to re-read accessibilityGranted.
            state.objectWillChange.send()
        }
    }

    private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Step 4: API key

private struct APIKeyStep: View {
    @EnvironmentObject var state: OnboardingState
    var onSaved: () -> Void

    @State private var saving = false
    @State private var errorText: String?
    @State private var revealed = false

    var body: some View {
        StepLayout(
            icon: "key.fill",
            title: "OpenAI API key",
            blurb: "Majoor uses OpenAI for transcription and routing. You'll need a key with available credit.",
            statusOK: state.apiKeyConfigured,
            statusOKText: "API key configured",
            statusBadText: errorText ?? "Paste your sk-… key below.",
            actionLabel: nil,
            actionDisabled: true,
            action: {}
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Group {
                        if revealed {
                            TextField("sk-...", text: $state.keyInput)
                        } else {
                            SecureField("sk-...", text: $state.keyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit { primaryAction() }

                    Button(action: { revealed.toggle() }) {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.7))
                }

                HStack {
                    Button("Get a key →") {
                        if let url = URL(string: "https://platform.openai.com/api-keys") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(.blue.opacity(0.9))
                    Spacer()
                }

                // Custom nav row — one smart "Continue" button that saves + advances.
                HStack {
                    Button("Back") { state.goBack() }
                        .buttonStyle(.bordered)
                    Spacer()
                    PrimaryButton(continueLabel) {
                        primaryAction()
                    }
                    .disabled(!canPressContinue)
                    .opacity(canPressContinue ? 1 : 0.55)
                }
            }
            // Silently clear stale error the moment the user edits the field again.
            .onChange(of: state.keyInput) { _, _ in errorText = nil }
        }
    }

    private var continueLabel: String {
        if saving { return "Saving…" }
        if state.apiKeyConfigured { return "Continue" }
        return "Save & Continue"
    }

    /// True when the button should be pressable: either we already have a saved
    /// key (just advance), or the input field holds something that looks valid
    /// (save first, then advance).
    private var canPressContinue: Bool {
        if saving { return false }
        if state.apiKeyConfigured { return true }
        let t = state.keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("sk-") && t.count >= 20
    }

    /// One action handles both cases — pre-saved (advance), and just-pasted
    /// (validate, save, then advance). Triggered by clicking the button OR
    /// pressing Return in the text field.
    private func primaryAction() {
        if saving { return }
        if state.apiKeyConfigured {
            state.advance()
            return
        }
        let trimmed = state.keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("sk-"), trimmed.count >= 20 else {
            errorText = "That doesn't look like an OpenAI key (should start with sk-)."
            return
        }
        saving = true
        errorText = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = Config.saveAPIKey(trimmed)
            DispatchQueue.main.async {
                saving = false
                if ok {
                    onSaved()
                    // Tiny delay so the user sees the status row flip to "configured ✓"
                    // before the step transitions.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        state.advance()
                    }
                } else {
                    errorText = "Couldn't write ~/.majoor/config.json. Check permissions."
                }
            }
        }
    }
}

// MARK: - Step 5: Try it (demo)

private struct DemoStep: View {
    @EnvironmentObject var state: OnboardingState
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: state.hotkeyFiredOnce ? "checkmark.circle.fill" : "waveform.circle")
                .font(.system(size: 52, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(state.hotkeyFiredOnce ? Color.green : Color.cyan)
                .padding(.top, 10)

            Text("Try Majoor")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(state.hotkeyFiredOnce
                 ? "Got it. Now say something like \"open Safari\" or \"what's the capital of France\"."
                 : "Hold Ctrl + Option, then release. Try it now.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)

            // Live status pill
            HStack(spacing: 8) {
                Circle()
                    .fill(state.hotkeyFiredOnce ? Color.green : Color.white.opacity(0.5))
                    .frame(width: 9, height: 9)
                Text(state.hotkeyFiredOnce ? "Hotkey detected ✓" : "Waiting for ⌃⌥…")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
            )

            Spacer(minLength: 4)

            HStack {
                Button("Back") { state.goBack() }
                    .buttonStyle(.bordered)
                Spacer()
                PrimaryButton(state.hotkeyFiredOnce ? "Finish" : "Skip for now") {
                    onDone()
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Shared layout helpers

private struct StepLayout<Trailing: View>: View {
    let icon: String
    let title: String
    let blurb: String                          // renamed from `body` to avoid View.body collision
    let statusOK: Bool
    let statusOKText: String
    let statusBadText: String
    let actionLabel: String?
    let actionDisabled: Bool
    let action: () -> Void
    var footnote: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.blue.opacity(0.22)))
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(blurb)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            StatusRow(ok: statusOK, okText: statusOKText, badText: statusBadText)

            if let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(actionDisabled)
            }

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            trailing()
        }
        .padding(.top, 4)
    }
}

private struct StatusRow: View {
    let ok: Bool
    let okText: String
    let badText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
            Text(ok ? okText : badText)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct NavRow: View {
    @EnvironmentObject var state: OnboardingState
    let canContinue: Bool

    var body: some View {
        HStack {
            Button("Back") { state.goBack() }
                .buttonStyle(.bordered)
                .disabled(state.step == .welcome)
            Spacer()
            PrimaryButton("Continue") {
                state.advance()
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.55)
        }
    }
}

private struct PrimaryButton: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return, modifiers: [])
    }
}
