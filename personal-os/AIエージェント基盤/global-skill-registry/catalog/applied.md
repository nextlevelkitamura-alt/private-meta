# 業務スキル / global

Globalの業務スキル索引。正本は `skills/`、作成・移行・削除履歴は `logs/` を見る。

## スキル名: `share-as-zip`
概要: Finderやコンソールのスクリーンショットなど、指定されたローカルファイルを元の名前のまま共有用ZIPにまとめ、デスクトップへZIPだけを作る。
近接・注意: 外部送信はしない。ZIP内の同名ファイルは自動改名せず確認する。

## スキル名: `slide`
概要: スライド・プレゼン資料を作る統合skill。A=ライト/B=しっかり/C=案件型（1枚ずつ壁打ち・旧project-slide-workflow吸収）の3モード。テンプレ庫（構成/レイアウト/差別化/ブランド）・PPTアドイン/NotebookLMエンジン選択・`副業/素材`連携。
近接・注意: 画像は `images-generate` 経由。素材正本は `~/Private/副業/素材/`、スライド管理スプシは外部。案件/キャリアはモードC。node_modules/memory/ログはgit非追跡。

## スキル名: `video-transcription`
概要: 動画・音声から編集用timestamp JSONを作り、字幕ブロックやテロップ編集に使える形へ整える。
近接・注意: メディア制作成果物を直接作るため `applied`。

## スキル名: `html`
概要: 回答・作業結果を、人間が見る1枚もののHTMLに整える統合窓口。通常のレポート・比較・ダッシュボードはquick/fullで作成し、メタ構造の説明・実装前合意は理解ゲートworkflowで同一HTMLを反復更新する。
近接・注意: 表示専用の成果物を直接作るため `applied`。正本(md)・同期対象(デイリー/計画)は対象外。メタ説明workflowは明示起動のみで、合意まで対象を編集しない。軽いすり合わせは `naiyou-suriawase`、問いで詰める壁打ちは `grill-me`。

## スキル名: `sns-post`
概要: SNSアカウント育成・投稿制作/編集・リサーチ・公開を、Googleスプレッドシート正本＋Buffer/Threads連携でmode別に回す業務オペ。
近接・注意: データ正本は外部スプシ、各repoの `.claude/sns-config.json`・`scripts/` に依存（repo-local設定は基盤に置かない）。露出はclaudeのみ（業務用途）。画像生成は `images-generate` 経由。

## スキル名: `images-generate`
概要: 画像生成の統合窓口。依頼を2分岐（A=一般/プロモ画像、B=開発/モックアップ）で判定し、どちらも Codex 組み込み `image_gen`（codex exec 経由・継続編集は exec resume）で生成する。
近接・注意: 最終エンジンは常に `image_gen`。A分岐＝5項目チェック→プロンプト確定、B分岐＝product-fidelity prompt。求人サムネ固有手順は仕事repo `scripts/job-create/docs/image-generation.md` へ移設済み（2026-07-11）。呼び出し元skill（job-new/sns-post/slide）からも使う。`disable-model-invocation: true`（明示/呼び出し起動）。
