# guard-plan-bucket-move.py

stdin JSONの`tool_input.command`（camelCaseも許容）を読み、Bash内の生`mv` / `git mv`と
`plans/<bucket>`の組み合わせだけをdeny JSONで返す。`bucketctl`、通常Bash、内部例外はexit 0・stdoutなし。
runtime登録は未適用で、承認セットの登録差分を適用するまで実行されない。
