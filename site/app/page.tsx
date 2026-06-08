import Image from "next/image";

const GITHUB_REPO = "Vivek-Chaudhari30/my_majoor";

type Release = {
  tag_name: string;
  name: string;
  html_url: string;
  assets: { name: string; browser_download_url: string; size: number }[];
};

async function getLatestRelease(): Promise<Release | null> {
  try {
    const res = await fetch(
      `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`,
      {
        next: { revalidate: 3600 },
        headers: { Accept: "application/vnd.github+json" },
      }
    );
    if (!res.ok) return null;
    return (await res.json()) as Release;
  } catch {
    return null;
  }
}

function formatBytes(n: number) {
  if (n > 1024 * 1024) return `${(n / 1024 / 1024).toFixed(1)} MB`;
  return `${Math.round(n / 1024)} KB`;
}

export default async function Home() {
  const release = await getLatestRelease();
  const zipAsset = release?.assets.find((a) => a.name.toLowerCase().endsWith(".zip"));
  const downloadUrl =
    zipAsset?.browser_download_url ?? `https://github.com/${GITHUB_REPO}/releases/latest`;
  const versionLabel = release?.tag_name ?? "latest";
  const sizeLabel = zipAsset ? formatBytes(zipAsset.size) : "";

  return (
    <div className="relative min-h-screen overflow-hidden">
      {/* ambient blue glow */}
      <div
        className="pointer-events-none absolute inset-x-0 top-0 -z-10 mx-auto h-[700px] max-w-5xl opacity-60 blur-3xl"
        aria-hidden
        style={{
          background:
            "radial-gradient(60% 60% at 50% 0%, rgba(0,194,255,0.20) 0%, rgba(0,102,255,0.10) 40%, rgba(0,0,0,0) 80%)",
        }}
      />

      {/* nav */}
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-5">
        <div className="flex items-center gap-2.5">
          <Image src="/icon.svg" alt="Majoor icon" width={26} height={26} />
          <span className="text-[15px] font-semibold tracking-tight">Majoor</span>
        </div>
        <nav className="flex items-center gap-1 text-sm text-white/70">
          <a
            href={`https://github.com/${GITHUB_REPO}`}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-md px-3 py-1.5 hover:bg-white/5 hover:text-white"
          >
            GitHub
          </a>
          <a
            href={`https://github.com/${GITHUB_REPO}/releases`}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-md px-3 py-1.5 hover:bg-white/5 hover:text-white"
          >
            Releases
          </a>
          <a
            href={`https://github.com/${GITHUB_REPO}/blob/main/MASTER_PLAN.md`}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-md px-3 py-1.5 hover:bg-white/5 hover:text-white"
          >
            Architecture
          </a>
        </nav>
      </header>

      <main className="mx-auto w-full max-w-6xl px-6">
        {/* hero */}
        <section className="flex flex-col items-center pt-16 pb-24 text-center sm:pt-24">
          <Image
            src="/icon.svg"
            alt="Majoor"
            width={128}
            height={128}
            priority
            className="drop-shadow-[0_20px_50px_rgba(0,180,255,0.35)]"
          />

          <h1 className="mt-10 max-w-2xl text-5xl font-semibold tracking-tight sm:text-6xl">
            A voice-first assistant
            <br />
            <span className="bg-gradient-to-r from-cyan-300 to-blue-500 bg-clip-text text-transparent">
              for your Mac
            </span>
          </h1>

          <p className="mt-6 max-w-xl text-balance text-base leading-7 text-white/70 sm:text-lg">
            Hold <Kbd>⌃</Kbd> <Kbd>⌥</Kbd>, speak, and Majoor opens what you asked for, answers your question, or remembers what you told it. Lives flush under the notch.
          </p>

          <div className="mt-10 flex flex-col items-center gap-3 sm:flex-row">
            <a
              href={downloadUrl}
              className="group inline-flex h-12 items-center gap-2.5 rounded-full bg-gradient-to-br from-cyan-400 to-blue-600 px-7 text-[15px] font-semibold text-white shadow-[0_10px_30px_-10px_rgba(0,180,255,0.7)] transition-transform hover:scale-[1.02] active:scale-[0.99]"
            >
              <DownloadIcon />
              Download for macOS
              <span className="rounded-full bg-white/15 px-2 py-0.5 text-[11px] font-medium text-white/90 group-hover:bg-white/25">
                {versionLabel}
              </span>
            </a>
            <a
              href={`https://github.com/${GITHUB_REPO}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex h-12 items-center gap-2 rounded-full border border-white/15 bg-white/[0.03] px-6 text-[15px] font-medium text-white/90 hover:bg-white/[0.07]"
            >
              View on GitHub
            </a>
          </div>

          <p className="mt-5 text-xs text-white/45">
            Open source · macOS 14+ · Apple Silicon &amp; Intel{sizeLabel && ` · ${sizeLabel}`}
          </p>
        </section>

        {/* try saying */}
        <section className="mx-auto max-w-3xl pb-24">
          <div className="mb-6 flex items-center gap-2">
            <div className="h-px flex-1 bg-white/10" />
            <span className="text-xs uppercase tracking-[0.18em] text-white/40">Try saying</span>
            <div className="h-px flex-1 bg-white/10" />
          </div>
          <div className="overflow-hidden rounded-2xl border border-white/10 bg-white/[0.025] backdrop-blur">
            <ul className="divide-y divide-white/5 font-mono text-[13px] leading-relaxed">
              {EXAMPLES.map(([said, did], i) => (
                <li key={i} className="grid grid-cols-1 px-5 py-3.5 sm:grid-cols-[1fr_auto_1fr] sm:items-center sm:gap-5">
                  <span className="text-white/95">"{said}"</span>
                  <span className="hidden text-white/35 sm:inline">→</span>
                  <span className="text-white/55">{did}</span>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {/* features */}
        <section className="grid grid-cols-1 gap-5 pb-24 sm:grid-cols-3">
          <Feature
            title="Voice-first, no wake word"
            body="Push-to-talk on Ctrl+Option. Hold, talk, release. No always-listening microphone, no false triggers, no battery drain."
          />
          <Feature
            title="Lives under the notch"
            body="A Dynamic-Island-style pill anchored to the menu bar. Animates color and shape per state: idle, listening, thinking, speaking."
          />
          <Feature
            title="Remembers you"
            body="Tell it your name, your default browser, your city — it persists those facts in a local file on your Mac, never uploaded anywhere."
          />
        </section>

        {/* how it works */}
        <section className="mx-auto max-w-3xl pb-24">
          <h2 className="mb-6 text-center text-xs uppercase tracking-[0.18em] text-white/40">How it works</h2>
          <ol className="space-y-3 text-[14px] leading-relaxed text-white/75">
            <Step n={1}>You hold <Kbd>⌃</Kbd><Kbd>⌥</Kbd> and speak. A pulsing pill appears under your notch.</Step>
            <Step n={2}>Audio is uploaded once to OpenAI Whisper for transcription. Not stored on your Mac.</Step>
            <Step n={3}>A gpt-4o-mini agent loop decides whether to <em>take action</em> (open an app, navigate a URL, control your system) or just <em>reply in voice</em>.</Step>
            <Step n={4}>Action runs locally via <code className="rounded bg-white/5 px-1.5 py-0.5 font-mono text-[12px]">/usr/bin/open</code> or AppleScript. Reply spoken via macOS <code className="rounded bg-white/5 px-1.5 py-0.5 font-mono text-[12px]">say</code>.</Step>
            <Step n={5}>The last 6 turns + your saved facts ride along so multi-turn questions work naturally.</Step>
          </ol>
        </section>

        {/* privacy */}
        <section className="mx-auto max-w-3xl pb-24">
          <div className="rounded-2xl border border-white/10 bg-white/[0.025] p-6 text-sm leading-relaxed text-white/70">
            <h3 className="mb-3 text-base font-semibold text-white">Privacy &amp; cost</h3>
            <ul className="space-y-2.5">
              <li>• Audio + transcripts are sent to OpenAI for processing. Their default policy is not to train on API data.</li>
              <li>• Your API key (<code className="rounded bg-white/5 px-1.5 py-0.5 font-mono text-xs">~/.majoor/config.json</code>) and persistent memory (<code className="rounded bg-white/5 px-1.5 py-0.5 font-mono text-xs">~/.majoor/memory.json</code>) live locally with <code className="rounded bg-white/5 px-1.5 py-0.5 font-mono text-xs">0600</code> permissions.</li>
              <li>• Text-to-speech is the built-in macOS <code className="rounded bg-white/5 px-1.5 py-0.5 font-mono text-xs">say</code> — free, instant, no third-party vendor.</li>
              <li>• Light personal use: roughly <strong>$0.05–$0.15 / day</strong> in OpenAI credit. STT is the bulk.</li>
            </ul>
          </div>
        </section>
      </main>

      <footer className="mx-auto w-full max-w-6xl border-t border-white/5 px-6 py-8">
        <div className="flex flex-col items-center justify-between gap-3 text-sm text-white/50 sm:flex-row">
          <span>
            Built by{" "}
            <a
              href="https://github.com/Vivek-Chaudhari30"
              target="_blank"
              rel="noopener noreferrer"
              className="text-white/70 hover:text-cyan-300"
            >
              Vivek Chaudhari
            </a>
          </span>
          <span className="font-mono text-xs">
            {release ? (
              <a
                href={release.html_url}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-cyan-300"
              >
                {release.tag_name}
              </a>
            ) : (
              "v—"
            )}
          </span>
        </div>
      </footer>
    </div>
  );
}

// ----- shared bits -----

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="mx-0.5 inline-flex h-[1.4em] min-w-[1.4em] items-center justify-center rounded-md border border-white/15 bg-white/[0.07] px-1.5 font-mono text-[0.78em] text-white/90 shadow-[inset_0_-1px_0_rgba(0,0,0,0.4)]">
      {children}
    </kbd>
  );
}

function Feature({ title, body }: { title: string; body: string }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.025] p-6 backdrop-blur transition-colors hover:bg-white/[0.04]">
      <h3 className="mb-2 text-[15px] font-semibold text-white">{title}</h3>
      <p className="text-[13.5px] leading-relaxed text-white/65">{body}</p>
    </div>
  );
}

function Step({ n, children }: { n: number; children: React.ReactNode }) {
  return (
    <li className="flex gap-4">
      <span className="mt-0.5 flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full border border-white/15 bg-white/[0.04] font-mono text-[11px] text-white/60">
        {n}
      </span>
      <span>{children}</span>
    </li>
  );
}

function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M12 4v12" />
      <path d="m7 11 5 5 5-5" />
      <path d="M5 20h14" />
    </svg>
  );
}

const EXAMPLES: [string, string][] = [
  ["Open gmail.com in Safari", "Safari opens Gmail"],
  ["What does API stand for?", "Application Programming Interface."],
  ["Mute the volume", "Volume muted"],
  ["My name is Vivek", "Got it. I'll remember that."],
  ["What's my name?", "Vivek."],
  ["Toggle dark mode", "Theme flips"],
  ["Lock my mac", "Screen locks"],
  ["Thanks Majoor", "Anytime."],
];
