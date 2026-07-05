# session-start — 開始時の宣言手順

SessionStartフック（claude/session-start.py）がこの手順を注入する。
行の登録自体は UserPromptSubmit フック（claude/prompt-register.py）が最初のプロンプトで機械的に済ませる
（要約=プロンプト先頭24字・種別=その他）。エージェントは種別・要約を正す。

`<board>` = `~/Private/personal-os/AIエージェント基盤/hooks/session-board/board.py`。キーは注入メッセージに記載。

## エージェントの仕事

1. **開始**: 最初の意味ある依頼を理解した直後に1回、種別と要約を正す:
   `<board> update --key <キー> --type <計画|実装|レビュー|その他> --summary <依頼の1行要約>`
2. **節目（一区切り・機能完成）**: 「終わったこと」に時刻付きの子を入れ子で積む:
   `<board> log --key <キー> --repo <repo> --parent <タスク名> --entry <成果>`
   → 行は消えず🟢のまま続行。親は重複せず、同じ親の下に子が最新順で積まれる。
3. **途中変更**: 依頼内容が変わったら `<board> update` で要約・種別を書き換える（開始時刻は固定）。
4. **バックグラウンドのサブエージェントを使う時**: 起動したら `<board> flip --key <キー> --state sub`
   （🔵サブ稼働中・Stopで⏸にならず「裏で動いている」と区別される）。サブ完了通知で戻ったら
   `<board> flip --key <キー> --state run` で作業に戻す。

## 登録しないもの

- subagent／headless（`AIJOBS_RUN`）／スラッシュコマンド／空・添付のみ。

## してはいけないこと

- 他セッションの行に触れる／完全なsession id・SHA・secretを書く。
- 計画・実装セッションの計画置き場は plans/ 規約（GLOBAL_AGENTS.md §6）に従う（このmdはボード操作だけ）。
