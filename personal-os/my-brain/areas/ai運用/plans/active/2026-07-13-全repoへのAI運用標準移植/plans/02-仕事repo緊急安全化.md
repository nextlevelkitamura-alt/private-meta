親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル
並列: 可 ／ レビュー: 都度

# 仕事repo緊急安全化

## 目的

credential漏えいと有効な危険hookを先に封じ、既存未コミット変更を巻き込まずに仕事repoの移行作業を開始できる安全基線を作る。

## 現状

1. trackedのCodex設定に平文credentialがあり、Git履歴にも残る。値は出力・計画・HTML・commit messageへ載せない。
2. trust登録済みの仕事repo固有Stop hookが、AI応答の終了時に `git add -A` と自動commitを実行する。これはGlobalのsession-board hookとは別であり、「自動commit一般」ではなく「全差分を無条件stage・commitする経路」が危険である。
3. root移動後に存在しない旧絶対pathを参照するhook・Skill・scriptが複数ある。
4. 調査開始時の未コミット変更が調査中に別セッションで変化したため、実装開始時のsnapshotと対象pathの分離が必要である。
5. 仕事repoのdispatcher等repo-local loopとGlobal loop一覧の接続は現時点で検証PASSのため、loop実装の移植は不要である。
6. 2026-07-13の安全化レビュー中、変更前から読み込まれていた旧Stop hookが2回発火し、未push commit `f4b78f49`・`fb6f5047` を作成した。安全化対象2ファイルに加えて、別sessionの新規plan作成・更新を `git add -A` で巻き込んだため、この2commitをそのまま移行成果と認めない。
7. session-board上では `circus応募自動入力を実装` の仕事sessionが稼働中である。設定ファイル上の危険hookは0件だが、変更前から開いているsessionが旧hookを保持する可能性があるため、回復操作より先に終了・再起動が必要である。

## 方針

1. 仕事repo内でAI実装を始める前に、現在のdirty path一覧を値なしで記録し、触るpathと重ならない専用worktree/branchを使う。
2. 人間ゲートで漏えいcredentialを失効・再発行し、Keychain・環境変数・非追跡設定などrepo外保管へ切り替える。
3. trackedファイルと現HEADをsecret scanし、値を標準出力へ出さず件数・path・判定だけを残す。
4. 履歴rewriteは全cloneへ影響する破壊操作として別の人間判断にする。credential失効を先に行い、履歴を残す/書き換える判断と理由を記録する。
5. まず仕事repo固有Stop hookの `git add -A` とcommit経路だけを停止し、他の業務hookは個別監査まで維持する。Stop時はread-onlyの `git status`、完了シグナル、session-board記録だけを許可する。
6. 禁止対象はStop hookによる無条件stage/commitとする。checkpoint commitが必要な場合は、節目の人間確認後にdiffを確認し、検証済みの `git add -- <明示path>` だけを使う。commit自体を一律禁止せず、対象path・検証結果・巻込みなしを人間ゲートにする。
7. local/global hookの発火回数と順序を実測し、Global session-board hookまで誤って停止しない。
8. 旧絶対pathは現役・履歴・生成物に分類し、現役hookから先に現在rootへ直す。launchd再登録が要る場合は別の人間ゲートにする。
9. 稼働中repo-local loopは、所有権とGlobal台帳参照が正しい限り変更しない。
10. 人間承認後に2件のauto-commitを未push baseまで戻し、worktreeの最新内容を保ったまま、安全化対象だけを明示pathで再commitする。別作業planは削除せず未commitへ戻し、その所有sessionが別commitとして扱う。branch/indexを書き換える正確な操作内容を事前提示する。

## 完了条件（レビュー項目）

- [ ] 漏えいcredentialが失効・再発行済みで、tracked設定にcredential実値が0件である。
- [ ] Git履歴対応について、保持またはrewriteの人間判断・影響範囲・次の一手が仕事repoの計画に記録されている。
- [ ] secret scanが値を出力せず、working treeと現HEADで0件PASSしている。
- [ ] trust登録済みrepo-local hookに `git add -A` と無条件自動commitが残っていない。
- [ ] Stop時はread-onlyの状態確認・完了シグナル・session-board記録だけで、無条件stage/commitを実行しない。
- [ ] commit時は対象diffの確認と `git add -- <明示path>` が必要で、別タスクの変更を巻き込まない。
- [ ] repo-local/global hookを各1回実測し、重複発火・無限loop・旧root参照エラーがない。
- [ ] 移行用worktreeに、開始時snapshot外の並行セッション変更が混入していない。
- [ ] dispatcher等の稼働中loopが変更前と同じ所有repo・実行状態である。
- [ ] commit、push、launchd再登録、履歴rewriteは、それぞれ必要な人間承認を得た操作だけである。
- [ ] 変更前から開いていた仕事sessionを終了・再起動し、旧hookを保持するsessionが残っていない。
- [ ] 旧hookが作成した `f4b78f49`・`fb6f5047` に別作業planが混在せず、安全化差分と別作業差分が明示的に分離されている。
