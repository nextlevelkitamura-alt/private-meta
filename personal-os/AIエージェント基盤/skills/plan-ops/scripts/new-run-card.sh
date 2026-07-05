#!/usr/bin/env bash
# plan-ops / new-run-card — 計画(出所)から ai-jobs/ready に run-card 雛形を生成する。
#
# 痛点②対策: 出所(計画)の絶対パスを自動補完し、repo-aware の必須枠を漏れなく出す。
#            手書きの「出所パス間違い・項目漏れ」を防ぐ。形式は ai-jobs/AGENTS.md §2 準拠。
# secret は書かない（前提は env/CLI/サービス名のみ）。
set -euo pipefail

AIJOBS="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs"

usage() {
  cat >&2 <<'EOF'
usage: new-run-card --out <計画への絶対パス> [options]
  --out   <path>   出所＝計画(plan.md/program.md/子.md)の絶対パス（必須・実在チェック）
  --engine <name>  担当 codex|claude|orca（既定: codex）
  --repo  <path>   対象repoのルート絶対パス（既定: --out のgitルート）
  --branch <spec>  既存branch / feature/xxx / worktree指定
  --title <slug>   カード名スラッグ（既定: 出所ファイル名から）
  --task  <text>   依頼本文（省略時は <…> プレースホルダ）
  --allow <text>   触ってよい範囲（省略時は <…>）
  --need  <text>   前提（env/CLI/サービス名のみ・値は書かない）

  対象repo が出所と同一repo かつ branch/need 未指定なら「最小形」を出す
  （対象repo/作業導線/ブランチ/前提 を省略）。別repo卒業時は全項目を埋める。
  生成先: ai-jobs/ready/<YYYYMMDD-HHMM>-<slug>.md（パスを stdout に出す）
EOF
  exit 2
}

out="" engine="codex" repo="" branch="" title="" task="" allow="" need=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:-}"; shift 2;;
    --engine) engine="${2:-}"; shift 2;;
    --repo) repo="${2:-}"; shift 2;;
    --branch) branch="${2:-}"; shift 2;;
    --title) title="${2:-}"; shift 2;;
    --task) task="${2:-}"; shift 2;;
    --allow) allow="${2:-}"; shift 2;;
    --need) need="${2:-}"; shift 2;;
    -h|--help) usage;;
    *) echo "不明なオプション: $1" >&2; usage;;
  esac
done

[ -n "$out" ] || { echo "--out（出所の絶対パス）は必須" >&2; usage; }
[ -e "$out" ] || { echo "出所が見つからない: $out" >&2; exit 1; }
case "$out" in /*) ;; *) echo "出所は絶対パスで指定: $out" >&2; exit 2;; esac

# 対象repo の既定 = 出所のgitルート
if [ -z "$repo" ]; then
  repo="$(git -C "$(dirname "$out")" rev-parse --show-toplevel 2>/dev/null || true)"
fi

# slug の既定 = 出所ファイル名（拡張子除去）
if [ -z "$title" ]; then
  base="$(basename "$out")"; title="${base%.*}"
fi
slug="$(printf '%s' "$title" | tr ' /' '--' | tr -cd '[:alnum:]ぁ-んァ-ヶ一-龠ー_-')"

stamp="$(date '+%Y%m%d-%H%M')"
mkdir -p "$AIJOBS/ready"
cardpath="$AIJOBS/ready/${stamp}-${slug}.md"
if [ -e "$cardpath" ]; then
  cardpath="$AIJOBS/ready/${stamp}-${slug}-$$.md"
fi

task="${task:-<自己完結した実行指示>}"
allow="${allow:-<触ってよいファイル / 範囲>}"

# 出所と対象repoが同一repo（出所がrepo配下） かつ branch/need 未指定 → 最小形
out_repo="$(git -C "$(dirname "$out")" rev-parse --show-toplevel 2>/dev/null || true)"
minimal=0
if [ -n "$repo" ] && [ "$repo" = "$out_repo" ] && [ -z "$branch" ] && [ -z "$need" ]; then
  minimal=1
fi

if [ "$minimal" = "1" ]; then
  cat > "$cardpath" <<EOF
担当: ${engine}
出所: ${out}
依頼: ${task}
許可: ${allow}
完了条件: 出所のレビュー項目を満たすこと
戻し方: worker_done + report-path（plan更新=対象repo側 / card状態=基盤ai-jobs側の2系統）
差し戻し上限: 2
EOF
else
  cat > "$cardpath" <<EOF
担当: ${engine}
出所: ${out}
対象repo: ${repo:-<作業するrepoのルート絶対パス>}
作業導線: ${repo:-<対象repo>}/AGENTS.md を先に読む
ブランチ: ${branch:-<既存branch / 新規 feature/xxx / worktree指定>}
依頼: ${task}
許可: ${allow}
前提: ${need:-<必要な env / CLI / サービス名のみ・値は書かない>}
完了条件: 出所のレビュー項目を満たすこと
戻し方: worker_done + report-path（plan更新=対象repo側 / card状態=基盤ai-jobs側の2系統）
差し戻し上限: 2
EOF
fi

echo "$cardpath"
