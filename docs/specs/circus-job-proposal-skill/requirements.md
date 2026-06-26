# circus-job-proposal Skill Requirements

## Scope

Create a reusable `仕事` Skill for candidate-specific circus-job.com job search and proposal portfolios.

## Acceptance Criteria

- The Skill asks for must-have candidate data before recommending jobs when the data is missing.
- The Skill starts with a brief search-direction proposal when the requested conditions are likely strict.
- The Skill separates strict recommendations from adjacent roles, condition-change candidates, and future qualification routes.
- The Skill requires page traversal evidence through `pageStats` or equivalent page-by-page logs.
- The Skill prohibits recommending jobs with unmet required licenses, required experience, gender mismatch, new-grad-only mismatch, or strong occupation mismatch.
- The `circus-job-search` output includes page-by-page collection stats.
- The `仕事` skill list, catalog, and work-skill guide route this task to the new Skill.
- The Skill includes occupation-family strategy for mapping candidate history to search vectors.
- The search script can save job-detail PDFs for proposed jobs and include the saved paths in JSON/Markdown output.

## Evidence

- `.claude/skills/circus-job-proposal/SKILL.md`
- `scripts/circus-job-search/src/search.ts`
- `scripts/circus-job-search/README.md`
- `npx tsc --noEmit` in `仕事/scripts/circus-job-search`
- `npm run search -- --pref 東京 --keyword 営業 --max 2 --pool 2 --json output/page-test.json --md output/page-test.md`
- `npm run search -- --pref 東京 --keyword SaaS --max 1 --pool 3 --include-disqualified --pdf --pdf-max 1 --json output/pdf-test.json --md output/pdf-test.md`
