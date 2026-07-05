#!/usr/bin/env python3
"""Build caption_blocks from canonical transcript units without AI timestamps."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable


DEFAULT_PROTECTED_TERMS = {
    "Claude Code",
    "Claude Opus",
    "Claude Sonnet",
    "GitHub Actions",
    "Instagram Reels",
    "YouTube Shorts",
    "Next.js",
    "TypeScript",
    "Playwright",
    "Remotion",
    "Supabase",
    "Vercel",
    "OpenAI",
    "Anthropic",
    "Genspark",
    "Manus",
    "Whisper",
    "Codex",
    "Gemini",
    "GitHub",
    "React",
    "Python",
    "ffmpeg",
    "TikTok",
    "note",
    "API",
    "SDK",
    "MLX",
}

PARTICLES = {
    "は",
    "が",
    "を",
    "に",
    "へ",
    "で",
    "と",
    "や",
    "も",
    "の",
    "から",
    "まで",
    "より",
    "だけ",
    "こそ",
    "しか",
}

PUNCTUATION = tuple("。.!！？?、，")


def text_len(text: str) -> int:
    return len("".join(text.split()))


def unit_text(unit: dict[str, Any]) -> str:
    return str(unit.get("clean_text") or unit.get("text") or "").strip()


def block_text(units: Iterable[dict[str, Any]]) -> str:
    return "".join(unit_text(unit) for unit in units).strip()


def duration(units: list[dict[str, Any]]) -> float:
    if not units:
        return 0.0
    return round(float(units[-1]["end"]) - float(units[0]["start"]), 3)


def is_particle(text: str) -> bool:
    return text.strip() in PARTICLES


def protected_no_space(terms: Iterable[str]) -> set[str]:
    return {"".join(term.split()) for term in terms if term.strip()}


def split_would_break_protected(
    current_units: list[dict[str, Any]],
    next_unit: dict[str, Any] | None,
    protected_terms: set[str],
) -> bool:
    if not current_units or next_unit is None:
        return False
    boundary = "".join((unit_text(current_units[-1]) + unit_text(next_unit)).split())
    wider_boundary = "".join(block_text(current_units[-2:] + [next_unit]).split())
    return any(
        term and (term == boundary or term == wider_boundary)
        for term in protected_terms
    )


def should_flush(
    current_units: list[dict[str, Any]],
    next_unit: dict[str, Any] | None,
    *,
    min_chars: int,
    max_chars: int,
    min_duration: float,
    max_duration: float,
    silence_gap: float,
    protected_terms: set[str],
) -> bool:
    if not current_units:
        return False
    current_text = block_text(current_units)
    current_duration = duration(current_units)

    if next_unit is None:
        return True

    next_gap = float(next_unit["start"]) - float(current_units[-1]["end"])
    next_text = unit_text(next_unit)
    combined_text = current_text + next_text
    last_text = unit_text(current_units[-1])

    if split_would_break_protected(current_units, next_unit, protected_terms):
        return current_duration >= max_duration

    if is_particle(last_text) or is_particle(next_text):
        return current_duration >= max_duration

    if current_duration >= max_duration:
        return True

    if current_duration >= min_duration and next_gap >= silence_gap and text_len(current_text) >= min_chars:
        return True

    if current_duration >= min_duration and current_text.endswith(PUNCTUATION):
        return True

    if text_len(combined_text) > max_chars and current_duration >= min_duration:
        return True

    return False


def make_line_breaks(text: str, max_line_chars: int) -> list[str]:
    if text_len(text) <= max_line_chars:
        return [text]

    chars = list(text)
    midpoint = max(1, len(chars) // 2)
    candidates = list(range(max(1, midpoint - 5), min(len(chars), midpoint + 6)))
    candidates.sort(key=lambda index: abs(index - midpoint))

    for index in candidates:
        left = "".join(chars[:index]).strip()
        right = "".join(chars[index:]).strip()
        if not left or not right:
            continue
        if left[-1] in PARTICLES or right in PARTICLES:
            continue
        return [left, right]

    return ["".join(chars[:midpoint]).strip(), "".join(chars[midpoint:]).strip()]


def make_caption_block(
    block_id: int,
    units: list[dict[str, Any]],
    *,
    max_line_chars: int,
) -> dict[str, Any]:
    raw_text = block_text(units)
    start = round(float(units[0]["start"]), 3)
    end = round(float(units[-1]["end"]), 3)
    return {
        "id": f"c{block_id:06d}",
        "start": start,
        "end": end,
        "unit_ids": [str(unit["id"]) for unit in units],
        "raw_text": raw_text,
        "clean_text": raw_text,
        "line_breaks": make_line_breaks(raw_text, max_line_chars),
        "duration_sec": round(end - start, 3),
    }


def build_caption_blocks(
    units: list[dict[str, Any]],
    *,
    min_chars: int = 6,
    max_chars: int = 18,
    min_duration: float = 0.8,
    max_duration: float = 3.0,
    silence_gap: float = 0.5,
    max_line_chars: int | None = None,
    protected_terms: Iterable[str] = DEFAULT_PROTECTED_TERMS,
) -> list[dict[str, Any]]:
    if not units:
        return []

    protected = protected_no_space(protected_terms)
    line_chars = max_line_chars or max_chars
    captions: list[dict[str, Any]] = []
    current: list[dict[str, Any]] = []

    for index, unit in enumerate(units):
        if unit_text(unit) == "":
            continue
        current.append(unit)
        next_unit = units[index + 1] if index + 1 < len(units) else None
        if should_flush(
            current,
            next_unit,
            min_chars=min_chars,
            max_chars=max_chars,
            min_duration=min_duration,
            max_duration=max_duration,
            silence_gap=silence_gap,
            protected_terms=protected,
        ):
            captions.append(
                make_caption_block(
                    len(captions) + 1,
                    current,
                    max_line_chars=line_chars,
                )
            )
            current = []

    if current:
        captions.append(
            make_caption_block(
                len(captions) + 1,
                current,
                max_line_chars=line_chars,
            )
        )

    return captions


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build caption_blocks from transcript units. Timestamps are copied from units only."
    )
    parser.add_argument("--input", required=True, help="Input transcript JSON.")
    parser.add_argument("--output", required=True, help="Output transcript JSON.")
    parser.add_argument("--min-chars", type=int, default=6)
    parser.add_argument("--max-chars", type=int, default=18)
    parser.add_argument("--min-duration", type=float, default=0.8)
    parser.add_argument("--max-duration", type=float, default=3.0)
    parser.add_argument("--silence-gap", type=float, default=0.5)
    parser.add_argument("--max-line-chars", type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).expanduser()
    transcript = json.loads(input_path.read_text(encoding="utf-8"))
    units = transcript.get("units") or []
    if not units:
        raise SystemExit("transcript.units is empty; cannot build caption_blocks.")

    transcript["caption_blocks"] = build_caption_blocks(
        units,
        min_chars=args.min_chars,
        max_chars=args.max_chars,
        min_duration=args.min_duration,
        max_duration=args.max_duration,
        silence_gap=args.silence_gap,
        max_line_chars=args.max_line_chars,
    )

    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(transcript, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(output_path)


if __name__ == "__main__":
    main()
