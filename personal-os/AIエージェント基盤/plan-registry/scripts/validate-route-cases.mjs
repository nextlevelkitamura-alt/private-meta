#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = resolve(here, "fixtures/route-cases.json");
const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));

const expectedIds = [
  "private-existing-plan-ambiguous",
  "private-plan-box-ambiguous",
  "private-plan-box-missing",
  "private-work-area-new",
  "repo-focusmap-declared-box",
  "repo-work-cross-domain-root",
  "repo-work-existing-plan"
];
const allowedActions = new Set(["no_plan", "join_existing", "create_new", "stop"]);
const allowedClasses = new Set(["area-local", "repo-root", "repo-declared", "global-area", "none"]);
const requiredExpected = [
  "exit_code", "action", "canonical_repo", "registry_reads",
  "canonical_plan_path", "plan_class", "execution_cwd",
  "handoff_required", "stop_reason", "findings", "secret_values_emitted"
];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const handoffFields = [
  "canonical_repo_path", "plan_ref", "worktree_cwd",
  "allowed_paths", "forbidden_actions", "start_git_snapshot"
];

function validHandoff(handoff, verification) {
  if (!handoff || typeof handoff !== "object") return false;
  const fieldsValid = handoffFields.every((key) => {
    if (!Object.hasOwn(handoff, key)) return false;
    const value = handoff[key];
    return Array.isArray(value) ? value.length > 0 : typeof value === "string" && value.length > 0;
  });
  return fieldsValid
    && verification.canonicalCommonDir === verification.worktreeCommonDir
    && handoff.start_git_snapshot === verification.observedSnapshot;
}

assert(fixture.schema_version === "plan-triage.route-fixtures/v1", "schema_version mismatch");
assert(Array.isArray(fixture.cases), "cases must be an array");

const ids = fixture.cases.map((item) => item.id).sort();
assert(JSON.stringify(ids) === JSON.stringify(expectedIds), "fixture IDs mismatch or duplicate");

for (const item of fixture.cases) {
  assert(item.input && item.expected, `${item.id}: input/expected required`);
  for (const key of requiredExpected) {
    assert(Object.hasOwn(item.expected, key), `${item.id}: missing expected.${key}`);
  }
  const out = item.expected;
  assert(allowedActions.has(out.action), `${item.id}: invalid action`);
  assert(allowedClasses.has(out.plan_class), `${item.id}: invalid plan_class`);
  assert(out.secret_values_emitted === 0, `${item.id}: secret value emission forbidden`);
  assert(JSON.stringify(out.findings) === JSON.stringify([...out.findings].sort()), `${item.id}: findings must be sorted`);
  if (item.input.origin === "repo") assert(out.registry_reads === 0, `${item.id}: repo origin must skip registry`);
  if (out.action === "stop") {
    assert(out.exit_code === 3, `${item.id}: stop must exit 3`);
    assert(out.canonical_plan_path === null, `${item.id}: stop path must be null`);
    assert(out.handoff_required === false, `${item.id}: stop cannot hand off`);
    assert(out.findings.includes(out.stop_reason), `${item.id}: stop_reason must be a finding`);
  } else {
    assert(out.exit_code === 0, `${item.id}: success must exit 0`);
    assert(out.canonical_plan_path !== null, `${item.id}: success path required`);
    assert(out.stop_reason === null, `${item.id}: success stop_reason must be null`);
  }
}

const validSyntheticHandoff = {
  canonical_repo_path: "$REPO/work",
  plan_ref: "$REPO/work/領域/整備/AI運用/計画/plan.md",
  worktree_cwd: "$WORKTREE/work",
  allowed_paths: ["$REPO/work/領域/整備/AI運用"],
  forbidden_actions: ["push", "secret-output"],
  start_git_snapshot: "synthetic-snapshot"
};
const validVerification = {
  canonicalCommonDir: "$REPO/work/.git",
  worktreeCommonDir: "$REPO/work/.git",
  observedSnapshot: "synthetic-snapshot"
};
assert(validHandoff(validSyntheticHandoff, validVerification), "valid synthetic handoff rejected");
for (const field of handoffFields) {
  const invalid = structuredClone(validSyntheticHandoff);
  delete invalid[field];
  assert(!validHandoff(invalid, validVerification), `handoff missing ${field} must be rejected`);
}
assert(!validHandoff(validSyntheticHandoff, {...validVerification, worktreeCommonDir: "$OTHER/.git"}), "different Git common-dir must be rejected");
assert(!validHandoff(validSyntheticHandoff, {...validVerification, observedSnapshot: "changed-snapshot"}), "snapshot mismatch must be rejected");

const summary = {
  schema_version: fixture.schema_version,
  case_count: fixture.cases.length,
  case_ids: ids,
  exit_codes: [...new Set(fixture.cases.map((item) => item.expected.exit_code))].sort((a, b) => a - b),
  handoff_negative_variants: handoffFields.length + 2,
  secret_values_emitted: 0
};
process.stdout.write(`${JSON.stringify(summary)}\n`);
