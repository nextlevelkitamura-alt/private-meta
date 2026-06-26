#!/usr/bin/env python3
"""Extract a Whisper-friendly audio track from video or audio input."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


DEFAULT_SAMPLE_RATE = 16000


def require_ffmpeg() -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit(
            "ffmpeg is not installed or not on PATH. On macOS, install it with: brew install ffmpeg"
        )


def extract_audio(
    input_path: str | Path,
    output_path: str | Path,
    *,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
    mono: bool = True,
    normalize: bool = False,
    overwrite: bool = True,
) -> Path:
    """Extract the first audio stream as WAV for local Whisper transcription."""
    require_ffmpeg()

    source = Path(input_path).expanduser()
    target = Path(output_path).expanduser()
    if not source.exists():
        raise FileNotFoundError(f"input file not found: {source}")

    target.parent.mkdir(parents=True, exist_ok=True)

    cmd = ["ffmpeg"]
    if overwrite:
        cmd.append("-y")
    else:
        cmd.append("-n")

    cmd.extend(["-i", str(source), "-vn", "-map", "0:a:0"])
    if normalize:
        cmd.extend(["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"])
    if mono:
        cmd.extend(["-ac", "1"])
    cmd.extend(["-ar", str(sample_rate), "-c:a", "pcm_s16le", str(target)])

    subprocess.run(cmd, check=True)
    return target


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract mono 16 kHz WAV audio for local Whisper transcription."
    )
    parser.add_argument("--input", required=True, help="Input video/audio file.")
    parser.add_argument(
        "--output",
        default="work/audio.wav",
        help="Output WAV path. Default: work/audio.wav",
    )
    parser.add_argument(
        "--sample-rate",
        type=int,
        default=DEFAULT_SAMPLE_RATE,
        help="Output sample rate. Default: 16000",
    )
    parser.add_argument(
        "--normalize",
        action="store_true",
        help="Apply ffmpeg loudnorm audio normalization.",
    )
    parser.add_argument(
        "--stereo",
        action="store_true",
        help="Keep stereo instead of converting to mono.",
    )
    parser.add_argument(
        "--no-overwrite",
        action="store_true",
        help="Fail if the output path already exists.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    audio_path = extract_audio(
        args.input,
        args.output,
        sample_rate=args.sample_rate,
        mono=not args.stereo,
        normalize=args.normalize,
        overwrite=not args.no_overwrite,
    )
    print(audio_path)


if __name__ == "__main__":
    main()
