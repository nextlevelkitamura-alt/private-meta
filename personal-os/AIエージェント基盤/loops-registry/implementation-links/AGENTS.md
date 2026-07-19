# implementation-links — repo-local loopへの入口

ここはrepo-local loopの**実装を置く場所ではない**。所有repoがAGENTS.mdで宣言する物理loop rootへ辿るための
directory symlinkだけを置く。正本・launchdの実行経路・状態一覧にはならない。

## 構成

```text
implementation-links/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  <repo-id> -> ../../../../projects/active/<repo>/<宣言済みの物理loop-root>/
```

- 1 repoにつき1本だけ、`<repo-id>` からそのrepoがAGENTS.mdで宣言する物理loop root全体へ相対symlinkを置く。rootの `loops/` が互換symlinkであっても、この入口は実体へ直接向ける。
- 個別loopへのsymlinkは作らない。repo内へ新しいloopを作れば、この入口から自動的に辿れる。
- リンク先の実装・ルールは必ず所有repoの `AGENTS.md` と、宣言済み物理rootの `AGENTS.md` を正とする。

## 安全規則

- plistの `ProgramArguments` と `WorkingDirectory` はcanonicalな実体pathを使う。このリンクを実行経路にしない。
- リンク削除前は `readlink` と `realpath` で対象を確認する。リンク経由で実体を削除せず、`rm -rf` を使わない。
- `loop-creator` が作成・更新時に、repo-registryのrepo id、リンク先root、registryのcanonical source pathを照合する。
- state、log、secret、実行履歴をここへ複製しない。全体の状態は移行期間中は `実行loop一覧.md`、切替後はTurso / Focusmapを正とする。
