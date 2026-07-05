#!/usr/bin/env bash
# renderer / carry-tomorrow — 前日デイリーの「## 明日へ」節を当日デイリーの逆算直後
# （## 今日のTODO の直前）に auto:tomorrow-carry マーカーで囲って冪等に転記する。
#
# 挙動（決定的・冪等・非AI）:
#   - 前日の「## 明日へ」に中身があれば、当日の逆算直後へ転記区画を作る（begin/endで囲む）。
#     区画は set-marker-block と違い、テンプレに予め埋め込まず、中身があるときだけ動的に生成する
#     （前日が空なら空のauto区画を残さないため。plan.md 方針3/4）。
#   - 前日デイリーが無い／「## 明日へ」が空（空行・裸の箇条書き記号のみ・HTMLコメントのみ）なら、
#     転記区画は生成しない。既に古い区画があれば除去する（前日が空になった追従）。
#   - マーカー外の人間行・他のauto区画は一切変更しない。
#   - 挿入は「区画＋空行1つ」、除去は「区画＋直後の空行1つ」を厳密に逆操作にしてあり、
#     何度実行しても収束する（2回目以降の差分ゼロ）。
#
# 転記元の「## 明日へ」節は末尾セクション（人間手書き欄・autoマーカー無し）。見出しは厳密一致で
# 判定するため「## 明日への繰越タスク」等の旧見出しには誤反応しない。
# アンカー「## 今日のTODO」が無いファイル（旧形式等）は警告のみで区画を作らずスキップする。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"

daily_file="${1:?usage: carry-tomorrow.sh <daily-file> <YYYY-MM-DD>}"
date_str="${2:?date required}"

BEGIN_RE='^<!-- auto:tomorrow-carry:begin'
END_RE='^<!-- auto:tomorrow-carry:end -->'
BEGIN_LINE='<!-- auto:tomorrow-carry:begin — renderer: 前日デイリーの「## 明日へ」を朝に転記。人間はマーカー外に書く -->'
END_LINE='<!-- auto:tomorrow-carry:end -->'
# 挿入位置のアンカー（当日デイリーの「## 今日のTODO」見出し・厳密一致）
ANCHOR_RE='^##[[:space:]]+今日のTODO[[:space:]]*$'

[ -f "$daily_file" ] || exit 0

# --- 当日ファイルの既存区画の健全性チェック（begin/endが揃っているか） ---
begin_count="$(grep -cE "$BEGIN_RE" "$daily_file" || true)"
end_count="$(grep -cE "$END_RE" "$daily_file" || true)"
if [ "$begin_count" != "$end_count" ]; then
  echo "警告: auto:tomorrow-carry マーカーが片方だけ／複数（begin=$begin_count end=$end_count）のためスキップ: $daily_file" >&2
  exit 0
fi
has_region=0
[ "$begin_count" -ge 1 ] && has_region=1

# --- 前日の「## 明日へ」節の中身を抽出（前後の空行・裸の箇条書き・コメントをトリム） ---
prev_date="$(LC_ALL=C date -j -v-1d -f '%Y-%m-%d' "$date_str" '+%Y-%m-%d' 2>/dev/null || echo '')"
content_tmp="$(mktemp "${TMPDIR:-/tmp}/carry-content.XXXXXX")"
trap 'rm -f "$content_tmp"' EXIT

meaningful=0
if [ -n "$prev_date" ]; then
  prev_file="$(daily_file_for "$prev_date")"
  if [ -f "$prev_file" ]; then
    awk '
      BEGIN { insec = 0; n = 0 }
      /^##[[:space:]]+明日へ[[:space:]]*$/ { insec = 1; next }
      insec && /^## / { insec = 0 }
      insec { lines[n++] = $0 }
      END {
        first = -1; last = -1
        for (i = 0; i < n; i++) {
          t = lines[i]
          sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
          if (t == "") continue                 # 空行
          if (t ~ /^<!--/) continue             # HTMLコメント
          c = t; sub(/^[-*+][[:space:]]*/, "", c)
          if (c == "") continue                 # 裸の箇条書き記号のみ（プレースホルダ）
          if (first < 0) first = i
          last = i
        }
        if (first < 0) exit 0                    # 中身なし → 何も出さない
        for (i = first; i <= last; i++) print lines[i]
      }
    ' "$prev_file" > "$content_tmp"
    [ -s "$content_tmp" ] && meaningful=1
  fi
fi

# 何もすることが無い（区画も無い・中身も無い）なら早期終了（無駄な書き換えを避ける）。
if [ "$has_region" -eq 0 ] && [ "$meaningful" -eq 0 ]; then
  exit 0
fi

# 転記する場合はアンカーが必要。無ければ区画を作らずスキップ（旧形式ファイル保護）。
# 既存区画があるなら中身の有無に関わらず除去はできる（アンカー不要）ので、meaningful時のみ要求する。
if [ "$meaningful" -eq 1 ] && ! grep -qE "$ANCHOR_RE" "$daily_file"; then
  echo "警告: アンカー『## 今日のTODO』が無いため転記をスキップ: $daily_file" >&2
  exit 0
fi

# --- 挿入する区画ブロックを組み立てる（meaningful時のみ） ---
block_tmp="$(mktemp "${TMPDIR:-/tmp}/carry-block.XXXXXX")"
trap 'rm -f "$content_tmp" "$block_tmp"' EXIT
if [ "$meaningful" -eq 1 ]; then
  {
    printf '%s\n' "$BEGIN_LINE"
    printf '### 明日へ（%s から）\n' "$prev_date"
    cat "$content_tmp"
    printf '%s\n' "$END_LINE"
  } > "$block_tmp"
fi

# --- 1パスで再構築（既存区画+直後の空行を除去 → meaningfulならアンカー直前へ再挿入） ---
out_tmp="$(mktemp "${daily_file}.carry.XXXXXX")"
trap 'rm -f "$content_tmp" "$block_tmp" "$out_tmp"' EXIT

awk -v begin_re="$BEGIN_RE" -v end_re="$END_RE" -v anchor_re="$ANCHOR_RE" \
    -v have_block="$meaningful" -v blockfile="$block_tmp" '
  BEGIN {
    nb = 0
    if (have_block == "1") {
      while ((getline l < blockfile) > 0) block[nb++] = l
      close(blockfile)
    }
    drop = 0; skip_blank = 0; inserted = 0
  }
  # 既存区画の除去（begin〜end を丸ごと落とす）
  $0 ~ begin_re { drop = 1; next }
  drop {
    if ($0 ~ end_re) { drop = 0; skip_blank = 1 }
    next
  }
  # 除去したendの直後に付いていた空行スペーサを1行だけ食う（挿入と逆操作にして冪等化）
  skip_blank == 1 {
    skip_blank = 0
    if ($0 ~ /^[[:space:]]*$/) { next }
    # 空行でなければこの行は通常処理へフォールスルー
  }
  # アンカー直前へ区画を挿入
  $0 ~ anchor_re && have_block == "1" && inserted == 0 {
    for (i = 0; i < nb; i++) print block[i]
    print ""
    inserted = 1
    print $0
    next
  }
  { print }
' "$daily_file" > "$out_tmp"

# 差分が無ければ mv しない（mtime churn 回避・冪等）
if cmp -s "$daily_file" "$out_tmp"; then
  exit 0
fi
mv "$out_tmp" "$daily_file"
trap 'rm -f "$content_tmp" "$block_tmp"' EXIT
echo "転記: auto:tomorrow-carry in $daily_file（前日 $prev_date）"
