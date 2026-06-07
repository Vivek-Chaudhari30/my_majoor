import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private var orb: OrbPanel!
    private let openAI: OpenAIClient? = {
        guard let key = Config.openAIKey else {
            Log.error("OPENAI_API_KEY not found. Create ~/.majoor/config.json with {\"openai_api_key\":\"sk-...\"}")
            return nil
        }
        return OpenAIClient(apiKey: key)
    }()

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
                self.orb.show()
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

            // 2) Agent loop — handles tool selection AND execution AND final reply.
            // Phase stays at .thinking through the loop; tool execution is part of it.
            await MainActor.run { AppState.shared.phase = .thinking }
            let spoken: String
            do {
                spoken = try await openAI.chat(transcript: transcript)
            } catch {
                Log.error("Brain failed: \(error.localizedDescription)")
                await MainActor.run { Task { await self.speakAndIdle("Something went wrong.") } }
                return
            }

            // 3) Speak whatever the model produced (post-loop final reply).
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
        orb.hide()
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
