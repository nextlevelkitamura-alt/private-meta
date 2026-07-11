---
name: images-generate
description: Codex組み込みのimage_genで画像を生成・編集する統合窓口。「画像を作って」「サムネ」「バナー」「モックアップ」「アプリ画面」「UI画像」などの依頼で使い、一般画像とプロダクトUI・画面の手順を振り分ける。
disable-model-invocation: true
---

# images-generate

画像の生成・編集は Codex 組み込み `image_gen` で行う。Claude 自身は画像を作れないため、Codex へ委任する。

## 生成の基本形

```bash
codex exec --json --skip-git-repo-check -C <作業dir> "image_gen で <プロンプト> を生成して保存パスを報告"
```

出力1行目の `thread.started` に含まれる `thread_id` を控える。

## 継続・編集

```bash
codex exec resume <thread_id> "<修正指示>"
```

前の画像を文脈に保ったまま編集する。新規 `exec` を投げ直さない。

## プロンプトのコツ

1. プロンプトは英語で書く。
2. 画像内テキストは短い英語にする。日本語は崩れやすい。
3. 複数枚は1プロンプト1生成で作る。
4. プロジェクトで使う画像は `~/.codex/generated_images/...` からワークスペースへコピーし、最終パスを報告する。

## 分岐

1. 一般画像は `workflows/general-image.md` を読む。
2. プロダクトUI・画面は `workflows/mockup.md` を読む。

## フォールバック

`image_gen` が使えない時だけ `references/chatgpt-arc-webbridge.md` を読む。
