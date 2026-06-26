# Whisper モデル選定

## 標準

`mlx-community/whisper-large-v3-turbo`

M2 MacBook Air 16GB では、まずこのモデルを標準にします。精度と速度のバランスを優先し、AIニュース・開発系の短尺から中尺動画の一次文字起こしに使います。

## 軽量 fallback

候補:

- `mlx-community/whisper-small`
- `mlx-community/whisper-medium`
- `mlx-community/whisper-base`
- `mlx-community/whisper-tiny`

用途:

- 長尺の一次処理。
- 下書きの粗起こし。
- 発熱やメモリ使用量を抑えたい場合。
- large-v3-turbo が遅すぎる、またはメモリ圧迫が強い場合。

## 重め

候補:

- `mlx-community/whisper-large-v3`

用途:

- 重要動画の最終確認。
- 固有名詞や聞き取りづらい音声の再処理。

注意:

- M2 Air 16GB では熱、処理時間、メモリ圧迫を確認する。
- 長尺動画ではチャンク処理を入れるまでは無理に使わない。

## ベンチマーク方針

まず同じ素材で以下を試します。

1. 5分動画
2. 20分動画
3. 50分動画

記録する項目:

- 処理時間
- メモリ体感、swap、発熱
- 文字起こし精度
- 固有名詞の認識
- `units` の粒度
- タイムスタンプずれ
- `caption_blocks` の自然さ

必要になったら `docs/benchmark_results.md` を作り、モデル別に結果を残します。

## 代替候補

### whisper.cpp + Core ML

`whisper.cpp` は Core ML 対応で Apple Silicon 上の代替候補になります。公式 README では Core ML モデル生成後、`cmake -B build -DWHISPER_COREML=1` で Core ML support を有効化する手順が示されています。

参考: https://github.com/ggml-org/whisper.cpp

初期実装では採用しません。`mlx-whisper` の word-level timestamp と Python 自動化を第一候補にします。

### WhisperX / stable-ts

より高精度な alignment が必要になった場合の上位ルートです。

- WhisperX は VAD と forced alignment を使う word-level timestamp / diarization 系の候補。
- stable-ts は Whisper timestamp の安定化、forced alignment、gap adjustment 系の候補。

参考:

- https://github.com/m-bain/whisperX
- https://arxiv.org/abs/2303.00747
- https://github.com/jianfch/stable-ts

初期実装では入れません。まず `mlx-whisper` の `segments[].words[]` を正本 JSON に変換するところまでを完成範囲にします。
