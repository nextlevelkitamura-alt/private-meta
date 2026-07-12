#!/usr/bin/env npx tsx
/**
 * PowerPoint Online × Claude アドイン — DOM探索スクリプト
 * WacFrame_PowerPoint_0 (officeapps.live.com) 内のリボン・アドインセレクタを調査
 */

import { chromium, type Frame } from 'playwright';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';

const USER_DATA_DIR = path.join(os.homedir(), '.playwright-auth-pptx');
const OUT_DIR = '/tmp/pptx-scout';
fs.mkdirSync(OUT_DIR, { recursive: true });

// 前回作成した空白プレゼンを直接開く
const PPTX_URL = 'https://powerpoint.officeapps.live.com/pods/ppt.aspx?ui=ja-JP&rs=ja-JP&wdenableroaming=1&mscc=1&wdod';
const args = process.argv.slice(2);
const urlArg = args[args.indexOf('--url') + 1] ?? null;

async function shot(page: import('playwright').Page, name: string) {
  const file = path.join(OUT_DIR, `${name}.png`);
  await page.screenshot({ path: file });
  console.log(`[scout] 📸 ${file}`);
}

async function waitForWacFrame(page: import('playwright').Page, timeout = 30000): Promise<Frame | null> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const f = page.frames().find(f => f.name() === 'WacFrame_PowerPoint_0');
    if (f && f.url().includes('officeapps')) return f;
    await page.waitForTimeout(500);
  }
  return null;
}

async function dumpFrame(frame: Frame, label: string, selector: string, limit = 20) {
  const els = await frame.locator(selector).all().catch(() => [] as import('playwright').Locator[]);
  if (els.length === 0) return;
  console.log(`[scout] ${label}: ${els.length}件`);
  for (const el of els.slice(0, limit)) {
    const txt = (await el.innerText().catch(() => '')).trim().slice(0, 50);
    const aria = await el.getAttribute('aria-label').catch(() => '') ?? '';
    const id = await el.getAttribute('id').catch(() => '') ?? '';
    const dtid = await el.getAttribute('data-testid').catch(() => '') ?? '';
    if (txt || aria || id) console.log(`  text="${txt}" aria="${aria}" id="${id}" data-testid="${dtid}"`);
  }
}

async function main() {
  const targetUrl = urlArg ?? 'https://powerpoint.cloud.microsoft/open/onedrive/?docId=116C03A6FE065E99%21s6751afcce24d4606beb5aceb84847813&driveId=116C03A6FE065E99';

  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    headless: false,
    channel: 'chrome',
    locale: 'ja-JP',
    viewport: { width: 1440, height: 900 },
    args: ['--window-position=50,50', '--window-size=1400,900'],
  });

  const page = context.pages()[0] || await context.newPage();
  console.log(`[scout] 開く: ${targetUrl}`);
  await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });

  // ① WacFrame が officeapps.live.com に向くまで待機
  console.log('[scout] WacFrame (officeapps) 待機中...');
  const wac = await waitForWacFrame(page, 45000);
  if (!wac) {
    console.error('[scout] ❌ WacFrame が見つからない');
    // フレーム一覧だけ出して終了
    for (const f of page.frames()) console.log(`  frame: name="${f.name()}" url="${f.url().slice(0, 100)}"`);
    await context.close();
    return;
  }
  console.log(`[scout] ✅ WacFrame: ${wac.url().slice(0, 80)}`);

  // ② エディタリボンが出るまで待機
  console.log('[scout] リボン待機中...');
  await wac.waitForSelector(
    '[id*="Ribbon"], [class*="ribbon"], [role="menubar"], [aria-label*="ホーム"], [aria-label*="Home"]',
    { timeout: 30000 }
  ).catch(() => console.log('[scout] リボン待機タイムアウト'));
  await page.waitForTimeout(2000);
  await shot(page, '01-editor');

  // ③ WacFrame 内のフレーム一覧
  const innerFrames = wac.childFrames();
  console.log(`\n[scout] WacFrame 内フレーム数: ${innerFrames.length}`);
  for (const f of innerFrames) console.log(`  name="${f.name()}" url="${f.url().slice(0, 100)}"`);

  // ④ リボンタブ
  console.log('\n[scout] === リボンタブ ===');
  await dumpFrame(wac, 'role=tab', '[role="tab"]');

  // ⑤ アドイン関連セレクタ候補
  console.log('\n[scout] === アドイン関連 ===');
  const addinSelectors = [
    '[aria-label*="アドイン"]', '[aria-label*="Add-ins"]', '[aria-label*="add-in"]',
    '[title*="アドイン"]', '[id*="AddIn"]', '[id*="addin"]',
    '[data-unique-id*="AddIn"]', 'button[data-id*="addin"]',
  ];
  for (const sel of addinSelectors) {
    const els = await wac.locator(sel).all().catch(() => []);
    if (els.length > 0) {
      console.log(`  ✅ HIT: ${sel} → ${els.length}件`);
      for (const el of els.slice(0, 3)) {
        const txt = (await el.innerText().catch(() => '')).trim();
        const aria = await el.getAttribute('aria-label').catch(() => '');
        const id = await el.getAttribute('id').catch(() => '');
        console.log(`     text="${txt}" aria="${aria}" id="${id}"`);
      }
    }
  }

  // ⑥ 挿入タブをクリック → アドインボタン探索
  console.log('\n[scout] === 挿入タブをクリック ===');
  const insertTab = wac.locator('[role="tab"]').filter({ hasText: /挿入|Insert/i }).first();
  if (await insertTab.isVisible({ timeout: 3000 }).catch(() => false)) {
    await insertTab.click();
    await page.waitForTimeout(2000);
    await shot(page, '02-insert-tab');
    console.log('[scout] 挿入タブ内ボタン:');
    await dumpFrame(wac, '全ボタン', 'button', 100);
  } else {
    console.log('[scout] 挿入タブが見つからない');
    // 全タブテキストをダンプ
    const tabs = await wac.locator('[role="tab"]').all().catch(() => []);
    for (const t of tabs) {
      const txt = (await t.innerText().catch(() => '')).trim();
      console.log(`  tab: "${txt}"`);
    }
  }

  // ⑦ 全iframe（タスクペイン）
  console.log('\n[scout] === 全iframe ===');
  const allFrames = page.frames();
  for (const f of allFrames) {
    console.log(`  name="${f.name()}" url="${f.url().slice(0, 100)}"`);
  }

  await shot(page, '03-final');
  console.log(`\n[scout] 完了: ${OUT_DIR}`);
  console.log('[scout] ブラウザを閉じると終了します...');
  await context.waitForEvent('close', { timeout: 300000 }).catch(() => {});
  await context.close().catch(() => {});
}

main().catch(e => { console.error(e); process.exit(1); });
