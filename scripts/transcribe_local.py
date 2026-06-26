#!/usr/bin/env python3
"""Transcribe local media with mlx-whisper and emit the canonical JSON shape."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from extract_audio import extract_audio  # noqa: E402


DEFAULT_MODEL = "mlx-community/whisper-large-v3-turbo"
AUDIO_EXTENSIONS = {".aac", ".aif", ".aiff", ".flac", ".m4a", ".mp3", ".ogg", ".opus", ".wav"}


def is_audio_file(path: Path) -> bool:
    return path.suffix.lower() in AUDIO_EXTENSIONS


def ffprobe_duration(path: Path) -> float | None:
    if shutil.which("ffprobe") is None:
        return None
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(path),
    ]
    result = subprocess.run(cmd, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return None
    try:
        return round(float(result.stdout.strip()), 3)
    except ValueError:
        return None


def read_text_file(path: str | None) -> str | None:
    if not path:
        return None
    return Path(path).expanduser().read_text(encoding="utf-8").strip()


def round_time(value: Any) -> float:
    return round(float(value), 3)


def word_text(word: dict[str, Any]) -> str:
    return str(word.get("word") or word.get("text") or "").strip()


def word_probability(word: dict[str, Any]) -> float | None:
    value = word.get("probability", word.get("prob"))
    if value is None:
        return None
    try:
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None


def adapt_mlx_result(
    result: dict[str, Any],
    *,
    input_path: Path,
    audio_path: Path,
    model: str,
    language: str | None,
    word_timestamps: bool,
    processing_sec: float,
    started_at: str,
    duration_sec: float | None,
    condition_on_previous_text: bool,
) -> dict[str, Any]:
    segments: list[dict[str, Any]] = []
    units: list[dict[str, Any]] = []

    for segment_index, source_segment in enumerate(result.get("segments", []), start=1):
        segment_id = f"s{segment_index:06d}"
        segment_unit_ids: list[str] = []
        source_words = source_segment.get("words") or []

        for source_word in source_words:
            if not isinstance(source_word, dict):
                continue
            text = word_text(source_word)
            if not text:
                continue
            start = source_word.get("start")
            end = source_word.get("end")
            if start is None or end is None:
                continue

            unit_id = f"u{len(units) + 1:06d}"
            segment_unit_ids.append(unit_id)
            unit: dict[str, Any] = {
                "id": unit_id,
                "segment_id": segment_id,
                "start": round_time(start),
                "end": round_time(end),
                "text": text,
            }
            probability = word_probability(source_word)
            if probability is not None:
                unit["probability"] = probability
            units.append(unit)

        segments.append(
            {
                "id": segment_id,
                "start": round_time(source_segment.get("start", 0.0)),
                "end": round_time(source_segment.get("end", 0.0)),
                "raw_text": str(source_segment.get("text") or "").strip(),
                "unit_ids": segment_unit_ids,
            }
        )

    return {
        "source": {
            "input_path": str(input_path),
            "audio_path": str(audio_path),
            "duration_sec": duration_sec,
            "language": language,
        },
        "engine": {
            "name": "mlx-whisper",
            "model": model,
            "word_timestamps": word_timestamps,
            "condition_on_previous_text": condition_on_previous_text,
        },
        "metadata": {
            "created_at": started_at,
            "processing_sec": round(processing_sec, 3),
            "input_file": str(input_path),
            "audio_file": str(audio_path),
            "audio_duration_sec": duration_sec,
            "mlx_text": str(result.get("text") or "").strip(),
        },
        "segments": segments,
        "units": units,
        "speech_blocks": [],
        "caption_blocks": [],
    }


def transcribe(args: argparse.Namespace) -> dict[str, Any]:
    try:
        import mlx_whisper
    except ImportError as exc:
        raise SystemExit(
            "mlx-whisper is not installed. Set up a venv and run: pip install mlx-whisper"
        ) from exc

    input_path = Path(args.input).expanduser()
    if not input_path.exists():
        raise FileNotFoundError(f"input file not found: {input_path}")

    if is_audio_file(input_path) and not args.force_extract_audio:
        audio_path = input_path
    else:
        work_dir = Path(args.work_dir).expanduser()
        audio_path = work_dir / f"{input_path.stem}.wav"
        extract_audio(
            input_path,
            audio_path,
            sample_rate=args.sample_rate,
            normalize=args.normalize_audio,
        )

    initial_prompt = read_text_file(args.initial_prompt_file)
    started_at = datetime.now(timezone.utc).isoformat()
    start_time = time.perf_counter()

    transcribe_kwargs: dict[str, Any] = {
        "path_or_hf_repo": args.model,
        "language": args.language,
        "word_timestamps": args.word_timestamps,
        "condition_on_previous_text": args.condition_on_previous_text,
        "verbose": args.verbose,
    }
    if initial_prompt:
        transcribe_kwargs["initial_prompt"] = initial_prompt
    if args.temperature is not None:
        transcribe_kwargs["temperature"] = args.temperature
    if args.compression_ratio_threshold is not None:
        transcribe_kwargs["compression_ratio_threshold"] = args.compression_ratio_threshold
    if args.logprob_threshold is not None:
        transcribe_kwargs["logprob_threshold"] = args.logprob_threshold
    if args.no_speech_threshold is not None:
        transcribe_kwargs["no_speech_threshold"] = args.no_speech_threshold
    if args.hallucination_silence_threshold is not None:
        transcribe_kwargs["hallucination_silence_threshold"] = args.hallucination_silence_threshold

    result = mlx_whisper.transcribe(str(audio_path), **transcribe_kwargs)
    processing_sec = time.perf_counter() - start_time
    duration_sec = ffprobe_duration(audio_path)

    transcript = adapt_mlx_result(
        result,
        input_path=input_path,
        audio_path=audio_path,
        model=args.model,
        language=args.language,
        word_timestamps=args.word_timestamps,
        processing_sec=processing_sec,
        started_at=started_at,
        duration_sec=duration_sec,
        condition_on_previous_text=args.condition_on_previous_text,
    )

    if args.require_units and not transcript["units"]:
        raise SystemExit(
            "No word-level units were produced. Confirm --word-timestamps is enabled and mlx-whisper returned segments[].words[]."
        )
    return transcript


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run local mlx-whisper transcription and save canonical timestamp JSON."
    )
    parser.add_argument("--input", required=True, help="Input video/audio file.")
    parser.add_argument("--output", required=True, help="Output transcript JSON path.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"MLX Whisper model. Default: {DEFAULT_MODEL}")
    parser.add_argument("--language", default="ja", help="Language code. Default: ja")
    parser.add_argument(
        "--word-timestamps",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Request word-level timestamps from mlx-whisper. Default: true",
    )
    parser.add_argument(
        "--initial-prompt-file",
        help="Glossary prompt file for proper nouns and domain terms only.",
    )
    parser.add_argument(
        "--condition-on-previous-text",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Condition decoding on prior text. Default: false for long-form hallucination resistance.",
    )
    parser.add_argument("--work-dir", default="work", help="Work directory for extracted audio.")
    parser.add_argument("--force-extract-audio", action="store_true", help="Extract WAV even for audio inputs.")
    parser.add_argument("--sample-rate", type=int, default=16000, help="Extracted WAV sample rate.")
    parser.add_argument("--normalize-audio", action="store_true", help="Apply ffmpeg loudnorm before transcription.")
    parser.add_argument("--temperature", type=float)
    parser.add_argument("--compression-ratio-threshold", type=float, default=2.4)
    parser.add_argument("--logprob-threshold", type=float, default=-1.0)
    parser.add_argument("--no-speech-threshold", type=float, default=0.6)
    parser.add_argument("--hallucination-silence-threshold", type=float)
    parser.add_argument("--require-units", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--verbose", action=argparse.BooleanOptionalAction, default=False)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    transcript = transcribe(args)
    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(transcript, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(output_path)


if __name__ == "__main__":
    main()
