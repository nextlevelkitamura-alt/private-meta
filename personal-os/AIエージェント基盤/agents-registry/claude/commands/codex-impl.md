---
description: Codexに実装を委任する（共通delegate経由・計画→実装→評価→修正のMD駆動ループ）
---

`/codex-impl <依頼>` は従来どおり Codex 実装委任の入口である。実行本体は `agents-registry/harness/delegate.py` に一本化し、このコマンドは直接 `codex exec` を組み立てない。

## 使い方

ライト以上では、依頼に対象計画の絶対pathを含める。Task Packetの生成時に runtime、role、base SHA、result packet出力先を決める。サクッとは既存の規模判定どおり計画なしで終了してよいが、delegateへ渡す実装は必ず計画を持つ。

## 手順

1. 規模を判定する。構造3条件（変更1〜2ファイル／容易に戻せる／人間ゲートなし）が全YESなら、通常の直接実装・diff確認・報告で終える。1つでもNOなら対象計画の「完了条件」を読む。
2. `PLAN_PATH` を対象計画の絶対path、`REPO_ROOT` を対象repoの絶対path、`BASE_SHA` を明示した基準commitとして確定する。さらに task ID と、少なくとも1つの変更可能pathを決める。write taskはこれらなしで起動しない。Task Packetとrun manifestのworktree方針に従い、worker自身に作業場所・branchを選ばせない。
3. 共通delegateを次の契約で起動する。`delegate.py` のCLI定義が正本であり、runtime、role、plan path、write taskのbase SHAを省略しない。

   ```bash
   python3 personal-os/AIエージェント基盤/agents-registry/harness/delegate.py \
     --runtime codex \
     --role implementer \
     --plan "$PLAN_PATH" \
     --repo-root "$REPO_ROOT" \
     --task-id "$TASK_ID" \
     --base-commit "$BASE_SHA" \
     --allowed-path "path/to/change"
   ```

4. result packetをschema検証し、result commitとchanged pathsを実物で確認する。禁止範囲違反、base不一致、blockedはその場で停止する。
5. ライト以上は `impl-evaluator` を起動し、計画・diff範囲・規模を渡す。評価本文は計画と同じ場所の `評価NN.md` とし、PASS/FAIL/対象外を完了条件と同順で照合する。
6. FAILは `修正NN.md` を作成し、同じdelegateの実装threadへresumeする。上限はライト=1回、フル=2回。全PASSだけ `planctl apply-evaluation` と `planctl sync-check` へ進む。

## サブ可視化の呼び出し規律（子03・board記録）

Codex への委任（delegate 経由でも直接 `codex exec` でも）は、Claude の `Agent`/`Task` ツールを通らないため
`SubagentStart/Stop` hook に乗らない＝ボードの「サブN体」に自動で現れない。指揮官が委任の前後で明示記録する。

- 委任直後: `python3 personal-os/AIエージェント基盤/hooks-registry/shared/session-board/board.py sub-start --key <s:自分のキー> --runtime codex --model <opus|sonnet|…> --via exec --prompt "<渡した依頼>"`
- 完了時: 同 `board.py sub-end --key <s:自分のキー>`（最古の running 1本を close）

`--prompt` は保存直前に board.py 側で簡易マスキングされる。詳細5列（runtime/model/agent_type/launch_via/prompt）は
board DB `session_subagents` に載り、ボードで個体展開に使う。migration 未適用時は best-effort 送信がドロップするだけで体数±1の挙動は不変。

## 維持する制約

- Task Packet、run manifest、result packetを正本とし、親会話の要約で置き換えない。
- push、mainへのmerge、deploy、worktree削除、runtime設定・symlink変更は行わない。
- `impl-evaluator` の入力（計画path／diff範囲／規模）とread-only評価を維持する。
- delegateの実行時引数・adapter wire formatはこのラッパーに複製しない。変更はharnessの契約として行う。

タスク: $ARGUMENTS
