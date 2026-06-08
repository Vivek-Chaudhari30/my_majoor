import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private var orb: OrbPanel!
    private var onboardingWindow: OnboardingWindow?

    /// In-memory conversation buffer (Phase C / MASTER_PLAN §6). Last 6 turns
    /// of (transcript, assistant reply) are sent with every chat call so the
    /// model has same-session context ("what's my name" right after "my name
    /// is Vivek"). Cleared on app quit. Persistent memory lives in
    /// ~/.majoor/memory.json via MemoryStore.
    private var conversationBuffer: [Turn] = []
    private let maxBufferTurns = 6

    /// Re-created when the user finishes the onboarding API-key step so the
    /// new key takes effect without a relaunch. `nil` until a key is set.
    private var openAI: OpenAIClient? = AppDelegate.makeClient()

    private static func makeClient() -> OpenAIClient? {
        guard let key = Config.openAIKey else {
            Log.warn("No OpenAI API key configured yet — chat calls will be skipped.")
            return nil
        }
        return OpenAIClient(apiKey: key)
    }

    /// Called by the onboarding API-key step.
    @MainActor
    private func refreshOpenAI() {
        openAI = AppDelegate.makeClient()
        Log.info(openAI == nil ? "Refreshed OpenAI client → still nil (no key found)."
                               : "Refreshed OpenAI client.")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "waveform.circle",
                                accessibilityDescription: "Majoor")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Majoor — hold ⌃⌥ to talk"
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Majoor v0.1", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Hold ⌃⌥ to talk", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        let onboardingItem = NSMenuItem(title: "Show Onboarding…",
                                        action: #selector(showOnboarding),
                                        keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)
        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "Launch at Login",
                                    action: #selector(toggleLaunchAtLogin(_:)),
                                    keyEquivalent: "")
        launchItem.target = self
        launchItem.identifier = NSUserInterfaceItemIdentifier("launchAtLogin")
        menu.addItem(launchItem)
        let settingsItem = NSMenuItem(title: "Open Login Items Settings…",
                                      action: #selector(openLoginItemsSettings),
                                      keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Majoor",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        statusItem.menu = menu

        orb = OrbPanel()
        // Always-visible Dynamic-Island-style pill (Phase B). Idle pill stays
        // up; phase changes drive the orb's size + color from inside SwiftUI.
        orb.show()

        AudioRecorder.requestPermission { granted in
            if !granted {
                Log.warn("Microphone permission denied. Enable Majoor in System Settings → Privacy & Security → Microphone, then relaunch.")
            } else {
                Log.info("Microphone permission granted.")
            }
        }

        if openAI == nil {
            Log.warn("OpenAI client is nil; transcription will be skipped until the API key is set.")
        } else {
            Log.info("OpenAI client ready.")
        }

        hotkey.onPressed = { [weak self] in
            Log.info("Hotkey PRESSED")
            guard let self else { return }
            Task { @MainActor in
                AppState.shared.phase = .listening
                OnboardingState.shared.hotkeyFiredOnce = true
                // Orb is already on-screen (Dynamic-Island idle pill); no show() needed.
            }
            do {
                try self.recorder.start()
            } catch {
                Log.error("Recorder failed to start: \(error.localizedDescription)")
                Task { @MainActor in self.returnToIdle() }
            }
        }
        hotkey.onReleased = { [weak self] in
            Log.info("Hotkey RELEASED")
            guard let self else { return }
            guard let url = self.recorder.stop() else {
                Task { @MainActor in self.returnToIdle() }
                return
            }
            Log.info("Recording saved → \(url.path)")
            self.runPipeline(url: url)
        }
        hotkey.start()

        // Show onboarding on first launch (no ~/.majoor/.onboarded sentinel).
        if !OnboardingState.isOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    @MainActor
    @objc private func showOnboarding() {
        OnboardingState.shared.reset()
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindow(
                onFinish: { [weak self] in
                    OnboardingState.markOnboarded()
                    self?.onboardingWindow?.close()
                },
                onAPIKeySaved: { [weak self] in
                    self?.refreshOpenAI()
                },
                onClose: { [weak self] in
                    self?.onboardingWindow = nil
                    NSApp.setActivationPolicy(.accessory)
                }
            )
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.present()
    }

    private func runPipeline(url: URL) {
        guard let openAI else {
            Log.warn("Skipping pipeline — no API key.")
            Task { @MainActor in
                await self.speakAndIdle("API key is missing.")
            }
            return
        }
        Task { @MainActor in AppState.shared.phase = .transcribing }

        Task.detached { [weak self, openAI] in
            guard let self else { return }

            // 1) STT
            let transcript: String
            do {
                transcript = try await openAI.transcribe(fileURL: url)
            } catch {
                Log.error("Whisper failed: \(error.localizedDescription)")
                await MainActor.run { Task { await self.speakAndIdle("Couldn't hear you.") } }
                return
            }
            guard !transcript.isEmpty else {
                Log.warn("Transcript was empty.")
                await MainActor.run { Task { await self.speakAndIdle("I didn't catch that.") } }
                return
            }
            Log.info("Transcript: \(transcript)")

            // 2) Snapshot conversation buffer + persistent memory on main actor.
            let snapshot = await MainActor.run {
                (history: self.conversationBuffer,
                 injection: MemoryStore.shared.systemPromptInjection(),
                 factCount: MemoryStore.shared.facts.count)
            }
            let history = snapshot.history
            let memoryInjection = snapshot.injection
            if !memoryInjection.isEmpty {
                Log.info("Memory: \(snapshot.factCount) fact(s) injected.")
            }
            if !history.isEmpty {
                Log.info("Conversation buffer: \(history.count) turn(s) in context.")
            }

            // 3) Agent loop — handles tool selection AND execution AND final reply.
            await MainActor.run { AppState.shared.phase = .thinking }
            let spoken: String
            do {
                spoken = try await openAI.chat(
                    transcript: transcript,
                    history: history,
                    memoryInjection: memoryInjection
                )
            } catch {
                Log.error("Brain failed: \(error.localizedDescription)")
                await MainActor.run { Task { await self.speakAndIdle("Something went wrong.") } }
                return
            }

            // 4) Append this turn to the buffer (cap at maxBufferTurns).
            await MainActor.run {
                self.conversationBuffer.append(Turn(userTranscript: transcript, assistantReply: spoken))
                if self.conversationBuffer.count > self.maxBufferTurns {
                    self.conversationBuffer.removeFirst(self.conversationBuffer.count - self.maxBufferTurns)
                }
            }

            // 5) Speak whatever the model produced (post-loop final reply).
            Log.info("Spoken: \(spoken)")
            await MainActor.run {
                AppState.shared.lastReply = spoken
                Task { await self.speakAndIdle(spoken) }
            }
        }
    }

    @MainActor
    private func speakAndIdle(_ text: String) async {
        AppState.shared.phase = .speaking
        if AppState.shared.lastReply.isEmpty {
            AppState.shared.lastReply = text
        }
        await Speaker.speak(text)
        returnToIdle()
    }

    @MainActor
    private func returnToIdle() {
        AppState.shared.phase = .idle
        AppState.shared.lastReply = ""
        // Don't hide — the idle pill is the resting Dynamic-Island state.
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.stop()
        _ = recorder.stop()
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                Log.info("Launch-at-login: unregistered.")
            case .notRegistered, .notFound:
                try service.register()
                Log.info("Launch-at-login: registered.")
            case .requiresApproval:
                Log.warn("Launch-at-login requires approval. Opening Login Items settings…")
                openLoginItemsSettings()
            @unknown default:
                break
            }
        } catch {
            Log.error("Launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }

    @objc private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // Refresh the toggle's checkmark every time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        guard let item = menu.items.first(where: { $0.identifier?.rawValue == "launchAtLogin" }) else { return }
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:           item.state = .on;  item.title = "Launch at Login"
        case .requiresApproval:  item.state = .mixed; item.title = "Launch at Login (needs approval)"
        case .notRegistered, .notFound: item.state = .off; item.title = "Launch at Login"
        @unknown default:        item.state = .off; item.title = "Launch at Login"
        }
    }
}
