今日のデイリースタート儀式を無人モードで実行してください。

1. `daily-start` スキル（正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/daily-start/SKILL.md`）を読み、その **無人モード（--auto）** の手順に従って実行する。
2. 手順の概略（詳細はスキル本文が正本・食い違ったらスキル本文を優先）:
   - 冪等ガード: `loops-registry/loops/daily-start/state/done-<今日のYYYY-MM-DD(JST)>` が既にあれば、起票せず即終了する。
   - 当月の月間計画・前日デイリーの「明日へ」節・繰越し候補（inbox todos）・前日 session_logs を読む。
   - 今日の大課題（themes 2〜3個）を確定し、不足分だけ `board.py theme-add` する（重複作成しない）。
   - 今日やること（todos）を `board.py todo-add` で確定起票する（テーマ紐付け・assignee/route を自己判定。**route='routine' の自称起票は禁止**＝宣言照合を経たものだけ）。繰越しは新todo起票＋`--carried-from <昨日>` で引き寄せる。
   - 気になった点（過多・不明玉・衝突）だけ `board.py ask` で question を発行する。
   - 実行ログ `state/done-<今日のYYYY-MM-DD(JST)>` を書き、`board.py log` で成果を1行記録して finish する。
3. デイリーmd本文の8節構成は編集しない（別担当の領分・壊さない）。
4. 人間の承認バーは置かない（確定起票してよい）。判断に迷う点は question にして人間へ回す。

このプロンプトは daily-start loop（launchd `com.kitamura.daily-start`・10:03 JST）から自動起動されている。
