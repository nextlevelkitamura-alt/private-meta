---
name: video-transcription
description: Create local, editing-grade timestamped JSON from video/audio using mlx-whisper word timestamps, then build caption blocks from units without LLM-generated timestamps.
---

# video-transcription

Use this skill when converting video or audio into editing-oriented timestamp JSON for captions, telops, or cut-edit decisions.

## Core Rules

- Do not ask Whisper to split subtitles.
- Do not ask an LLM to generate timestamps.
- Run `mlx-whisper` with `word_timestamps=True`.
- Use `glossary.md` only as `initial_prompt` support for proper nouns and technical terms.
- Treat `units` as the timestamp source of truth.
- Build `caption_blocks` from `units` with post-processing.
- LLMs may only help with typo correction, punctuation, proper nouns, and `clean_text`.
- If only long 50-character segments exist, first verify word timestamps are enabled.
- If `units` is empty, fail or warn loudly before continuing.

## Default Commands

```sh
SKILL_DIR="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription"

python "$SKILL_DIR/scripts/transcribe_local.py" \
  --input path/to/video.mp4 \
  --output output/transcript.json \
  --model mlx-community/whisper-large-v3-turbo \
  --language ja \
  --word-timestamps \
  --initial-prompt-file "$SKILL_DIR/glossary.md"
```

```sh
SKILL_DIR="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription"

python "$SKILL_DIR/scripts/build_caption_blocks.py" \
  --input output/transcript.json \
  --output output/transcript_with_captions.json \
  --max-chars 18 \
  --min-duration 0.8 \
  --max-duration 3.0
```

## Model Defaults

- Standard: `mlx-community/whisper-large-v3-turbo`
- Fallback: small / medium / base equivalent MLX models
- Heavy review: large-v3 equivalent, only when M2 Air 16GB can tolerate heat and processing time

## Output Contract

Read `output_schema.md`. The short version:

- `segments`: Whisper's larger chunks.
- `units`: word-level timestamp units from `segments[].words[]`.
- `caption_blocks`: post-processed subtitle blocks derived from `units`.

## Quality Gate

Run the checks in `quality_check.md`. For editing workflows, empty `units` is a failure, not a minor warning.

## Future Extensions

- 10-15 minute chunk processing for long videos.
- WhisperX or stable-ts for higher-precision alignment.
- Speaker diarization.
- SRT/ASS export.
- Remotion integration.
