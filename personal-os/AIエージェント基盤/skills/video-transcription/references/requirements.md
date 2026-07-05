# Local Video Transcription Requirements

## Feature Summary

Add a local, Apple Silicon-friendly transcription pipeline that converts video/audio files into canonical JSON with word-level `units`, then builds editing-oriented `caption_blocks` from those units.

## Related Requirements

- REQ-015: Local Whisper transcription should produce `segments`, `units`, and post-processed `caption_blocks` without LLM-generated timestamps.

## Acceptance Criteria

- `skills/video-transcription/scripts/extract_audio.py` extracts mono 16 kHz WAV audio with ffmpeg.
- `skills/video-transcription/scripts/transcribe_local.py` uses `mlx-whisper` and passes `word_timestamps=True` by default.
- `transcribe_local.py` accepts `--initial-prompt-file` for glossary/proper-noun recognition support only.
- Canonical transcript JSON contains `source`, `engine`, `metadata`, `segments`, `units`, `speech_blocks`, and `caption_blocks`.
- `units` are derived from `segments[].words[]` and are treated as the timestamp source of truth.
- `skills/video-transcription/scripts/build_caption_blocks.py` builds `caption_blocks` from `units`; `start` and `end` are copied from the first and last unit.
- Caption splitting does not ask Whisper or an LLM to create line breaks or timestamps.
- Docs cover macOS setup, model selection, workflow, alternatives, and quality checks.
- `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription` is the canonical source for the skill.
- Function-level tests verify caption block construction from dummy units.

## Non-Goals

- No GUI transcription app implementation.
- No WhisperX, stable-ts, speaker diarization, chunked long-form processing, SRT/ASS export, or Remotion integration in the initial implementation.
- No LLM-generated timestamps.
- No one-character timestamp generation.
- No API-key or paid external API requirement.

## Impacted Surfaces

- `skills/video-transcription/scripts/`
- `skills/video-transcription/schemas/`
- `skills/video-transcription/references/`
- `skills/video-transcription/tests/`
- `docs/requirements/requirements-ledger.md`
- `docs/requirements/progress-board.md`

## Open Questions

- Real-device benchmark results for M2 MacBook Air 16GB are not recorded yet.
- Actual `mlx-whisper` output shape should be verified against a sample file after dependencies are installed.

## Completion Evidence Expected

- `python -m unittest discover -s skills/video-transcription/tests -p 'test_*.py'` passes.
- `python skills/video-transcription/scripts/build_caption_blocks.py --input <dummy transcript> --output <out>` can create caption blocks without LLM calls.
- `python skills/video-transcription/scripts/transcribe_local.py --help` and `python skills/video-transcription/scripts/extract_audio.py --help` work without requiring `mlx-whisper` runtime inference.
