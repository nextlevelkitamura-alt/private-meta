# 計画システム再設計 Theme

このThemeは、Focusmapの計画運用に関する構想をローカル/Gitで育て、実行を決めた計画を同じTheme内で管理する場所である。実装コード、DB migration、Turso schema、R2設定は置かない。

## 固定構造と正本

```text
goal.md
concepts/
  topics/            # 個別の構想・設計本文
  research/          # 調査・比較・根拠
  discussion-logs/   # 壁打ち・検討から残す記録
plans/
  planning/
  active/
  done/
  archive/
```

- `goal.md` はThemeの入口と現在の決定を持つ。`concepts/` のMarkdown本文はローカル/Gitが正本である。
- Theme固有の実行計画は、上記 `plans/<bucket>/<計画名>/plan-0.md` にだけ置く。AI運用直下の計画箱は廃止し、別Themeやrepoの計画をここへ複製しない。
- `concepts/research/` はTheme全体の調査・比較・根拠を置く。具体的な計画だけに必要な補助資料はその計画フォルダに置けるが、`references/` を既定フォルダとして作らない。
- 将来はTopic、調査の要約、discussion logの短い状態・活動履歴をTursoへ段階的に移す候補がある。ただし今回の正本はローカル/Gitのままとし、Markdown本文の同期や二重保存はしない。

## 作業ルール

1. Theme固有の計画を探す時は、この `plans/` だけを検索する。Themeに属さない実装計画は対象repoの最寄り `AGENTS.md` を正とする。
2. 計画の規模、評価、状態遷移は `../../AGENTS.md`、`../../../AGENTS.md`、`../../../../AIエージェント基盤/plan-registry/AGENTS.md` を正とする。
3. secret、token、credential、署名URLをここへ記録しない。
