#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const skillDir = resolve(here, "../../inbox-triage");
const skill = readFileSync(resolve(skillDir, "SKILL.md"), "utf8");
const html = readFileSync(resolve(skillDir, "SKILL.html"), "utf8");
const fixtures = JSON.parse(readFileSync(resolve(here, "fixtures/route-cases.json"), "utf8"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const requiredSkillSignals = [
  "plan-triage.route/v1", "action分岐", "`stop`", "`no_plan`",
  "`join_existing`", "`create_new`", "handoff_required=true",
  "Private側はplanも成功マーカーも書かない"
];
const forbiddenSkillPatterns = [
  /plans\/planning/, /plans\/active/, /無ければ作る/,
  /ここで処理を止めない/, /最も具体的で実行主体が明確な置き場を選/
];
const requiredCases = [
  "repo-work-existing-plan", "private-work-area-new",
  "repo-work-cross-domain-root", "repo-focusmap-declared-box",
  "private-plan-box-missing", "private-plan-box-ambiguous",
  "private-existing-plan-ambiguous"
];

assert(skill.split("\n").length - 1 <= 70, "inbox-triage SKILL.md exceeds 70 lines");
for (const signal of requiredSkillSignals) assert(skill.includes(signal), `missing signal: ${signal}`);
for (const pattern of forbiddenSkillPatterns) assert(!pattern.test(skill), `forbidden duplicated route rule: ${pattern}`);
assert(html.includes("color-scheme:light"), "HTML must force light color scheme");
assert(!/color-scheme:dark|prefers-color-scheme/i.test(html), "HTML dark mode forbidden");
assert(/html,body\{background:#fff/.test(html), "HTML white canvas required");

const caseIds = fixtures.cases.map((item) => item.id).sort();
for (const id of requiredCases) assert(caseIds.includes(id), `missing route fixture: ${id}`);
for (const item of fixtures.cases.filter((item) => item.expected.action === "stop")) {
  assert(item.expected.exit_code === 3, `${item.id}: stop must exit 3`);
  assert(item.expected.canonical_plan_path === null, `${item.id}: stop path must be null`);
}

process.stdout.write(`${JSON.stringify({
  schema_version: "inbox-triage.contract-check/v1",
  skill_lines: skill.split("\n").length - 1,
  route_cases: requiredCases.length,
  duplicated_route_rules: 0,
  dark_mode_rules: 0,
  secret_values_emitted: 0
})}\n`);
