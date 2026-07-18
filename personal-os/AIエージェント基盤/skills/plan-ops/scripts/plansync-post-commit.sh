#!/usr/bin/env bash
# ~/Private の git post-commit hook 本体（子06 計画ミラー同期）。
#
# 役割: 直近コミットで変更された active計画md だけを inbox DB へ差分ミラーする。
# 規律:
#   - 非ブロッキング: 何があっても exit 0（コミットを止めない）。
#   - 多重起動対策: plansync.py が fcntl で自前ロック（取れなければ黙ってスキップ）。
#   - 送信失敗: plansync.py が専用spool(plansync-spool)へ退避し次回再送（inbox宛senderで隔離）。
#   - 適用は inbox migration 適用後にのみ意味を持つ（未適用なら send 失敗→spool退避で無害）。
#
# 登録（人間ゲート・このスクリプトを直接 .git/hooks へは置かず symlink 露出）:
#   ln -s ../../personal-os/AIエージェント基盤/skills/plan-ops/scripts/plansync-post-commit.sh \
#         ~/Private/.git/hooks/post-commit
#   （既存 post-commit がある場合は追記方式にするか、chain スクリプトから呼び出す）
set -u

# symlink経由（.git/hooks/post-commit）で呼ばれても実体の場所を解決する
HOOK_SRC="$0"
[ -L "$HOOK_SRC" ] && HOOK_SRC="$(readlink -f "$HOOK_SRC" 2>/dev/null || echo "$HOOK_SRC")"
SELF="$(cd "$(dirname "$HOOK_SRC")" && pwd)"
REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO" ] || exit 0

# 直近コミットの変更ファイル（削除・改名も名前として拾う）。初回コミットは親が無いので全追跡扱い。
# core.quotepath=false: 日本語パスがoctalエスケープ+引用符で出て正規表現に落ちるのを防ぐ（2026-07-19実測修正）
if git -C "$REPO" rev-parse --verify -q HEAD~1 >/dev/null 2>&1; then
  CHANGED="$(git -C "$REPO" -c core.quotepath=false diff --name-only HEAD~1 HEAD 2>/dev/null)"
else
  CHANGED="$(git -C "$REPO" -c core.quotepath=false show --name-only --format= HEAD 2>/dev/null)"
fi

# active計画md だけへ絞る（areas/<area>/plans/active/<slug>/....md）
PATHS="$(printf '%s\n' "$CHANGED" \
  | grep -E 'personal-os/my-brain/areas/[^/]+/plans/active/[^/]+/.*\.md$' || true)"

[ -n "$PATHS" ] || exit 0

# 差分同期（--apply）。ロック・secret拒否・spool退避は plansync.py 側が担う。
# shellcheck disable=SC2046
python3 "$SELF/plansync.py" sync --paths $(printf '%s ' $PATHS) --apply >/dev/null 2>&1 || true

exit 0
