#!/usr/bin/env bash
# exec-audit — launchd 自動実行の「構造ドリフト」を決定的に検出する（AIなし・読み取りのみ）。
# ドリフト有り: レポート出力 ＋ 出力先スイッチ（既定=inbox）＋ ntfy(任意)。
#   - inbox（既定）: 当日デイリーの「## 依頼インボックス」節へ、1ドリフト種別=1行で追記する
#     （inbox-patrol が未処理行として拾える書式。当日デイリー／同節が無ければ勝手に作らず警告して非0終了）。
#   - readycard（温存・旧経路）: ai-jobs/ready に担当:orca カードを投下する。
# ドリフト無し: 静かに終了。冪等: 同一内容の行/カードが既にあれば新規投下しない。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../daily-digest/scripts/_paths.sh"

LA="$HOME/Library/LaunchAgents"
BASE="$HOME/Private/personal-os/AIエージェント基盤"
SHIGOTO="$HOME/Private/projects/active/仕事"
READY="$BASE/loops-registry/ai-jobs/ready"
OUTDIR="$BASE/loops-registry/loops/exec-audit/output/logs"
PREF='com\.(kitamura|nextlevel|work)\.'
# dispatcher に統合済みの子（単独ロード＋dispatcher稼働＝二重稼働候補）
CHILDREN="com.nextlevel.entry-schedule com.nextlevel.job-update.schedule com.nextlevel.keep-alive com.nextlevel.monthly-schedule-generator com.nextlevel.job-patrol"

# 出力先スイッチ（既定=inbox）。readycard は旧経路（ai-jobs/ready へのカード投下）を温存する。
EXEC_AUDIT_OUTPUT="${EXEC_AUDIT_OUTPUT:-inbox}"

# 依頼インボックスのマーカー流儀（正本: ../../renderer/templates/デイリー.md ／ ../../inbox-patrol/scripts/patrol.sh）
INBOX_CLAIM_MARKER='→処理中('
INBOX_FINAL_MARKER='→計画作成済み('
INBOX_DUP_MARKER='→重複('

mkdir -p "$OUTDIR"
ts="$(date '+%Y-%m-%d %H:%M')"; day="$(date '+%Y%m%d')"

# --- 実態を集める ---
loaded="$(launchctl list 2>/dev/null | awk 'NR>1{print $3}' | grep -E "^$PREF" | sort -u)"
libp="$(ls "$LA" 2>/dev/null | grep -E "^$PREF.*\.plist$" | sed 's/\.plist$//' | sort -u)"
srcs="$( { find "$BASE/loops-registry" -name 'com.kitamura.*.plist' 2>/dev/null
           find "$SHIGOTO/scripts" \( -name 'com.nextlevel.*.plist' -o -name 'com.work.*.plist' \) -not -path '*/node_modules/*' 2>/dev/null; } \
         | while read -r f; do basename "$f" .plist; done | sort -u )"

has(){ printf '%s\n' "$2" | grep -qxF "$1"; }
drift=""; info=""
count_broken=0; count_orphan=0; count_dup=0
add_drift(){
  local type="$1" msg="$2"
  drift="${drift}- $msg"$'\n'
  case "$type" in
    broken) count_broken=$((count_broken + 1)) ;;
    orphan) count_orphan=$((count_orphan + 1)) ;;
    dup)    count_dup=$((count_dup + 1)) ;;
  esac
}
add_info(){ info="${info}- $1"$'\n'; }

# 壊れplist（要対応）
while IFS= read -r p; do [ -z "$p" ] && continue
  plutil -lint "$LA/$p.plist" >/dev/null 2>&1 || add_drift broken "壊れplist: \`$p\`（plutil -lint 失敗・要削除/再生成）"
done <<< "$libp"

# 正本plist無し=orphan（要対応）: ~/Library にあるが repo に生成元が無い
while IFS= read -r p; do [ -z "$p" ] && continue
  has "$p" "$srcs" || add_drift orphan "正本plist無し(orphan): \`$p\`（~/Library にあるが repo に生成元plist無し＝手動配置/要整理）"
done <<< "$libp"

# 二重稼働候補（要対応）
if has "com.nextlevel.dispatcher" "$loaded"; then
  for c in $CHILDREN; do
    has "$c" "$loaded" && add_drift dup "二重稼働候補: \`$c\` が単独ロード＋dispatcher内部でも実行（別ロック＝両走の恐れ）"
  done
fi

# 参考（多くは意図的）: 未ロード / 未インストール
while IFS= read -r p; do [ -z "$p" ] && continue
  has "$p" "$loaded" || add_info "未ロード: \`$p\`（plistはあるが未ロード）"
done <<< "$libp"
while IFS= read -r p; do [ -z "$p" ] && continue
  has "$p" "$libp" || add_info "未インストール: \`$p\`（repo正本はあるが ~/Library 未配置）"
done <<< "$srcs"

# --- レポート（毎回・当日分を上書き）---
report="$OUTDIR/audit-$day.md"
{
  echo "# exec-audit $ts"; echo
  echo "## ドリフト（要対応）"; [ -n "$drift" ] && printf '%s' "$drift" || echo "- なし"; echo
  echo "## 参考（多くは意図的・dispatcher統合など）"; [ -n "$info" ] && printf '%s' "$info" || echo "- なし"
} > "$report"

if [ -z "$drift" ]; then
  echo "[exec-audit] $ts ドリフト無し（report: ${report}）"; exit 0
fi

# ============================================================
# 出力先: readycard（旧経路・温存。EXEC_AUDIT_OUTPUT=readycard で選択）
# ============================================================
output_readycard() {
  # --- 冪等: 未処理カードがあれば新規投下しない（フォルダごとのglobを個別に評価。一部フォルダ非マッチのls合成exit codeに依存しない）---
  shopt -s nullglob
  # local と配列リテラルを同一行にすると、bash 3.2（macOS既定）でnullglobが0件展開した際に
  # 配列がunbound扱いになるバグがある（実測確認済み）。宣言と代入を分離して回避する。
  local pending_cards
  pending_cards=( "$BASE"/loops-registry/ai-jobs/{ready,running,review,reviewing}/exec-audit-*.md )
  shopt -u nullglob
  if [ "${#pending_cards[@]}" -gt 0 ]; then
    echo "[exec-audit] $ts ドリフト有り・既存カード処理待ちのため新規投下せず（report: ${report}）"
    return 0
  fi

  local card="$READY/exec-audit-$day.md"
  cat > "$card" <<EOF
担当: orca
依頼: launchd 自動実行の構造ドリフトを確認し、正本(マニュアル/実行一覧)を現実に合わせるか、現実を正本へ戻すか判断して解消する。
許可: マニュアル/実行一覧mdの更新、launchd の enable/disable（業務ジョブは影響確認のうえ）
完了条件: 下記ドリフトが解消し、再度 audit.sh でドリフト無しになること
差し戻し上限: 2

## ドリフト（$ts 検出）
$drift
## 参考
${info:-- なし}

## 確認コマンド
- personal-os: launchctl list | grep com.kitamura
- nextlevel:   bash ~/Private/projects/active/仕事/scripts/launchd/status.sh
- 再監査:       bash ~/Private/personal-os/AIエージェント基盤/loops-registry/loops/exec-audit/scripts/audit.sh
EOF
  echo "[exec-audit] $ts ドリフト有り → カード投下: $card"
  return 0
}

# ============================================================
# 出力先: inbox（既定）— 当日デイリーの「## 依頼インボックス」節へ1ドリフト種別=1行で追記する。
# 冪等: マーカー付き(→処理中/→計画作成済み/→重複)を剥がしても同一内容の行が既にあれば追記しない。
# 節・当日デイリーが無い場合は勝手に作らず、警告して非0で終了する（単一writer原則・auto:*区画には触れない）。
# ============================================================

inbox_section_exists() {
  local file="$1"
  LC_ALL=C awk '
    /^## 依頼インボックス[ \t]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

# 依頼インボックス節内に、マーカーを剥がした上で $2 と完全一致する行があるか。
# LC_ALL=C の理由: macOS標準awk（one true awk）はUTF-8ロケール下で日本語文字列同士の `==` を
# 誤って真と判定することを実測で確認している（inbox-patrol/patrol.sh 同種コメント参照）。
inbox_line_exists() {
  local file="$1" target="$2"
  LC_ALL=C awk -v target="$target" -v claim="$INBOX_CLAIM_MARKER" -v final="$INBOX_FINAL_MARKER" -v dup="$INBOX_DUP_MARKER" '
    /^## 依頼インボックス[ \t]*$/ { insec=1; next }
    insec && /^## / { insec=0 }
    insec && /^- / {
      line=$0
      p=index(line, claim); if (p>0) line=substr(line,1,p-2)
      p=index(line, final); if (p>0) line=substr(line,1,p-2)
      p=index(line, dup);   if (p>0) line=substr(line,1,p-2)
      if (line == target) found=1
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

# 依頼インボックス節の末尾（次の "## " 見出し直前。無ければEOF）に1行追記する。他行・他区画には触れない。
insert_inbox_line() {
  local file="$1" newline="$2" tmp
  tmp="$(mktemp "${file}.XXXXXX")" || return 1
  LC_ALL=C awk -v newline="$newline" '
    /^## 依頼インボックス[ \t]*$/ { insec=1; print; next }
    insec && /^## / { print newline; insec=0; print; next }
    { print }
    END { if (insec) print newline }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

output_inbox() {
  local today daily_file
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  daily_file="$(daily_file_for "$today")"

  if [ ! -f "$daily_file" ]; then
    echo "[exec-audit] 警告: 当日デイリーが無いためインボックスへ追記できません（何もせず終了）: $daily_file" >&2
    return 1
  fi
  if ! inbox_section_exists "$daily_file"; then
    echo "[exec-audit] 警告: 当日デイリーに『## 依頼インボックス』節が無いため追記できません（何もせず終了）: $daily_file" >&2
    return 1
  fi

  local type label count line
  for type in broken orphan dup; do
    case "$type" in
      broken) count="$count_broken"; label="壊れplist" ;;
      orphan) count="$count_orphan"; label="正本plist無し(orphan)" ;;
      dup)    count="$count_dup";    label="二重稼働候補" ;;
    esac
    [ "$count" -gt 0 ] || continue
    line="- [exec-audit $today] ${label} ${count}件（詳細: ${report}）"
    if inbox_line_exists "$daily_file" "$line"; then
      echo "[exec-audit] 既にインボックスに同内容の行あり・追記スキップ: $line"
      continue
    fi
    if insert_inbox_line "$daily_file" "$line"; then
      echo "[exec-audit] $ts ドリフト有り → インボックスへ追記: $line"
    else
      echo "[exec-audit] 警告: インボックスへの追記に失敗: $daily_file" >&2
      return 1
    fi
  done
  return 0
}

case "$EXEC_AUDIT_OUTPUT" in
  readycard) output_readycard || exit 1 ;;
  *)         output_inbox || exit 1 ;;
esac

# --- ntfy（任意・NTFY_TOPIC 設定時のみ・値はenv経由）---
if [ -n "${NTFY_TOPIC:-}" ]; then
  n=$(printf '%s' "$drift" | grep -c '^- ')
  msg="launchd自動実行にドリフト${n}件。"
  case "$EXEC_AUDIT_OUTPUT" in
    readycard) msg="${msg}ai-jobs/ready のカードを確認。" ;;
    *)         msg="${msg}デイリーの依頼インボックスを確認。" ;;
  esac
  curl -s -H "Title: exec-audit: ドリフト${n}件" \
       -d "$msg" \
       "${NTFY_BASE_URL:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null 2>&1 || true
fi
exit 0
