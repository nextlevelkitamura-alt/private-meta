分類: loop ／ 種別: 統合整理 ／ 規模: フル

# 実行loop一覧の一元化と表示改善

## 目的

Mac上で動く自作の定期loopを、`loops-registry/` 直下の1つのMarkdownで管理し、
同名HTMLを開けば「何が・いつ・どう動き・失敗後どうなるか・記録がどこに残るか」を
内容別の白い表型レイアウトで把握できるようにする。

## 現状

- global loop 4本は `personal-os.md`、仕事の自動実行は `nextlevel-career.md` に分かれている。
- 人間向け `personal-os.html` は暗色カード型で、件数が増えた時の比較と一覧性が弱い。
- global loopの生ログはローカル `output/logs/`。仕事のワーカー監視はローカルログに加えて
  Googleスプレッドシートの実行ログにも記録するが、現在の一覧から判別しづらい。
- 2026-07-12 12:06 JSTの実機棚卸しで、自作の定期loopとしてglobal 4本、仕事3本の
  合計7 labelがloaded。Focusmap app serverとHermes gatewayは常駐serviceなので対象外。

## 人間決定

1. 主表示はMacローカルでよい。
2. `loops-registry/` 配下へ置く。
3. ローカルMarkdownを一覧の単一正本にする。
4. 今後の自作loopも同じ正本へ追記する。
5. 内容別に増やせる分類構造にする。
6. 人間向けHTMLは表型・白基調にする。

## 方針

1. 一覧正本を `実行loop一覧.md`、派生表示を同名HTMLにし、不要な `実行一覧/` フォルダは置かない。
2. global / repo-localを別ファイルに分けず、所有領域を「Personal OS」「仕事」の2つに固定する。
   各領域の中は「AI運用・セッション管理」「情報同期」「保守・整理」「仕事・求人運用」で内容分類する。
3. 各loopに、分類・scope・目的・実行方法・発火・発火設定・失敗時・記録・runner・label・
   正本・plist・意図状態・最終実機確認を持たせる。
4. HTMLは、健康状態のサマリー、2領域パネル、loop / 内容 / 実行間隔 / 次回 / 記録先の一覧、
   展開式の補足帯（実行方法 / 失敗時 / 記録 / 正本）で構成する。
5. 生ログを中央へコピーしない。一覧には保存先だけを書き、詳細は所有loop/repoを正本にする。
6. `verify.py` は、global loop棚との一致、全掲載loopのplist label・発火設定、必須項目、
   MD↔HTML hash、HTML掲載名を検査する。
7. launchdの登録・発火設定・実装本体は変更しない。

## 完了条件（レビュー項目）

- [x] `loops-registry/実行loop一覧.md` が一覧の唯一の本文正本で、現役7本を2領域・内容別に掲載している。
- [x] `実行loop一覧.html` が正本MDから生成され、白基調・2領域ダッシュボードとして横スクロールなしに読める。
- [x] 各行から、目的・実行方法・時間・失敗時・記録先・正本を確認できる。
- [x] global 4本と仕事3本のplist label・発火設定を `verify.py` が実ファイルと照合する。
- [x] 新しいloopは正本MDへ1項目追加し、HTML再生成とverifyを通す契約がAGENTSに明記されている。
- [x] 旧 `nextlevel-career.md` の内容が正本へ統合され、二重の一覧本文が残っていない。
- [x] `python3 verify.py --write-html`、`python3 verify.py`、`python3 verify.py --self-test` がPASSする。
- [x] 1440pxと900pxのChrome描画で、文字切れ・重なり・不自然な空白がない。
- [x] secret・token・credential・認証値がMD・HTML・差分に含まれない。
- [x] launchdの登録状態・plist・各loop実装に変更がない。

### 第2段階: 内部処理・launchd可視化

- [x] 全7loopで、起動後の内部処理を番号順に追える。
- [x] 全loopに `launchd構成` と `統合判断` があり、同周期loopを維持・統合する根拠を確認できる。
- [x] HTML生成時にlaunchctlからloaded・runs・last exitを取得し、意図状態と実機状態を混同しない。
- [x] `not running` を定期実行の正常な待機状態として扱う。
- [x] 1分周期はNextLevel dispatcher 1本へ6処理が統合済みと確認できる。
- [x] 同じ実装・4分周期の関東／全国worker-searchを統合候補として明示する。
- [x] 常時UIは閲覧中だけlocalhostからpollする方針とし、状態確認loopを追加しない。

## 結果

- 実装日: 2026-07-12 JST
- 一覧正本を `実行loop一覧.md`、派生表示を同名HTMLへ統一した。
- 現役7本を4分類で掲載し、global / repo-localのplistと発火設定を同じ検査で照合した。
- UI設計はimagegenの合意案を基に、白基調・上部サマリー・Personal OS / 仕事の2領域・展開式詳細へ更新した。
- `実行一覧/` フォルダをなくし、正本MD・派生HTML・検査スクリプトを `loops-registry/` 直下へ配置した。
- 機械検査と1440px / 900px描画はPASS。launchdと各実装本体は変更していない。
- 実装後評価は `評価96.md` に記録した。
- 第2段階で内部処理55ステップ、launchd実機スナップショット、統合判断、常時UIの推奨方式を追加した。
