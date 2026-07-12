分類: repo ／ 種別: 既存改善 ／ 規模: ライト

# FocusMap出力レポート簡素化

## 目的

FocusMapデイリー/Turso同等性の成果物を、人間が読むHTMLレポート1枚だけに集約する。サイト雛形、依存パッケージ、ビルド生成物を抱えた重複出力をなくし、FocusMap本体と混同しない状態にする。

## 現状

- `outputs/meta-explain/2026-07/2026-07-11-focusmap-daily-turso-parity.html` は、2026-07-11 18:00更新のv6レポートであり、現時点で最も新しい本文。
- `outputs/sites/2026-07/focusmap-daily-turso-parity/` は、古いv1本文をサイト雛形で包んだ独立フォルダ。`node_modules/` 約772MBを含み、現在のレポート本文より古い。
- 同じ題名のPDFと、今回の調査用補助HTML 2枚があり、「この件の読むべき資料」が1枚に定まっていない。

## 方針

1. v6のmeta-explain HTMLを唯一のレポートとして残す。
2. 古いv1を含む `outputs/sites/2026-07/focusmap-daily-turso-parity/` を削除する。
3. 同題名のPDFと、この作業で作ったFocusMap出力の補助HTML 2枚を削除する。
4. FocusMap本体、他テーマのmeta-explain、Personal OS全体の構成レポートには触れない。

## 完了条件（レビュー項目）

- [x] `outputs/meta-explain/2026-07/2026-07-11-focusmap-daily-turso-parity.html` が残り、タイトルとv6表記を確認できる。
- [x] `outputs/sites/2026-07/focusmap-daily-turso-parity/` が存在しない。
- [x] 同題名PDFおよびFocusMap出力の補助HTML 2枚が存在しない。
- [x] `projects/active/focusmap/` と、他テーマのmeta-explain HTMLに変更がない。

## 結果

- 残した唯一の成果物: `AIエージェント基盤/outputs/meta-explain/2026-07/2026-07-11-focusmap-daily-turso-parity.html`（52KB、meta-explain v6）。
- 削除したもの: 古いv1のサイト雛形一式、同題名PDF、今回の補助HTML 2枚。
- 確認: `outputs/sites/` は空、`outputs/html/2026-07/` にFocusMap出力の補助HTMLは残っていない。`projects/active/focusmap/` は対象外として未変更。
