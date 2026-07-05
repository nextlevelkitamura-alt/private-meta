#!/usr/bin/env bash
# renderer / plan-scan — AREAS_BASE配下（my-brain/areas/*/plans/active/*）を走査し、
# 計画ボード・待ち（着手可能）判定向けの正規化行を決定的に出力する（AIを呼ばない）。
# 単発 plan.md は "plan" 行、program.md は "program" 行＋子計画マップの "child" 行（1子=1行）を出す。
#
# 区切りは"|"（auto:logの既存"key=value|..."形式と同じ）。bashの `IFS=$'\t' read` はtabをIFS
# whitespace扱いするため連続tab（空欄フィールド＝優先未設定時）が畳まれてズレる実害があるため、
# tabではなく"|"を使う（実測で確認済み）。フィールド内の"|"は"/"へ置換して区切りと衝突させない。
#
# 出力:
#   plan|<area>|<優先(無ければ空)>|<計画名>|<plan.mdの絶対パス>
#   program|<area>|<優先(無ければ空)>|<program名>|<program.mdの絶対パス>
#   child|<子番号>|<子計画名>|<状態>|<所属program名>
#
# AREAS_BASEが無い環境は「対象0件」として exit 0（collect-done-cards.sh等の既存precedentと同じ扱い。
# クラッシュ・非0にはしない）。
set -euo pipefail

: "${AREAS_BASE:?AREAS_BASE required}"

[ -d "$AREAS_BASE" ] || exit 0

sanitize() {
  printf '%s' "$1" | tr '|\t\r\n' '////'
}

# 1行目の "分類: x ／ 種別: y ／ 優先: ◎" 等から 優先 の値だけを取り出す。無ければ空文字。
extract_priority() {
  awk '
    NR==1 {
      n = split($0, parts, "／")
      for (i = 1; i <= n; i++) {
        f = parts[i]
        gsub(/^[ \t]+|[ \t]+$/, "", f)
        if (index(f, "優先:") == 1) {
          v = substr(f, index(f, ":") + 1)
          gsub(/^[ \t]+|[ \t]+$/, "", v)
          print v
          exit
        }
      }
    }
  ' "$1"
}

extract_h1() {
  awk '/^# / { sub(/^# /, ""); print; exit }' "$1"
}

for area_dir in "$AREAS_BASE"/*/; do
  [ -d "$area_dir" ] || continue
  area="$(basename "$area_dir")"
  active_dir="${area_dir}plans/active"
  [ -d "$active_dir" ] || continue

  for plan_dir in "$active_dir"/*/; do
    [ -d "$plan_dir" ] || continue

    if [ -f "${plan_dir}program.md" ]; then
      pfile="${plan_dir}program.md"
      title="$(extract_h1 "$pfile")"
      [ -n "$title" ] || title="$(basename "$plan_dir")"
      title="$(sanitize "$title")"
      priority="$(sanitize "$(extract_priority "$pfile")")"
      printf 'program|%s|%s|%s|%s\n' "$area" "$priority" "$title" "$pfile"

      awk '
        BEGIN { insection = 0 }
        /^## 子計画マップ/ { insection = 1; next }
        insection && /^## / { insection = 0 }
        insection && /^[0-9][0-9]  / {
          no = substr($0, 1, 2)
          rest = substr($0, 5)
          n = split(rest, parts, "…")
          name = parts[1]
          cstatus = (n >= 2 ? parts[2] : "")
          gsub(/[ \t]+$/, "", name)
          gsub(/^[ \t]+/, "", cstatus)
          gsub(/[ \t]+$/, "", cstatus)
          gsub(/\|/, "/", name)
          gsub(/\|/, "/", cstatus)
          printf "%s|%s|%s\n", no, name, cstatus
        }
      ' "$pfile" | while IFS='|' read -r no name cstatus; do
        printf 'child|%s|%s|%s|%s\n' "$no" "$name" "$cstatus" "$title"
      done

    elif [ -f "${plan_dir}plan.md" ]; then
      pfile="${plan_dir}plan.md"
      title="$(extract_h1 "$pfile")"
      [ -n "$title" ] || title="$(basename "$plan_dir")"
      title="$(sanitize "$title")"
      priority="$(sanitize "$(extract_priority "$pfile")")"
      printf 'plan|%s|%s|%s|%s\n' "$area" "$priority" "$title" "$pfile"
    fi
  done
done
