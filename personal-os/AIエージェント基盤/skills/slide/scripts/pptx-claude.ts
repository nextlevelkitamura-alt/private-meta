#!/usr/bin/env npx tsx
/**
 * PowerPoint Online × Claude アドイン 全自動スクリプト
 *
 * 使い方:
 *   npx tsx pptx-claude.ts --url "https://..." --prompt "スライドを作ってください"
 *
 * 前提: 事前に npx tsx pptx-auth.ts を実行して認証済みであること
 */

import { chromium, type Frame } from 'playwright';
import * as path from 'node:path';
import * as os from 'node:os';

const USER_DATA_DIR = path.join(os.homedir(), '.playwright-auth-pptx');

const argv = process.argv.slice(2);
const getArg = (flag: string) => { const i = argv.indexOf(flag); return i >= 0 ? argv[i + 1] : undefined; };
const hasFlag = (flag: string) => argv.includes(flag);

const PPTX_URL = getArg('--url');
const PROMPT = getArg('--prompt');
const SHOW = hasFlag('--show-browser');

if (!PPTX_URL) { console.error('❌ --url が必要です'); process.exit(1); }
if (!PROMPT) { console.error('❌ --prompt が必要です'); process.exit(1); }

async function waitForWacFrame(page: import('playwright').Page): Promise<Frame> {
  const deadline = Date.now() + 45000;
  while (Date.now() < deadline) {
    const f = page.frames().find(f => f.name() === 'WacFrame_PowerPoint_0' && f.url().includes('officeapps'));
    if (f) return f;
    await page.waitForTimeout(500);
  }
  throw new Error('WacFrame が見つかりません');
}

async function waitForNewFrame(page: import('playwright').Page, knownUrls: Set<string>, timeout = 20000): Promise<Frame | null> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const f = page.frames().find(f => {
      const url = f.url();
      return url !== 'about:blank' && !knownUrls.has(url) && url.startsWith('http');
    });
    if (f) return f;
    await page.waitForTimeout(500);
  }
  return null;
}

async function main() {
  console.log('[pptx-claude] ブラウザ起動...');
  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    headless: !SHOW,
    channel: 'chrome',
    locale: 'ja-JP',
    viewport: { width: 1440, height: 900 },
    args: SHOW ? ['--window-position=50,50', '--window-size=1400,900'] : [],
  });

  const page = context.pages()[0] || await context.newPage();

  console.log('[pptx-claude] PowerPoint を開いています...');
  await page.goto(PPTX_URL!, { waitUntil: 'domcontentloaded', timeout: 60000 });

  console.log('[pptx-claude] エディタ読み込み待機...');
  const wac = await waitForWacFrame(page);
  await wac.waitForSelector('[role="tab"]', { timeout: 30000 });
  await page.waitForTimeout(2000);
  console.log('[pptx-claude] ✅ エディタ準備完了');

  const knownUrls = new Set(page.frames().map(f => f.url()));

  // Claude タスクペインが既に開いているか確認
  let claudeFrame = await waitForNewFrame(page, knownUrls, 2000);

  if (!claudeFrame) {
    // ホームタブ
    const homeTab = wac.locator('#Home');
    if (await homeTab.isVisible({ timeout: 3000 }).catch(() => false)) {
      await homeTab.click();
      await page.waitForTimeout(500);
    }

    // Claude リボンボタン or アドインパネル経由
    const claudeRibbonBtn = wac.locator('#AddinControl1');
    if (await claudeRibbonBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
      await claudeRibbonBtn.click();
    } else {
      console.log('[pptx-claude] アドインパネルから起動...');
      const addinBtn = wac.locator('[aria-label="アドイン"]:not(#InsertAddInFlyout)').first();
      await addinBtn.click({ force: true });
      await page.waitForTimeout(2500);

      const result = await wac.evaluate(() => {
        const btn = document.getElementById('AddinControl1') as HTMLElement | null;
        if (btn) { btn.click(); return 'ok'; }
        const all = Array.from(document.querySelectorAll('button, [role="button"]'));
        const cb = all.find(el => el.textContent?.includes('Claude')) as HTMLElement | null;
        if (cb) { cb.click(); return 'fallback'; }
        return null;
      });
      if (!result) throw new Error('Claude ボタンが見つかりません。pptx-auth.ts を実行してください。');
      console.log('[pptx-claude] ✅ Claude クリック');
    }

    claudeFrame = await waitForNewFrame(page, knownUrls, 20000);
  }

  if (!claudeFrame) throw new Error('Claude タスクペインが開きませんでした');

  await page.waitForTimeout(2000);
  await claudeFrame.waitForLoadState('domcontentloaded').catch(() => {});

  // 未認証チェック
  const isLoginPage =
    claudeFrame.url().includes('/auth/login') ||
    (await claudeFrame.locator('button:has-text("Log in")').isVisible({ timeout: 2000 }).catch(() => false));

  if (isLoginPage) {
    throw new Error('Claude に未ログインです。先に npx tsx pptx-auth.ts を実行してください。');
  }

  // プロンプト入力
  console.log('[pptx-claude] プロンプトを入力中...');
  const input = claudeFrame.locator('textarea, [contenteditable="true"], [role="textbox"]').last();
  await input.waitFor({ timeout: 10000 });
  await input.click();
  await input.fill(PROMPT!);
  console.log('[pptx-claude] ✅ 入力完了');

  // 送信
  const sendBtn = claudeFrame.locator(
    'button[aria-label*="送信"], button[aria-label*="Send"], button[type="submit"]'
  ).first();
  if (await sendBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
    await sendBtn.click();
    console.log('[pptx-claude] ✅ 送信完了');
  } else {
    await input.press('Enter');
    console.log('[pptx-claude] ✅ Enter で送信');
  }

  console.log('[pptx-claude] ✅ 完了！Claude がスライドを生成中...');

  if (SHOW) {
    console.log('[pptx-claude] ブラウザを閉じると終了します');
    await context.waitForEvent('close', { timeout: 600000 }).catch(() => {});
  }
  await context.close().catch(() => {});
}

main().catch(e => {
  console.error('[pptx-claude] ❌ エラー:', e.message);
  process.exit(1);
});
