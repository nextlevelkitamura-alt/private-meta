#!/usr/bin/env python3
# session-record-prune — 古いセッション記録(.jsonl)を保持日数超で ~/.Trash へ移す。
#
# 設計（記録削除loop・2026-07-08 裁定）:
#   - 既定は dry-run（何も動かさず件数・解放容量だけ報告）。--apply で実移動。launchd入口は --apply 付き。
#   - 方式は削除(rm)でなく ~/.Trash へ移動（復旧余地を残す・OSが後で空にする）。
#   - 対象は指定2ディレクトリ配下の *.jsonl だけ。realpath で配下判定し symlink 逃げを封じる
#     （＝外付けへ退避された実体は realpath が外に出るため触らない＝安全側）。
#   - 記録の中身は一切読まない（stat と move のみ・secret 混入なし）。ログは件数・容量・ディレクトリのみ。
#   - テスト用に環境変数で対象/ゴミ箱/保持日数を差し替え可能（実運用に触れない）。
#     PRUNE_TARGET_DIRS（":"区切り）／PRUNE_TRASH_DIR／PRUNE_DAYS。
import argparse
import glob
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


def is_under(path, root):
    """realpath で path が root 配下か判定（symlink で外へ逃げるものは False＝触らない）。"""
    rp = os.path.realpath(path)
    rr = os.path.realpath(root)
    return rp == rr or rp.startswith(rr + os.sep)


def find_old(now, days, targets):
    """targets 配下の *.jsonl で mtime が (now - days) より古いものを [(path, size), ...] で返す。"""
    cutoff = now - days * 86400
    out = []
    for d in targets:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, "**", "*.jsonl"), recursive=True):
            try:
                if not os.path.isfile(f) or not is_under(f, d):
                    continue
                if os.path.getmtime(f) < cutoff:      # ちょうど days 丁度は残す（strict）
                    out.append((f, os.path.getsize(f)))
            except OSError:
                continue
    return out


def move_to_trash(f, trash):
    """f を trash へ移動。名前衝突は連番付与で回避。同一ボリューム前提だが cross-device も shutil で吸収。"""
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
    old = find_old(now, days, targets)

    by_dir = {d: [0, 0] for d in targets}
    for f, sz in old:
        for d in targets:
            if is_under(f, d):
                by_dir[d][0] += 1
                by_dir[d][1] += sz
                break
    total = sum(sz for _, sz in old)
    ts = time.strftime("%Y-%m-%d %H:%M", time.localtime(now))
    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"[session-record-prune] {ts} {mode} 保持{days}日超 → {trash}")
    for d in targets:
        c, s = by_dir[d]
        print(f"  {d}: {c}件 / {_mb(s)}")
    print(f"  合計: {len(old)}件 / {_mb(total)}")

    if not args.apply:
        print("  （dry-run: 何も移動していない。本番は --apply）")
        return 0

    moved = 0
    for f, _ in old:
        try:
            move_to_trash(f, trash)
            moved += 1
        except OSError:
            print(f"  skip(移動失敗): {os.path.basename(f)}")
    print(f"  移動完了: {moved}/{len(old)}件 / {_mb(total)} 相当")
    return 0


if __name__ == "__main__":
    sys.exit(main())
