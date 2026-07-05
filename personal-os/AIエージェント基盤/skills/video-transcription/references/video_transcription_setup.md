# ローカルWhisper文字起こしセットアップ

## 方針

本命は GUI アプリではなく、`mlx-whisper` + Python + `ffmpeg` による CLI 自動化です。MacWhisper などの GUI アプリは、手動確認・聞き直し・ざっくり比較の補助としては使えますが、編集用 JSON の正本生成には使いません。

Whisper には字幕分割を依頼しません。Whisper の役割は音声認識と word-level timestamp の取得までです。字幕、テロップ、12-18文字程度の `caption_blocks` は後処理で作ります。

## 確認した現行情報

- `mlx-whisper` は PyPI から `pip install mlx-whisper` で導入できます。
- `mlx_whisper.transcribe(audio, word_timestamps=True)` により、`output["segments"][0]["words"]` のような word-level timestamp を取得できます。
- Homebrew 公式 formula の ffmpeg インストール手順は `brew install ffmpeg` です。
- `mlx-whisper` の `path_or_hf_repo` には Hugging Face Hub の MLX Whisper モデル、またはローカルモデルディレクトリを指定できます。Hub repo を指定すると自動取得される場合があります。

参考:

- https://pypi.org/project/mlx-whisper/
- https://formulae.brew.sh/formula/ffmpeg

## macOS / Apple Silicon 手順

```sh
brew install ffmpeg

python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install mlx-whisper
```

Hugging Face の大きなモデル取得を安定させたい場合:

```sh
pip install "huggingface_hub[hf_xet]"
```

モデルを事前ダウンロードする場合:

```sh
huggingface-cli download \
  --local-dir models/whisper-large-v3-turbo \
  mlx-community/whisper-large-v3-turbo
```

ただし、通常は `scripts/transcribe_local.py --model mlx-community/whisper-large-v3-turbo` のように Hugging Face repo を渡せば、`mlx-whisper` 側で取得できます。

## 基本実行

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

字幕ブロック生成:

```sh
SKILL_DIR="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription"

python "$SKILL_DIR/scripts/build_caption_blocks.py" \
  --input output/transcript.json \
  --output output/transcript_with_captions.json \
  --max-chars 18 \
  --min-duration 0.8 \
  --max-duration 3.0
```

音声抽出だけを先に実行する場合:

```sh
SKILL_DIR="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription"

python "$SKILL_DIR/scripts/extract_audio.py" \
  --input path/to/video.mp4 \
  --output work/audio.wav
```

音量正規化が必要な場合:

```sh
SKILL_DIR="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription"

python "$SKILL_DIR/scripts/extract_audio.py" \
  --input path/to/video.mp4 \
  --output work/audio.wav \
  --normalize
```

## 失敗時の見る場所

- `units` が空: `--word-timestamps` が有効か、`mlx-whisper` の戻り値に `segments[].words[]` があるか確認する。
- ffmpeg がない: `brew install ffmpeg` 後、`ffmpeg -version` を確認する。
- 長尺で幻覚が出る: `--condition-on-previous-text false` のまま使い、`--no-speech-threshold` や `--hallucination-silence-threshold` を調整する。
- M2 Air 16GB で重い: `references/whisper_model_selection.md` の fallback モデルに落とす。
