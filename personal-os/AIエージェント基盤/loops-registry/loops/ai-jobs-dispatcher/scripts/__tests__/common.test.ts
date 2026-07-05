import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import test from 'node:test';
import {
  buildWorkerCommand,
  countActiveLocks,
  isCardLockActive,
  lockPath,
  parseAssignee,
  shellQuote,
} from '../common.js';

test('parseAssignee: 半角コロン', () => {
  assert.equal(parseAssignee('担当: claude\n出所: /foo'), 'claude');
});

test('parseAssignee: 全角コロン・空白なし', () => {
  assert.equal(parseAssignee('担当：codex\n'), 'codex');
});

test('parseAssignee: フィールドが無い', () => {
  assert.equal(parseAssignee('出所: /foo\n依頼: bar'), null);
});

test('parseAssignee: 2行目以降にあってもmで拾う', () => {
  assert.equal(parseAssignee('見出し\n担当: orca\n'), 'orca');
});

test('shellQuote: シングルクオートを含む文字列を安全にエスケープする', () => {
  const quoted = shellQuote(`it's a test`);
  assert.equal(quoted, `'it'\\''s a test'`);
});

test('shellQuote: 改行を含む文字列もそのまま1トークンにする', () => {
  const quoted = shellQuote('line1\nline2');
  assert.equal(quoted, "'line1\nline2'");
});

test('buildWorkerCommand: claude はheadless print modeで起動', () => {
  const cmd = buildWorkerCommand('claude', 'hello');
  assert.ok(cmd);
  assert.match(cmd, /^claude -p 'hello' --dangerously-skip-permissions/);
});

test('buildWorkerCommand: codex はexec + workspace-write sandboxで起動', () => {
  const cmd = buildWorkerCommand('codex', 'hello');
  assert.ok(cmd);
  assert.match(cmd, /^codex exec 'hello' --sandbox workspace-write/);
});

test('buildWorkerCommand: 未対応engine（orca等）はnullを返す', () => {
  assert.equal(buildWorkerCommand('orca', 'hello'), null);
  assert.equal(buildWorkerCommand(null, 'hello'), null);
  assert.equal(buildWorkerCommand('unknown-engine', 'hello'), null);
});

test('lock: isCardLockActive/countActiveLocks は生存中PIDのlockを数え、死亡lockは掃除する', () => {
  const card = `test-card-${process.pid}-alive.md`;
  const deadCard = `test-card-${process.pid}-dead.md`;
  const lp = lockPath(card);
  const deadLp = lockPath(deadCard);
  try {
    // 自分自身のPID＝確実に生きている
    fs.writeFileSync(lp, `${process.pid} ${Date.now()}`, 'utf-8');
    // 存在しないであろう大きなPID＋古い時刻＝死亡かつstale
    fs.writeFileSync(deadLp, `999999 1`, 'utf-8');

    const now = Date.now();
    assert.equal(isCardLockActive(card, now, 1000), true);
    assert.equal(isCardLockActive(deadCard, now, 1000), false);
    assert.equal(fs.existsSync(deadLp), false, 'stale/死亡lockは削除される');

    const active = countActiveLocks(now, 1000);
    assert.ok(active >= 1, 'countActiveLocksは生存中のlockを数える');
  } finally {
    for (const p of [lp, deadLp]) {
      try {
        fs.unlinkSync(p);
      } catch {
        /* noop */
      }
    }
  }
});

test('lock: staleMsを超えた古いlockはPIDが生きていてもcountに含めない挙動にはしない（PID生存を優先）', () => {
  // 仕様: PIDが生きていればstaleMsに関わらずactiveとみなす（実行が長引いても誤って二重起動しない）
  const card = `test-card-${process.pid}-longrun.md`;
  const lp = lockPath(card);
  try {
    fs.writeFileSync(lp, `${process.pid} 1`, 'utf-8'); // startedMs=1（大昔）だがPIDは自分自身
    assert.equal(isCardLockActive(card, Date.now(), 1000), true);
  } finally {
    try {
      fs.unlinkSync(lp);
    } catch {
      /* noop */
    }
  }
});
