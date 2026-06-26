# Local Video Transcription Requirements

## Feature Summary

Add a local, Apple Silicon-friendly transcription pipeline that converts video/audio files into canonical JSON with word-level `units`, then builds editing-oriented `caption_blocks` from those units.

## Related Requirements

- REQ-015: Local Whisper transcription should produce `segments`, `units`, and post-processed `caption_blocks` without LLM-generated timestamps.

## Acceptance Criteria

- `scripts/extract_audio.py` extracts mono 16 kHz WAV audio with ffmpeg.
- `scripts/transcribe_local.py` uses `mlx-whisper` and passes `word_timestamps=True` by default.
- `transcribe_local.py` accepts `--initial-prompt-file` for glossary/proper-noun recognition support only.
- Canonical transcript JSON contains `source`, `engine`, `metadata`, `segments`, `units`, `speech_blocks`, and `caption_blocks`.
- `units` are derived from `segments[].words[]` and are treated as the timestamp source of truth.
- `scripts/build_caption_blocks.py` builds `caption_blocks` from `units`; `start` and `end` are copied from the first and last unit.
- Caption splitting does not ask Whisper or an LLM to create line breaks or timestamps.
- Docs cover macOS setup, model selection, workflow, alternatives, and quality checks.
- `.claude/skills/video-transcription` exists and `.agents/skills/video-transcription` resolves to it.
- Function-level tests verify caption block construction from dummy units.

## Non-Goals

- No GUI transcription app implementation.
- No WhisperX, stable-ts, speaker diarization, chunked long-form processing, SRT/ASS export, or Remotion integration in the initial implementation.
- No LLM-generated timestamps.
- No one-character timestamp generation.
- No API-key or paid external API requirement.

## Impacted Surfaces

- `scripts/`
- `schemas/`
- `docs/`
- `.claude/skills/`
- `.agents/skills/`
- `tests/`
- `docs/requirements/requirements-ledger.md`
- `docs/requirements/progress-board.md`

## Open Questions

- Real-device benchmark results for M2 MacBook Air 16GB are not recorded yet.
- Actual `mlx-whisper` output shape should be verified against a sample file after dependencies are installed.

## Completion Evidence Expected

- `python -m unittest tests/test_build_caption_blocks.py` passes.
- `python scripts/build_caption_blocks.py --input <dummy transcript> --output <out>` can create caption blocks without LLM calls.
- `python scripts/transcribe_local.py --help` and `python scripts/extract_audio.py --help` work without requiring `mlx-whisper` runtime inference.
