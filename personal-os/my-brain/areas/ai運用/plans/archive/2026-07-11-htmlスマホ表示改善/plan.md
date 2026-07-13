分類: skill ／ 種別: 既存改善

# htmlスマホ表示改善

## 目的

Codexで生成したself-contained HTMLを、ユーザーがスマホ・ブラウザ・URL表示を明示した時だけ、tmuxで保持したCloudflare Quick Tunnelから安全に提示できるようにする。新Skillは作らず、表示責務を既存 `html` Skillへ吸収し、`meta-explain` はその導線を参照する。

## 現状

- `html` はPC向けArtifactを既定とし、Codexからスマホで開けるURLを作る手順がない。
- `meta-explain` は出力を `html` に委譲済みだが、Artifact不可runtimeではローカルHTML提示までしか定義していない。
- 手動の `cloudflared` processはセッション終了時に消え、URLだけが残る事故が起きた。Focusmap repo-localのtmux型phone-previewでは会話終了後も維持できることを実測した。

## 方針

1. `html/SKILL.md` は70行以内のrouterを維持し、明示依頼・外部公開・検証済みURLという境界だけを5行追加する。
2. `html/workflows/mobile-preview.md` に、入力確認、再利用、起動、HTTPS/HTTP 200/title/tmux検証、停止、失敗時対応を書く。
3. `html/scripts/mobile_preview.py` を唯一の機械実装にし、対象HTMLだけを返すlocalhost serverとCloudflare Quick Tunnelを1つのtmux sessionで保持する。状態はrepo外cacheに置く。
4. `meta-explain/SKILL.md` は説明HTMLのスマホ表示を `html` のworkflowへ委譲する1行へ置換し、Cloudflare手順をコピーしない。
5. `html/SKILL.html` と `meta-explain/SKILL.html` を正本mdから再生成する。
6. description、Skill名、runtime露出、catalog、logsは変更しない。

## 完了条件（レビュー項目）

- [x] `html/SKILL.md` が70行以内で、スマホURLは明示依頼時だけ発行し、workflow/scriptを1階層参照している。
- [x] `meta-explain/SKILL.md` がCloudflare手順を持たず、スマホ表示を `html/workflows/mobile-preview.md` へ委譲している。
- [x] `mobile-preview.md` に開始・再利用・HTTPS/HTTP 200/title/tmux検証・停止・失敗時対応がある。
- [x] `mobile_preview.py` が単一HTMLだけを配信し、start/status/stopを冪等に扱い、secretやHTML本文をログへ出さない。
- [x] scriptの単体テストで依存欠落、公開対象不正、状態判定、tmux command構築、HTTP検証を確認できる。
- [x] 実地E2EでURLがHTTP 200かつtitle一致し、起動元command終了後もtmux sessionが生存し、stop後は終了する。
- [x] `html/SKILL.html` と `meta-explain/SKILL.html` が再生成され、正本mdへの導線と安全方針を人間向けに説明している。
- [x] 対象Skill関連7ファイル以外の既存変更を巻き戻していない。catalog/logs/runtime露出は変更不要と確認できる。

## 実装結果

- `html/SKILL.md` は55→60行。スマホURLの発行条件・検証・安全境界・workflow導線を5行追加した。
- `meta-explain/SKILL.md` は1行置換のみで、32行を維持した。Cloudflare手順は複製していない。
- 新規はworkflow 32行、runner 355行、単体テスト108行、`html/SKILL.html` 24行。`meta-explain/SKILL.html` は4行相当を更新した。
- 独立レビューの初回FAIL（テスト範囲不足）を受け、依存欠落・実HTTP 200/404・tmux command・curl 200/404・title不一致を追加。11件全PASS、再レビュー8/8 PASS。E2Eは `200 / 404 / title一致 / tmux alive / stop後stopped` を確認した。
- 新Skill、catalog、logs、runtime露出は追加していない。既存Skillの正本更新だけで全runtimeに反映される。
