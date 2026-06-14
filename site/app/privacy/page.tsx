import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Majoor",
  description: "Majoor privacy policy. Your data stays on your device.",
};

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-neutral-950 text-neutral-200">
      <div className="mx-auto max-w-2xl px-6 py-20">
        {/* Header */}
        <div className="mb-12">
          <p className="mb-3 text-sm font-medium tracking-widest text-neutral-500 uppercase">
            Legal
          </p>
          <h1 className="text-3xl font-semibold tracking-tight text-white">
            Privacy Policy
          </h1>
          <p className="mt-3 text-sm text-neutral-500">
            Last updated: June 2025
          </p>
        </div>

        {/* Sections */}
        <div className="space-y-10">

          {/* 1. Overview */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">Overview</h2>
            <p className="leading-relaxed text-neutral-400">
              Majoor is a native macOS application. Almost all of your data —
              your settings, your memories, your API key — lives locally on your
              device and never leaves it. We do not operate any backend servers,
              collect usage data, or store anything on our infrastructure. This
              policy describes the narrow set of cases where data does leave your
              machine, and exactly what happens to it.
            </p>
          </section>

          <div className="border-t border-neutral-800" />

          {/* 2. Audio Data */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">Audio Data</h2>
            <p className="leading-relaxed text-neutral-400">
              Majoor only activates your microphone while you are actively
              holding the push-to-talk shortcut (Ctrl+Option). No audio is
              captured passively or in the background. When you speak and release
              the shortcut, the recorded audio is sent to OpenAI's Whisper API
              solely for the purpose of speech-to-text transcription. Once
              transcription is complete, the audio is discarded — it is not
              stored on your device, not retained by Majoor, and not stored by
              us. OpenAI's data handling for API requests is governed by{" "}
              <a
                href="https://openai.com/policies/privacy-policy"
                target="_blank"
                rel="noopener noreferrer"
                className="text-neutral-300 underline underline-offset-2 hover:text-white transition-colors"
              >
                OpenAI's privacy policy
              </a>
              .
            </p>
          </section>

          <div className="border-t border-neutral-800" />

          {/* 3. API Key */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">API Key</h2>
            <p className="leading-relaxed text-neutral-400">
              Your OpenAI API key is stored locally on your device at{" "}
              <code className="rounded bg-neutral-800 px-1.5 py-0.5 text-sm text-neutral-300">
                ~/Library/Application Support/Majoor/config.json
              </code>
              . It is never transmitted to us or to any party other than
              OpenAI's API endpoints, where it is used to authenticate your
              requests directly. Majoor has no mechanism to read or forward your
              key elsewhere.
            </p>
          </section>

          <div className="border-t border-neutral-800" />

          {/* 4. Memory */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">Memory</h2>
            <p className="leading-relaxed text-neutral-400">
              When you ask Majoor to remember a fact, that information is written
              to a local file at{" "}
              <code className="rounded bg-neutral-800 px-1.5 py-0.5 text-sm text-neutral-300">
                ~/Library/Application Support/Majoor/memory.json
              </code>
              . This file never leaves your device. You can inspect, edit, or
              delete it at any time using any text editor or Finder.
            </p>
          </section>

          <div className="border-t border-neutral-800" />

          {/* 5. Analytics */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">Analytics</h2>
            <p className="leading-relaxed text-neutral-400">
              Majoor collects no analytics. There is no usage tracking, no crash
              reporting, no telemetry, and no event logging sent anywhere. We do
              not know how often you use the app, which commands you run, or
              whether you encounter errors.
            </p>
          </section>

          <div className="border-t border-neutral-800" />

          {/* 6. Third Parties */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">
              Third-Party Services
            </h2>
            <p className="leading-relaxed text-neutral-400">
              The only third-party service Majoor communicates with is OpenAI
              (
              <code className="rounded bg-neutral-800 px-1.5 py-0.5 text-sm text-neutral-300">
                api.openai.com
              </code>
              ). Audio transcription requests are sent to this endpoint during
              active push-to-talk sessions. No other third-party SDKs,
              analytics providers, or network services are included in the app.
            </p>
          </section>

          <div className="border-t border-neutral-800" />

          {/* 7. Contact */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-white">Contact</h2>
            <p className="leading-relaxed text-neutral-400">
              If you have questions about this privacy policy or how Majoor
              handles your data, reach out at{" "}
              <a
                href="mailto:vivek.cs.study@gmail.com"
                className="text-neutral-300 underline underline-offset-2 hover:text-white transition-colors"
              >
                vivek.cs.study@gmail.com
              </a>
              .
            </p>
          </section>

        </div>

        {/* Footer note */}
        <p className="mt-16 text-xs text-neutral-600">
          © {new Date().getFullYear()} Majoor. All rights reserved.
        </p>
      </div>
    </main>
  );
}
