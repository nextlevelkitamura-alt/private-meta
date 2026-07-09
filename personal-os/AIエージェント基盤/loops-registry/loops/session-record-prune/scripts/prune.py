#!/usr/bin/env python3
# session-record-prune — 古いセッション記録(.jsonl)を保持日数超で ~/.Trash へ移す。
#
# 設計（記録削除loop・2026-07-08 裁定 / 2026-07-09 堅牢化）:
#   - 既定は dry-run（何も動かさず件数・解放容量だけ報告）。--apply で実移動。launchd入口は --apply 付き。
#   - 方式は削除(rm)でなく ~/.Trash へ移動（復旧余地を残す・OSが後で空にする）。
#   - 対象は指定2ディレクトリ配下の *.jsonl だけ。安全ガード（whole-root offload 対策込み）:
#       (a) ファイル自体が symlink のものは触らない。
#       (b) os.walk(followlinks=False) で symlink サブディレクトリへは降りない（循環・逃げ防止）。
#       (c) **Trash と同じボリューム上のファイルだけ対象**（st_dev 一致）。
#           → 外付けSSDへディレクトリごと退避しても、別ボリュームなので触らない＝内蔵へ逆流させない。
#   - 記録の中身は一切読まない（stat と move のみ・secret 混入なし）。ログは件数・容量・ディレクトリのみ。
#   - 全件移動に失敗したら exit 1（Trash が壊れている等の恒久無動作を launchd 側で検知できるように）。
#   - テスト用に環境変数で対象/ゴミ箱/保持日数を差し替え可能（実運用に触れない）。
#     PRUNE_TARGET_DIRS（":"区切り）／PRUNE_TRASH_DIR／PRUNE_DAYS。
import argparse
import glob  # noqa: F401  (後方互換のため残置。走査は os.walk)
import os
import shutil
import sys
import time

DEFAULT_DAYS = 30


def target_dirs():
    env = os.environ.get("PRUNE_TARGET_DIRS")
    if env:
        return [os.path.expanduser(p) for p in env.split(":") if p]
    return [os.path.expanduser("~/.codex/sessions"),
            os.path.expanduser("~/.claude/projects")]


def trash_dir():
    return os.path.expanduser(os.environ.get("PRUNE_TRASH_DIR", "~/.Trash"))


def retention_days():
    try:
        return int(os.environ.get("PRUNE_DAYS", str(DEFAULT_DAYS)))
    except ValueError:
        return DEFAULT_DAYS


def ref_device(trash):
    """Trash が乗るボリュームの device id。存在する最寄りの親を stat して求める。
    この device と一致するファイルだけを移動対象にする（別ボリューム＝外付け退避は触らない）。"""
    probe = os.path.abspath(trash)
    while probe and not os.path.exists(probe):
        parent = os.path.dirname(probe)
        if parent == probe:
            break
        probe = parent
    try:
        return os.stat(probe).st_dev
    except OSError:
        return os.stat(os.path.expanduser("~")).st_dev


def find_old(now, days, targets, ref_dev):
    """targets 配下の *.jsonl で mtime が (now - days) より古く、かつ ref_dev と同じボリューム上の
    実ファイルを [(path, size, target_dir), ...] で返す。symlink（ファイル/サブdir）は辿らない。"""
    cutoff = now - days * 86400
    out = []
    for d in targets:
        if not os.path.isdir(d):
            continue
        for dirpath, dirnames, filenames in os.walk(d, followlinks=False):
            for name in filenames:
                if not name.endswith(".jsonl"):
                    continue
                f = os.path.join(dirpath, name)
                try:
                    if os.path.islink(f):              # (a) ファイル symlink は触らない
                        continue
                    st = os.stat(f)
                    if st.st_dev != ref_dev:           # (c) 別ボリューム（外付け退避）は触らない
                        continue
                    if st.st_mtime < cutoff:           # ちょうど days 丁度は残す（strict）
                        out.append((f, st.st_size, d))
                except OSError:
                    continue
    return out


def move_to_trash(f, trash):
    """f を trash へ移動。名前衝突は連番付与で回避。cross-device は shutil.move で吸収。"""
    os.makedirs(trash, exist_ok=True)
    base = os.path.basename(f)
    dest = os.path.join(trash, base)
    if os.path.exists(dest):
        stem, ext = os.path.splitext(base)
        i = 1
        while os.path.exists(dest):
            dest = os.path.join(trash, f"{stem}-{i}{ext}")
            i += 1
    try:
        os.rename(f, dest)
    except OSError:
        shutil.move(f, dest)                          # cross-device フォールバック
    return dest


def _mb(n):
    return f"{n / 1_000_000:.1f}MB"


def main():
    ap = argparse.ArgumentParser(description="古いセッション記録を保持日数超で ~/.Trash へ移す")
    ap.add_argument("--apply", action="store_true",
                    help="実際に ~/.Trash へ移動する（既定は dry-run＝何も動かさない）")
    args = ap.parse_args()

    days = retention_days()
    targets = target_dirs()
    trash = trash_dir()
    now = time.time()
    ref_dev = ref_device(trash)
    old = find_old(now, days, targets, ref_dev)

    by_dir = {d: [0, 0] for d in targets}
    for f, sz, d in old:
        by_dir[d][0] += 1
        by_dir[d][1] += sz
    total = sum(sz for _, sz, _ in old)
    ts = time.strftime("%Y-%m-%d %H:%M", time.localtime(now))
    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"[session-record-prune] {ts} {mode} 保持{days}日超 → {trash}（同一ボリュームのみ）")
    for d in targets:
        c, s = by_dir[d]
        print(f"  {d}: {c}件 / {_mb(s)}")
    print(f"  合計: {len(old)}件 / {_mb(total)}")

    if not args.apply:
        print("  （dry-run: 何も移動していない。本番は --apply）")
        return 0

    moved = 0
    failed = 0
    for f, _, _ in old:
        try:
            move_to_trash(f, trash)
            moved += 1
        except OSError:
            failed += 1
            print(f"  skip(移動失敗): {os.path.basename(f)}")
    print(f"  移動完了: {moved}/{len(old)}件 / {_mb(total)} 相当")
    if old and moved == 0:
        print("  ⚠ 全件移動失敗（Trash が書けない等）。要確認。")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
