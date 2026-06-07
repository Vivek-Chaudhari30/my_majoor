# Majoor eval harness

Replays voice-transcript cases against `/v1/chat/completions` using the **exact**
system prompt and tool schemas the Swift app ships in its bundle:

- `Majoor/Resources/SystemPrompt.txt`
- `Majoor/Resources/Tools.json`

Single source of truth — change the prompt or tools in one place, both the app
and the eval pick it up. No copy-paste drift.

## Setup

```bash
pip install openai
```

API key resolution mirrors the Swift app's `Config.swift`:

1. `~/.majoor/config.json` → `{"openai_api_key": "sk-..."}`
2. `$OPENAI_API_KEY` env var

## Usage

```bash
# Baseline (matches current Swift code: tool_choice = "required")
python evals/run_eval.py --tool-choice required --save evals/baseline.json

# Post-refactor (tool_choice = "auto", plain-text replies allowed)
python evals/run_eval.py --tool-choice auto --save evals/post_refactor.json

# Filter to one category
python evals/run_eval.py --only chitchat
```

## How scoring works

A case passes when:

- the model picks the expected tool name, **and**
- if `expected_arg_contains` is set, that substring appears in the JSON-encoded
  arguments (case-insensitive).

`expected_behavior == "say"` means we expect the model to return **plain text,
no tool call**. Under `tool_choice: required` that's impossible, so all "say"
cases are expected to FAIL in the baseline — that is the test of the refactor.

## Files

- `cases.json` — 25 labelled transcripts across 8 categories.
- `run_eval.py` — the runner. Reads prompt + tools + cases, hits the API per case, prints a table + per-category breakdown.
- `baseline.json` / `post_refactor.json` — generated per-case results (when `--save` is used). Gitignored.
