#!/usr/bin/env npx tsx
/**
 * アドインパネル内の Claude タイルの正確なセレクタを調査
 */
import { chromium } from 'playwright';
import * as path from 'node:path';
import * as os from 'node:os';
import * as fs from 'node:fs';

const USER_DATA_DIR = path.join(os.homedir(), '.playwright-auth-pptx');
const OUT_DIR = '/tmp/pptx-scout';
fs.mkdirSync(OUT_DIR, { recursive: true });

const PPTX_URL = 'https://powerpoint.cloud.microsoft/open/onedrive/?docId=116C03A6FE065E99%21s6751afcce24d4606beb5aceb84847813&driveId=116C03A6FE065E99';

async function waitForWacFrame(page: import('playwright').Page) {
  const deadline = Date.now() + 45000;
  while (Date.now() < deadline) {
    const f = page.frames().find(f => f.name() === 'WacFrame_PowerPoint_0' && f.url().includes('officeapps'));
    if (f) return f;
    await page.waitForTimeout(500);
  }
  throw new Error('WacFrame not found');
}

async function main() {
  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    headless: false, channel: 'chrome', locale: 'ja-JP',
    viewport: { width: 1440, height: 900 },
    args: ['--window-position=50,50', '--window-size=1400,900'],
  });
  const page = context.pages()[0] || await context.newPage();

  await page.goto(PPTX_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  const wac = await waitForWacFrame(page);
  await wac.waitForSelector('[role="tab"]', { timeout: 30000 });
  await page.waitForTimeout(1000);

  // ホームのアドインボタンをクリック
  const homeAddinBtn = wac.locator('[aria-label="アドイン"]:not(#InsertAddInFlyout)').first();
  await homeAddinBtn.click();
  await page.waitForTimeout(2000);

  // パネル内の HTML を全ダンプ
  console.log('\n=== パネル内 HTML（ClaudeタイルのDOM構造）===');
  const panelHtml = await wac.evaluate(() => {
    // ダイアログ・フライアウト・ポップアップを探す
    const candidates = [
      document.querySelector('[role="dialog"]'),
      document.querySelector('[class*="Flyout"]'),
      document.querySelector('[class*="Panel"]'),
      document.querySelector('[class*="addin"]'),
      document.querySelector('[class*="AddIn"]'),
    ].filter(Boolean);

    if (candidates[0]) return candidates[0]!.innerHTML.slice(0, 5000);

    // 見つからなければ body 全体から Claude を含む要素を探す
    const allEls = document.querySelectorAll('*');
    for (const el of allEls) {
      if (el.textContent?.includes('Claude by Ant') && el.children.length > 0) {
        return el.outerHTML.slice(0, 3000);
      }
    }
    return 'not found';
  });
  console.log(panelHtml);

  // Claude を含む全インタラクティブ要素
  console.log('\n=== Claude 関連インタラクティブ要素 ===');
  const claudeEls = await wac.evaluate(() => {
    const result: string[] = [];
    const allEls = document.querySelectorAll('button, a, [role="button"], [onclick], [tabindex]');
    for (const el of allEls) {
      if (el.textContent?.trim().toLowerCase().includes('claude') ||
          el.getAttribute('aria-label')?.toLowerCase().includes('claude') ||
          el.getAttribute('title')?.toLowerCase().includes('claude')) {
        result.push(`tag=${el.tagName} class="${el.className.slice(0,80)}" aria="${el.getAttribute('aria-label')}" text="${el.textContent?.trim().slice(0,50)}" id="${el.id}"`);
      }
    }
    return result;
  });
  claudeEls.forEach(e => console.log(' ', e));

  // スクリーンショット
  await page.screenshot({ path: path.join(OUT_DIR, 'panel-open.png') });
  console.log(`\n📸 ${OUT_DIR}/panel-open.png`);

  // 全フレーム（パネル開いた後）
  console.log('\n=== 全フレーム（パネル開いた後） ===');
  for (const f of page.frames()) {
    console.log(`  name="${f.name()}" url="${f.url().slice(0, 100)}"`);
  }

  console.log('\nブラウザを閉じると終了');
  await context.waitForEvent('close', { timeout: 120000 }).catch(() => {});
  await context.close().catch(() => {});
}

main().catch(e => { console.error(e); process.exit(1); });
