# turso — Turso送信層

- token取得、SQL builder、HTTP送信、events/logsのspool再送を所有する。
- board DBのスキーマ変更DDLは `migrations/*.sql` に置く。適用は人間が `turso db shell personal-os-board < ファイル` で行う（本番DB書込は人間ゲート）。
- デイリーMarkdownを直接読み書きしない。受け取ったrow・event・entryだけを送る。
- 送信失敗は呼び出し元のMarkdown確定を巻き戻さない。
- `CLAUDE.md` はこのファイルへの相対symlinkにする。
