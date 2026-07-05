# Quality Check

Run these checks before using the transcript for subtitle, telop, or cut editing.

## Transcript Checks

- `units` is not empty.
- Every unit has `start`, `end`, and `text`.
- Unit timestamps are monotonically increasing.
- No unit has `end < start`.
- No unit is longer than 5 seconds unless the source audio truly contains a long continuous phrase.
- Segment `unit_ids` point to existing units.
- `source.duration_sec` roughly matches the source audio length when `ffprobe` is available.

## Caption Checks

- Every `caption_blocks[].start` equals the first referenced unit's `start`.
- Every `caption_blocks[].end` equals the last referenced unit's `end`.
- Caption blocks are usually 0.8-3.0 seconds.
- Caption blocks are usually 12-18 Japanese characters.
- No caption block is too short to read naturally.
- No caption block is too long for two-line display.
- No caption block contains only a particle such as `が`, `に`, `を`, or `は`.
- Proper nouns are not split unnaturally.

## Text Cleanup Checks

- `raw_text` and `clean_text` preserve the same meaning.
- `clean_text` has no hallucinated facts.
- Punctuation and proper-noun corrections do not change timing.

## Long Video Checks

For 50-minute videos, manually inspect early, middle, and late sections. Timestamp drift can grow over time, so do not approve the whole file from the opening section alone.
