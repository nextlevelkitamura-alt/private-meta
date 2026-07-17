#!/usr/bin/env bash
# repoctl-check.sh — repo-registryの3点突合（実体repo・repo概要.md掲載・registeredログ）
#
# 突合内容:
#   (1) projects/{active,paused,archive}/ 直下のgit repoが repo概要.md に掲載されている
#   (2) repo概要.md の各エントリの `場所:` パスが実在する
#   (3) repo概要.md の各エントリの `登録:` ログファイルが実在する
#
# 状態台帳は作らない。読むだけ・書かない・非0終了でドリフトを知らせる。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE="$(cd "$HERE/../../../../.." && pwd)"                 # ~/Private
REGISTRY="$PRIVATE/personal-os/AIエージェント基盤/repo-registry"
OVERVIEW="$REGISTRY/repo概要.md"

fail_count=0
ok()   { printf 'OK  %s\n' "$1"; }
ng()   { printf 'NG  %s\n' "$1"; fail_count=$((fail_count + 1)); }
info() { printf -- '--  %s\n' "$1"; }

[ -f "$OVERVIEW" ] || { ng "repo概要.md が見つからない: $OVERVIEW"; exit 1; }

# repo概要.md から「- 場所: `path`」「- 登録: `path`」のbacktick内を抜き出す
extract_field() { # $1=フィールド名
  sed -n "s/^- $1: \`\([^\`]*\)\`.*$/\1/p" "$OVERVIEW"
}
locations="$(extract_field 場所)"
registrations="$(extract_field 登録)"

# (1) 実体repo → repo概要.md 掲載
for bucket in active paused archive; do
  dir="$PRIVATE/projects/$bucket"
  [ -d "$dir" ] || continue
  for repo in "$dir"/*/; do
    [ -e "$repo/.git" ] || continue    # git repoだけを対象（worktree置き場等は除外）
    rel="projects/$bucket/$(basename "$repo")/"
    if printf '%s\n' "$locations" | grep -Fxq "$rel"; then
      ok "掲載あり: $rel"
    else
      ng "repo概要.md に未掲載の実体repo: $rel"
    fi
  done
  if [ "$bucket" = paused ] && [ -f "$dir/MOVED_TO_EXTERNAL_SSD.md" ]; then
    info "paused実体は外部SSDへ退避済み（$dir/MOVED_TO_EXTERNAL_SSD.md）。退避repoはmovedログで説明する"
  fi
done

# (2) 掲載 → 実体パス実在
while IFS= read -r loc; do
  [ -n "$loc" ] || continue
  if [ -e "$PRIVATE/$loc" ]; then
    ok "場所が実在: $loc"
  else
    ng "repo概要.md の場所が実在しない: $loc"
  fi
done <<< "$locations"

# (3) 掲載 → registeredログ実在
while IFS= read -r reg; do
  [ -n "$reg" ] || continue
  if [ -f "$REGISTRY/$reg" ]; then
    ok "登録ログが実在: $reg"
  else
    ng "repo概要.md の登録ログが実在しない: $reg"
  fi
done <<< "$registrations"

if [ "$fail_count" -eq 0 ]; then
  printf '\nrepoctl-check: 全緑（実体・掲載・登録ログの3点が一致）\n'
  exit 0
fi
printf '\nrepoctl-check: NG %d件。repo概要.md と logs/ を同一作業単位で追従させてください\n' "$fail_count"
exit 1
