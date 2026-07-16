親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 可（repo単位・人間承認後） ／ レビュー: Review 2

# 全repo監査と段階展開

## 目的

仕事とfocusmapの2カナリアで確定した制御面を使い、実体が確認できるrepoだけを監査し、導入済み・保留・対象外・未mountを混同せず段階展開する。

## 現状

1. active実repoは仕事とfocusmapの2件で、`focusmap-worktrees` はrepoではなくcontainerである。
2. paused/archiveはローカル実体がなく、外部SSD未mountの対象をsecret/hook 0件と検証できない。
3. registryは担当repoの入口索引であり、rolloutの現在状態やplan本文を持たせると二重正本になる。

## 実行パッケージ

1. **R01 active audit-all**: canonical repo identityでactive実repoだけを列挙し、worktree/container重複を除外する。
2. **R02 deferred fleet**: paused/archive/未mountを理由・再開条件付きで分類し、mount後はrepoごとの人間承認と独立計画で進める。
3. **R03 Review 2**: security、route/index、runtime/hook、仕事E2E、focusmap E2E、rollbackの6レーンを、全実装/test-author/Integrationと別系統のreviewerが1回で採点する。人間はactive fleet完了と全履歴repo完了を別々に判断する。

## 正本と出力

- 横断順序・合否・参照commit・rollout matrixは本programが所有する。
- registryは担当repoの入口と履歴だけを持ち、領域表・計画本文・現在状態を複製しない。
- repo固有の追加修正は、そのrepoのAGENTSが宣言する計画箱へ独立planを置く。

## テスト・rollback・人間ゲート

1. `audit-all` はread-only既定、secret値非表示、worktree container除外、未mountをPASS扱いしない。
2. repo単位のwriterは別worktree・別allowed paths・別commitとし、1repoのFAILで他repoをrollbackしない。
3. push、main反映、symlink/launchd変更、未mount repoへの書込みは個別の人間ゲートにする。

## 完了条件（レビュー項目）

- [ ] active実repoが重複なく列挙され、仕事・focusmapのカナリア証拠と参照commitを持つ。
- [ ] paused/archive/未mountが理由・再開条件付きで分類され、未検証を導入済みと表示しない。
- [ ] Global本文コピー、cross-repo symlink、tracked secret、危険自動commit hookが、検証可能な実repoで0件である。
- [ ] Review 1とReview 2の規約名評価mdが全PASSし、active fleetと全履歴repoの完了判定が分離されている。
- [ ] local commit、origin push、本番反映が別々に表示され、未承認pushがない。
