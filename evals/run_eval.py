#!/usr/bin/env python3
"""
Majoor eval harness.

Replays each case in cases.json against /v1/chat/completions using the SAME
system prompt and tool schemas the Swift app ships in its bundle
(Majoor/Resources/SystemPrompt.txt, Majoor/Resources/Tools.json) — single
source of truth, so eval scores cannot drift from the app.

Usage
-----
    pip install openai
    python evals/run_eval.py                          # tool_choice=auto  (post-refactor)
    python evals/run_eval.py --tool-choice required   # tool_choice=required  (current code / baseline)
    python evals/run_eval.py --model gpt-4o-mini      # override model
    python evals/run_eval.py --save baseline.json     # write per-case results to file

A case scores PASS when:
  - the model's chosen tool name matches `expected_behavior`, AND
  - if `expected_arg_contains` is non-empty, that substring (case-insensitive)
    appears anywhere in the JSON-serialised tool arguments

For `expected_behavior == "say"`, PASS means the model returned NO tool call
(plain assistant text). Today's chat() requires a tool, so all "say" cases
must FAIL in the baseline — that is the point of the eval.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import openai
except ImportError:
    sys.exit("Missing dependency. Run: pip install openai")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROMPT_PATH = PROJECT_ROOT / "Majoor" / "Resources" / "SystemPrompt.txt"
TOOLS_PATH = PROJECT_ROOT / "Majoor" / "Resources" / "Tools.json"
CASES_PATH = PROJECT_ROOT / "evals" / "cases.json"
CONFIG_PATH = Path.home() / ".majoor" / "config.json"


def load_api_key() -> str:
    """Mirror Config.swift: ~/.majoor/config.json first, then OPENAI_API_KEY env."""
    if CONFIG_PATH.exists():
        try:
            cfg = json.loads(CONFIG_PATH.read_text())
            key = cfg.get("openai_api_key")
            if key:
                return key
        except json.JSONDecodeError:
            pass
    env = os.environ.get("OPENAI_API_KEY", "")
    if env:
        return env
    sys.exit(
        f"No OpenAI API key found.\n"
        f"  Tried: {CONFIG_PATH}\n"
        f"  Tried: $OPENAI_API_KEY\n"
        f"Create one or the other and re-run."
    )


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Majoor chat router eval harness")
    p.add_argument(
        "--tool-choice",
        choices=["auto", "required", "none"],
        default="auto",
        help="OpenAI tool_choice. Use 'required' to match current Swift code (baseline).",
    )
    p.add_argument("--model", default="gpt-4o-mini", help="OpenAI chat model")
    p.add_argument("--temperature", type=float, default=0.2)
    p.add_argument("--save", type=Path, help="Optional path to write detailed JSON results")
    p.add_argument(
        "--only",
        help="Filter cases by category substring (e.g. 'chitchat', 'open_app')",
    )
    return p.parse_args()


def run_case(client: openai.OpenAI, *, system_prompt: str, tools: list,
             transcript: str, model: str, tool_choice: str, temperature: float) -> dict:
    """Return {actual_name, actual_args_str} where actual_name is 'say' if the
    model returned plain text instead of a tool call."""
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": transcript},
        ],
        tools=tools,
        tool_choice=tool_choice,
        temperature=temperature,
    )
    msg = resp.choices[0].message
    if msg.tool_calls:
        tc = msg.tool_calls[0]
        try:
            args = json.loads(tc.function.arguments or "{}")
        except json.JSONDecodeError:
            args = {}
        return {
            "actual_name": tc.function.name,
            "actual_args_str": json.dumps(args, ensure_ascii=False),
        }
    return {
        "actual_name": "say",
        "actual_args_str": (msg.content or "").strip(),
    }


def score(case: dict, result: dict) -> tuple[bool, bool, bool]:
    expected = case["expected_behavior"]
    expected_arg = (case.get("expected_arg_contains") or "").strip()
    actual = result["actual_name"]
    actual_args = result["actual_args_str"]

    name_ok = actual == expected
    if expected_arg:
        arg_ok = expected_arg.lower() in actual_args.lower()
    else:
        arg_ok = True
    return name_ok, arg_ok, name_ok and arg_ok


def main() -> int:
    args = parse_args()
    api_key = load_api_key()
    client = openai.OpenAI(api_key=api_key)

    system_prompt = PROMPT_PATH.read_text()
    tools = json.loads(TOOLS_PATH.read_text())
    cases = json.loads(CASES_PATH.read_text())

    if args.only:
        cases = [c for c in cases if args.only.lower() in c.get("category", "").lower()]

    print()
    print(f"  Majoor eval — {len(cases)} cases")
    print(f"  model        : {args.model}")
    print(f"  tool_choice  : {args.tool_choice}")
    print(f"  temperature  : {args.temperature}")
    print(f"  prompt       : {PROMPT_PATH.relative_to(PROJECT_ROOT)}")
    print(f"  tools        : {TOOLS_PATH.relative_to(PROJECT_ROOT)}")
    print(f"  cases        : {CASES_PATH.relative_to(PROJECT_ROOT)}")
    print()
    print(f"  {'#':>2}  {'cat':<16} {'expected':<18} {'actual':<18}  transcript")
    print(f"  {'-'*2}  {'-'*16} {'-'*18} {'-'*18}  {'-'*44}")

    results = []
    for i, case in enumerate(cases, 1):
        try:
            r = run_case(
                client,
                system_prompt=system_prompt,
                tools=tools,
                transcript=case["transcript"],
                model=args.model,
                tool_choice=args.tool_choice,
                temperature=args.temperature,
            )
            name_ok, arg_ok, passed = score(case, r)
        except Exception as e:
            r = {"actual_name": "<error>", "actual_args_str": str(e)[:120]}
            name_ok = arg_ok = passed = False

        mark = "PASS" if passed else "FAIL"
        cat = case.get("category", "")[:16]
        t = case["transcript"][:44]
        print(f"  {mark[:2]:>2}  {cat:<16} {case['expected_behavior']:<18} {r['actual_name']:<18}  {t}")
        if not passed:
            why = []
            if not name_ok:
                why.append(f"tool mismatch: wanted '{case['expected_behavior']}', got '{r['actual_name']}'")
            if not arg_ok:
                why.append(f"arg missing '{case.get('expected_arg_contains','')}'")
            print(f"        ↳ {'; '.join(why)}")
            if r["actual_args_str"]:
                print(f"        ↳ args/text: {r['actual_args_str'][:120]}")

        results.append({
            "case": case,
            "actual_name": r["actual_name"],
            "actual_args_str": r["actual_args_str"],
            "name_ok": name_ok,
            "arg_ok": arg_ok,
            "passed": passed,
        })

    n = len(results)
    n_pass = sum(1 for r in results if r["passed"])
    print()
    print(f"  Score: {n_pass}/{n} passed  ({100*n_pass/n:.0f}%)")

    # Per-category breakdown
    cats: dict[str, list] = {}
    for r in results:
        cats.setdefault(r["case"].get("category", "?"), []).append(r)
    print()
    print("  By category:")
    for c, rs in sorted(cats.items()):
        p = sum(1 for r in rs if r["passed"])
        print(f"    {c:<18} {p}/{len(rs)}")

    if args.save:
        args.save.write_text(json.dumps({
            "model": args.model,
            "tool_choice": args.tool_choice,
            "temperature": args.temperature,
            "total": n,
            "passed": n_pass,
            "results": results,
        }, indent=2, ensure_ascii=False))
        print(f"\n  Detailed results saved to: {args.save}")

    return 0 if n_pass == n else 1


if __name__ == "__main__":
    sys.exit(main())
