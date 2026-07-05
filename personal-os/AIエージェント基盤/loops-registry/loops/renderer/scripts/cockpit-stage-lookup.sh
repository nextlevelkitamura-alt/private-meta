#!/usr/bin/env bash
# renderer / cockpit-stage-lookup.sh — cockpit段階イベント(COCKPIT_EVENTS_FILE)からレーン(worktree path)
# ごとの最新段階・最新管轄(owner)を引く共有ロジック。build-board-now.sh(auto:board-now)と
# notion-lanes.sh(N3b・レーン実況DB)が共用する（第2の収集実装を作らない＝段階/owner抽出はどちらも
# 下の _cockpit_collect_events 1箇所に集約し、公開関数はその結果を絞り込むだけ）。source専用
# （単体実行しない・呼び出し元が自分の $SCRIPT_DIR を設定済みである前提。build-board-now.sh/
# notion-lanes.sh はどちらも renderer/scripts/ 直下にあるため相対パスは同一に解決する）。
#
# 使い方:
#   source "$SCRIPT_DIR/cockpit-stage-lookup.sh"
#   stage_map="$(cockpit_latest_stage_by_worktree)"
#   stage="$(cockpit_lookup_stage "$stage_map" "<worktree path>")"
#   owner_map="$(cockpit_latest_owner_by_worktree)"
#   owner="$(cockpit_lookup_owner "$owner_map" "<worktree path>")"
COCKPIT_EVENTS_FILE="${COCKPIT_EVENTS_FILE:-$SCRIPT_DIR/../../../../skills/orca-cockpit/state/events.jsonl}"

# worktree path -> 最新段階\t最新owner のtab区切り行を出力する内部collector（event=sendのみ対象。
# stage/ownerはそれぞれ非nullの最新tsを個別採用＝一方だけ設定されたイベントでも他方の判定に
# 影響しない）。ownerキーが無い/nullの旧イベント（f2d5f7b以前）はowner欄が空のまま＝後方互換。
# 壊れた行は個別にskipし、ファイル自体が無い/全滅でも空出力のまま非0にしない（best-effort）。
_cockpit_collect_events() {
  [ -f "$COCKPIT_EVENTS_FILE" ] || return 0
  python3 - "$COCKPIT_EVENTS_FILE" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
latest_stage = {}
latest_owner = {}
try:
    with open(path, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                ev = json.loads(raw)
            except Exception:
                continue
            if not isinstance(ev, dict) or ev.get("event") != "send":
                continue
            worktree = ev.get("worktree")
            ts = ev.get("ts")
            if not worktree or not ts:
                continue
            stage = ev.get("stage")
            if stage:
                cur = latest_stage.get(worktree)
                if cur is None or ts > cur[0]:
                    latest_stage[worktree] = (ts, stage)
            owner = ev.get("owner")
            if owner:
                cur = latest_owner.get(worktree)
                if cur is None or ts > cur[0]:
                    latest_owner[worktree] = (ts, owner)
except Exception:
    pass
for worktree in sorted(set(latest_stage) | set(latest_owner)):
    stage = latest_stage.get(worktree, (None, ""))[1].replace("\t", " ").replace("\n", " ")
    owner = latest_owner.get(worktree, (None, ""))[1].replace("\t", " ").replace("\n", " ")
    print("%s\t%s\t%s" % (worktree, stage, owner))
PY
}

# worktree path -> 最新段階 のtab区切り行を出力する（event=send かつ stage非nullの最新tsのみ採用）。
cockpit_latest_stage_by_worktree() {
  _cockpit_collect_events | awk -F'\t' '$2 != "" { print $1 "\t" $2 }'
}

# worktree path -> 最新owner のtab区切り行を出力する（event=send かつ owner非nullの最新tsのみ採用）。
cockpit_latest_owner_by_worktree() {
  _cockpit_collect_events | awk -F'\t' '$3 != "" { print $1 "\t" $3 }'
}

# cockpit_lookup_stage <stage_map> <worktree path>
#   bash 3.2（macOS既定・連想配列非対応）互換のため、path\tstage の複数行文字列を線形lookupする。
cockpit_lookup_stage() {
  local stage_map="$1" target="$2" ev_path ev_stage
  [ -n "$stage_map" ] || return 0
  while IFS=$'\t' read -r ev_path ev_stage; do
    if [ "$ev_path" = "$target" ]; then printf '%s' "$ev_stage"; return 0; fi
  done <<< "$stage_map"
}

# cockpit_lookup_owner <owner_map> <worktree path>
#   cockpit_lookup_stage と同型の線形lookup（bash 3.2連想配列非対応の回避）。
cockpit_lookup_owner() {
  local owner_map="$1" target="$2" ev_path ev_owner
  [ -n "$owner_map" ] || return 0
  while IFS=$'\t' read -r ev_path ev_owner; do
    if [ "$ev_path" = "$target" ]; then printf '%s' "$ev_owner"; return 0; fi
  done <<< "$owner_map"
}
