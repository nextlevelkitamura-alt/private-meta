# 動画文字起こしワークフロー

## 正本データの考え方

編集用タイムスタンプの正本は `units` です。`segments` は Whisper の大きめのまとまりであり、50文字前後の segment だけに依存しません。

```text
video/audio
  -> ffmpeg audio extraction
  -> mlx-whisper word_timestamps=True
  -> canonical transcript JSON
  -> units-based caption_blocks
  -> subtitle/telop/cut editing inputs
```

## 役割分担

- Whisper: 音声認識、segment、word-level timestamp の取得。
- 後処理: 字幕分割、テロップ分割、`caption_blocks` 生成。
- LLM: 任せる場合でも誤字修正、句読点補正、固有名詞補正、`clean_text` 生成まで。

LLM に `start` / `end` を自由生成させません。`caption_blocks[].start` は最初の unit の `start`、`caption_blocks[].end` は最後の unit の `end` から機械的に決めます。

## JSON 構造

```json
{
  "source": {
    "input_path": "input/video.mp4",
    "audio_path": "work/audio.wav",
    "duration_sec": 123.45,
    "language": "ja"
  },
  "engine": {
    "name": "mlx-whisper",
    "model": "mlx-community/whisper-large-v3-turbo",
    "word_timestamps": true
  },
  "segments": [],
  "units": [],
  "speech_blocks": [],
  "caption_blocks": []
}
```

詳細な制約は同Skill内の `schemas/transcript.schema.json` を参照します。

## Caption Block 生成ルール

- 1 block は 0.8-3.0秒を目安にする。
- 日本語は 1 block 12-18文字程度を目安にする。
- 最大2行想定で `line_breaks` を作る。
- 無音が 0.4-0.6秒以上あれば区切り候補にする。
- 句読点、接続詞、話題転換を区切り候補にする。
- 固有名詞を途中で不自然に分割しない。
- 助詞だけを次 block に残さない。
- ただし時間が長くなりすぎる場合は自然な位置で分割する。

## 初期実装の範囲

初期実装は単一ファイル処理です。10-15分単位のチャンク処理、WhisperX/stable-ts、話者分離、SRT/ASS出力、Remotion連携は将来拡張です。

## 品質確認

同Skill内の `quality_check.md` を参照します。特に `units` が空の出力は編集用として失敗扱いにします。
