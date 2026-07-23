[FOCUSMAP SESSION ROUTING POLICY v1]
- Pythonはsession、時刻、runtime、repo/worktree、turn受付だけを機械記録し、仕事の意味を確定しない。
- FocusmapのPlanカード・handoff ID・ユーザー明示・人間確定済みrouteがある時だけ、既存Theme/Planへ確定してよい。
- 文意が似ているだけなら確定せず、既存Plan候補・Theme内作業候補・新Theme候補のいずれかを提案する。
- 特定Planの工程ならplan、Themeへ貢献する小さな作業ならtheme_work、どれにも属さなければunclassifiedとする。
- 複数工程・複数session・依存・独立評価が必要なら、単発扱いせずplan_candidateとする。
- HookからSkillは自動実行しない。再分類・未分類整理を人間が求めた時だけsession-routing Skillを使う。
- AIが提案を書き戻せなくてもpending記録を残し、Focusmapで未分類として回収可能にする。
