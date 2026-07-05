# job-link

- 日付時刻: 2026-06-29 12:44 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 削除Skill: `.agents/skills/job-link`
- 概要: 求人シートE列のHYPERLINK化・複製元ID確定を扱っていた短縮Skillを削除した。
- 削除理由: 求人作成フロー内の必須Stepとして扱うべき処理であり、独立Skillにすると呼び出し分岐が増えて精度が下がるため。
- 統合先: `.agents/skills/job-create-flow/求人作成.md` Step 5、`.agents/skills/job-create-flow/references/複製元リンクルール.md`
- 実装側対応: `scripts/job-create/src/commands/search-and-link.ts` をT列=複製元ID、U列=作成済み求人IDの運用へ更新。
- 引き継ぎ履歴: 統合元ログなし。
- 復旧方針: 復旧しない。リンク確定は `job-create-flow` の中で実行する。
