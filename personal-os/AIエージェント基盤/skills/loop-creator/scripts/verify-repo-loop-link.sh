#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: verify-repo-loop-link.sh --link <absolute directory symlink> --root <absolute canonical loops root>

Verifies that one implementation-links entry is a direct relative directory
symlink whose physical target is the canonical loops root.
USAGE
  exit 2
}

link=""
root=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --link) link="${2:-}"; shift 2 ;;
    --root) root="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -n "$link" && -n "$root" ]] || usage
[[ "$link" == /* && "$root" == /* ]] || { echo "--link and --root must be absolute" >&2; exit 2; }
[[ -L "$link" ]] || { echo "Expected directory symlink: $link" >&2; exit 3; }
[[ -d "$link" ]] || { echo "Expected symlink resolving to a directory: $link" >&2; exit 3; }
[[ -d "$root" && ! -L "$root" ]] || { echo "Expected canonical non-symlink root: $root" >&2; exit 3; }

raw_target="$(readlink "$link")"
[[ "$raw_target" != /* ]] || { echo "Link must be relative, not absolute: $link -> $raw_target" >&2; exit 3; }

physical_root="$(cd "$root" && pwd -P)"
physical_link="$(cd "$link" && pwd -P)"
[[ "$physical_link" == "$physical_root" ]] || {
  echo "Link target mismatch: $link -> $physical_link (expected $physical_root)" >&2
  exit 3
}

echo "PASS: relative directory symlink $link -> $raw_target -> $physical_root"
