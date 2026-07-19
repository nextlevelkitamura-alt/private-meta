#!/usr/bin/env bash
# plan-ops / plansync.py のテスト。合成fixture(tmp)のみを検査する。
# 実HOME・実デイリー・~/Private実ファイル・実DBには一切書き込まない（scan/dry-runのみ）。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
# shellcheck source=_test_lib.sh
source "$HERE/_test_lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SESSION_BOARD_STATE_DIR="$TMP/state"   # notices/spoolをtmpへ隔離（実stateに触れない）
AREAS="$TMP/areas"
ACT="$AREAS/testarea/plans/active"

# --- fixture: program計画 ---
PDIR="$ACT/2026-01-01-プログラム例"
mkdir -p "$PDIR/plans" "$PDIR/実装" "$PDIR/評価"
cat > "$PDIR/program.md" <<'EOF'
形態: program

# プログラム例

## 子計画マップ

- [x] 01 子いち … 完了
    場所: plans/01 ／ 依存: ―
- [ ] 02 子に … 実装
    場所: plans/02 ／ 依存: 01

## 完了条件

- [x] 条件A
- [ ] 条件B
- [ ] 条件C
EOF
printf '親計画: ../program.md\n\n# 子いち\n' > "$PDIR/plans/01-子いち.md"
printf '親計画: ../program.md\n\n# 子に\n' > "$PDIR/plans/02-子に.md"
printf '# 子いち評価01\n' > "$PDIR/plans/01-子いち-評価01.md"
printf '# 実装共通\n' > "$PDIR/実装/共通.md"
printf '# 統合評価01\n' > "$PDIR/評価/評価01.md"

# --- fixture: 単発計画 ---
SDIR="$ACT/2026-01-02-単発例"
mkdir -p "$SDIR"
cat > "$SDIR/plan.md" <<'EOF'
分類: skill ／ 種別: 新規作成

# 単発例

## 完了条件

- [ ] 単発条件1
- [ ] 単発条件2
EOF
printf '# 単発評価01\n' > "$SDIR/評価01.md"

# --- fixture: secret混入の単発計画（同期拒否される） ---
XDIR="$ACT/2026-01-03-秘密混入"
mkdir -p "$XDIR"
printf '# 秘密混入\n\nAKIAABCDEFGHIJKLMNOP という値がある。\n' > "$XDIR/plan.md"

# ============================================================
# (a) scan: kind分類の件数
# ============================================================
OUT="$("$SCRIPTS/plansync.py" scan --root "$AREAS" --repo-root "$TMP" 2>/dev/null)"
assert_contains "(a) programを1件抽出" "$OUT" "program=1"
assert_contains "(a) single 2件（単発例＋秘密混入）" "$OUT" "single=2"
assert_contains "(a) child 2件" "$OUT" "child=2"
assert_contains "(a) role 1件（実装共通のみ）" "$OUT" "role=1"
assert_contains "(a) eval 3件" "$OUT" "eval=3"

# ============================================================
# (b) 進捗集計: 子N/M・完了条件x/y・parse_ok
# ============================================================
assert_contains "(b) program進捗 子1/2・完了条件1/3" "$OUT" "2026-01-01-プログラム例: 子 1/2・完了条件 1/3・parse_ok=1"
assert_contains "(b) 単発進捗 子0/0・完了条件0/2" "$OUT" "2026-01-02-単発例: 子 0/0・完了条件 0/2・parse_ok=1"
assert_contains "(b) 完了条件節なしはparse_ok=0（本文閲覧は生きる）" "$OUT" "2026-01-03-秘密混入: 子 0/0・完了条件 0/0・parse_ok=0"

# ============================================================
# (c) secret疑い: 該当文書は同期拒否・値は非表示・通知が届く
# ============================================================
assert_contains "(c) secret拒否1件" "$OUT" "secret拒否: 1 件"
assert_contains "(c) 拒否理由ラベルを表示(値は非表示)" "$OUT" "aws_access_key"
assert_not_contains "(c) secret値そのものは出力しない" "$OUT" "AKIAABCDEFGHIJKLMNOP"
assert_contains "(c) 拒否文書はSECRET拒否フラグ付き" "$OUT" "[SECRET拒否]"
# 通知ログに1行残る（値は含めない）
NOTICES="$TMP/state/plansync-notices.log"
assert_eq "(c) 通知ログが作られる" "$( [ -f "$NOTICES" ] && echo yes || echo no )" "yes"
assert_not_contains "(c) 通知ログにsecret値を書かない" "$(cat "$NOTICES")" "AKIAABCDEFGHIJKLMNOP"

# 同期対象は 全10件 - 拒否1件 = 9件
assert_contains "(c) 同期対象8件" "$OUT" "同期対象(secret通過): 8 件"

# ============================================================
# (d) 差分sync(dry-run): activeから消えたpathはDELETE候補になる
# ============================================================
GONE="areas/testarea/plans/active/2026-01-09-消えた計画/plan.md"
DOUT="$("$SCRIPTS/plansync.py" sync --paths "$GONE" --root "$AREAS" --repo-root "$TMP" 2>/dev/null)"
assert_contains "(d) dry-run表記" "$DOUT" "dry-run"
assert_contains "(d) 消えたpathはDELETE候補" "$DOUT" "DELETE $GONE"

# ============================================================
# (e) 差分sync(dry-run): 変更pathだけに絞る
# ============================================================
CHG="areas/testarea/plans/active/2026-01-02-単発例/plan.md"
EOUT="$("$SCRIPTS/plansync.py" sync --paths "$CHG" --root "$AREAS" --repo-root "$TMP" 2>/dev/null)"
# 差分モードは送信対象を変更slugだけに絞る: doc1(単発plan) + progress1(単発slug) = 2文
assert_contains "(e) 送信対象は変更slugのみ=2文" "$EOUT" "想定送信文数(upsert+progress+delete): 2"

# ============================================================
# (f) filter_unchanged: content_hash一致docは送信スキップ・不一致/新規は送信・照会失敗は全送信
# ============================================================
FOUT="$(python3 - "$SCRIPTS" <<'PY'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("plansync", sys.argv[1] + "/plansync.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
class D:
    def __init__(self, path, h): self.path = path; self.content_hash = h
docs = [D("p1", "h1"), D("p2", "h2NEW"), D("p3", "h3")]
existing = {"p1": "h1", "p2": "h2OLD"}   # p1一致/skip, p2変更/送信, p3新規/送信
keep, skipped = m.filter_unchanged(docs, existing)
print("skip", skipped, "keep", ",".join(sorted(d.path for d in keep)))
keep2, skip2 = m.filter_unchanged(docs, None)   # 照会失敗=全送信
print("nofetch", skip2, len(keep2))
PY
)"
assert_contains "(f) 一致1件skip・p2/p3送信" "$FOUT" "skip 1 keep p2,p3"
assert_contains "(f) DB照会失敗時は全送信(skip0)" "$FOUT" "nofetch 0 3"

report
