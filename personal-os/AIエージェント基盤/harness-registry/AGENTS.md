# harness-registry

Claude / Codex / Focusmap など、複数runtimeと画面をまたぐ「実行ハーネス」の説明地図を置く場所。
ここでいうハーネスは、hook・loop・script・DB・UI がどうつながって1つの運用になるかを指す。

## 置くもの

- 横断運用の説明md
- 説明mdと同名の人間向け派生HTML
- runtimeごとの登録表、hook、loop、script、DB、UIの関係図
- 実行本体を変更する前に読む設計・運用メモ

## 置かないもの

- hook の実行本体。正本は `../hooks-registry/`
- loop の実行本体。正本は `../loops-registry/`
- custom agent 定義。正本は `../agents-registry/`
- Focusmapアプリの実装。正本は `../../../projects/active/focusmap/`
- credential、token、secret、認証値

## ファイル

- `focusmap-daily.md`: Focusmap デイリーダッシュボードに関係する Claude / Codex hook、loop、`board.py`、Turso、Focusmap UI の全体設計。
- `focusmap-daily.html`: `focusmap-daily.md` の人間向け図解。正本ではない。

## 運用ルール

- このフォルダのmdは説明地図であり、実行設定ではない。
- HTMLは同名mdの派生物としてだけ置く。AIの実行導線にしない。
- 挙動を変える時は、該当する正本 registry を変更する。
- このフォルダだけを更新しても、hook、loop、Focusmap画面の挙動は変わらない。
- 新しい説明mdを増やす時は、階層を増やさずこの直下に置く。
