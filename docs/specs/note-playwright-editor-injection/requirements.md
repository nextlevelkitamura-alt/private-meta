# note Playwright Editor Injection

## Summary

note下書き作成では、認証は通常Chromeアプリを非標準の専用user-data-dirで起動して行い、保存済みログインをPlaywright/CDPで再利用する。本文HTML投入・画像アップロード・保存確認もPlaywright/CDPで実行する。Computer Useはログイン補助と非常時のUI復旧に限定する。

## Related Requirements

- REQ-008: normal Chrome should be used for note authentication instead of Chrome for Testing.
- REQ-009: Playwright/CDP should be the primary editor execution path after authentication.

## Acceptance Criteria

- [x] 専用CDPプロファイル `.playwright/profiles/note-nextlevel` の保存済みログインを使ってnote編集画面を開ける。
- [x] CDP Chromeが未起動でも、安定下書きコマンドが専用プロファイルのChromeを起動してから接続できる。
- [x] Playwright/CDPで `draft-rich.html` を投入し、note本文でH2見出しがH2として残る。
- [x] Playwright/CDPでサムネ画像と本文画像をアップロードできる。
- [x] 下書き保存後、タイトル、H2数、本文画像数、サムネ検出、保存レスポンスを確認できる。
- [x] 公開ボタンは押さない。

## Non-Goals

- note公開の自動実行。
- Google OAuth、MFA、パスワード保存、Cookieコピーの回避や代替。
- Chrome for Testing、クローンプロファイル、Cookieコピー、デフォルトChrome `Profile 16` へのCDP直結を通常経路にすること。

## Impacted Surfaces

- `起業スキル/scripts/note-playwright.ts`
- `起業スキル/scripts/note-playwright-ui.ts`
- `起業スキル/scripts/set-html-clipboard.swift`
- `起業スキル/docs/note-ops-automation.md`
- `起業スキル/skills/note-create/SKILL.md`
- `起業スキル/skills/note-create/references/*`

## Open Questions

- なし。

## Completion Evidence Expected

- `npm run note-nextlevel-check` が `editor_visible: true` を返す。
- `npm run note-draft-stable ... --save` が `ok: true`、`save.ok=true`、H2数、サムネ数、本文画像数、`markersLeft=[]` を返す。
- 失敗時は `out/note-draft-runs/.../error.json` とスクリーンショットで原因を追える。
- 対象note下書きが公開されずに保存されている。

## Completion Evidence

- 2026-05-29: `npm run note-nextlevel-check -- --draft-url https://editor.note.com/notes/n353659c7038d/edit/` returned `logged_in: true`, `editor_visible: true`, and `note_cookie_count: 7`.
- 2026-05-29: `npm run note-create-draft-cdp -- ... --save` created `https://editor.note.com/notes/n353659c7038d/edit/`; save status was 201 and verification returned `h2: 4`, `bodyImages: 1`, and `heroDetected: true`.
- 2026-05-29: UI-only Playwright/CDP flow created `https://editor.note.com/notes/n477218781ba3/edit/`; save response was 201 and verification returned title OK, `h2: 7`, `heroCount: 1`, `bodyImages: 2`, `figures: 2`, `markers: []`, and `savedText: true`.
- 2026-05-29: `note-draft-stable` gained CDP auto-start for `.playwright/profiles/note-nextlevel`; `npm run note-draft-stable -- --help`, `npx tsc --noEmit --allowImportingTsExtensions false --skipLibCheck --module nodenext --moduleResolution nodenext --target es2022 note-playwright-ui.ts`, and `git diff --check` passed after the stable wrapper and artifact verification were added.
- 2026-05-29: `npm run note-candidate-board -- status --article-id 20260528-002 --status 下書き済み ...` updated the row, and `npm run note-sheet-setup` returned `ok: true`.
