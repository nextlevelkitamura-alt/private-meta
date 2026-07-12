#!/bin/bash
# pptx-to-svg.sh — .pptx を LibreOffice headless で各スライドの SVG に変換する

set -euo pipefail

PPTX=""
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --pptx) PPTX="$2"; shift 2 ;;
    --out)  OUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PPTX" || -z "$OUT_DIR" ]]; then
  echo "Usage: pptx-to-svg.sh --pptx path.pptx --out output-dir/" >&2
  exit 1
fi

PPTX="$(realpath "$PPTX")"

# LibreOffice のパスを探す
LIBREOFFICE=""
for candidate in \
  "/Applications/LibreOffice.app/Contents/MacOS/soffice" \
  "$(which libreoffice 2>/dev/null || true)" \
  "$(which soffice 2>/dev/null || true)"; do
  if [[ -x "$candidate" ]]; then
    LIBREOFFICE="$candidate"
    break
  fi
done

if [[ -z "$LIBREOFFICE" ]]; then
  echo "LibreOffice が見つかりません。以下でインストールしてください:" >&2
  echo "  brew install --cask libreoffice" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "→ LibreOffice で SVG 変換中: $PPTX"
"$LIBREOFFICE" --headless --convert-to svg --outdir "$TMP_DIR" "$PPTX" 2>/dev/null

# 生成ファイルをゼロパディングしてリネーム
IDX=1
for SVG in "$TMP_DIR"/*.svg; do
  [[ -f "$SVG" ]] || continue
  DEST="$OUT_DIR/$(printf 'slide-%02d.svg' "$IDX")"
  cp "$SVG" "$DEST"
  echo "  $DEST"
  IDX=$((IDX + 1))
done

TOTAL=$((IDX - 1))
echo "✓ $TOTAL 枚の SVG を $OUT_DIR に出力しました"
