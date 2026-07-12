#!/usr/bin/env npx tsx
/**
 * Claude for PowerPoint — 事前認証スクリプト（一度だけ実行）
 *
 * 使い方:
 *   npx tsx pptx-auth.ts
 *
 * やること:
 *   1. Microsoft アカウントでログイン (powerpoint.cloud.microsoft)
 *   2. Claude add-in を開いてログイン (pivot.claude.ai)
 *   3. セッションを ~/.playwright-auth-pptx/ に保存
 *
 * 次回以降は pptx-claude.ts が自動でそのセッションを使う
 */

import { chromium } from 'playwright';
import * as path from 'node:path';
import * as os from 'node:os';

const USER_DATA_DIR = path.join(os.homedir(), '.playwright-auth-pptx');
const PPTX_URL = 'https://powerpoint.cloud.microsoft/open/onedrive/?docId=116C03A6FE065E99%21s6751afcce24d4606beb5aceb84847813&driveId=116C03A6FE065E99';

async function waitForWacFrame(page: import('playwright').Page) {
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    const f = page.frames().find(f => f.name() === 'WacFrame_PowerPoint_0' && f.url().includes('officeapps'));
    if (f) return f;
    await page.waitForTimeout(500);
  }
  throw new Error('PowerPoint エディタが読み込まれませんでした');
}

async function main() {
  console.log('[pptx-auth] ブラウザを起動します...');
  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    headless: false,
    channel: 'chrome',
    locale: 'ja-JP',
    viewport: { width: 1440, height: 900 },
    args: ['--window-position=50,50', '--window-size=1400,900'],
  });

  const page = context.pages()[0] || await context.newPage();

  // PowerPoint を開く
  console.log('[pptx-auth] PowerPoint を開いています...');
  await page.goto(PPTX_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });

  // Microsoft ログイン確認
  const currentUrl = page.url();
  if (currentUrl.includes('login') || currentUrl.includes('microsoftonline')) {
    console.log('[pptx-auth] ⚠️ Microsoft にログインしてください（ブラウザ上）');
    await page.waitForURL('**/powerpoint.cloud.microsoft/**', { timeout: 300000 });
    console.log('[pptx-auth] ✅ Microsoft ログイン完了');
  }

  // WacFrame 待機
  console.log('[pptx-auth] エディタ読み込み待機...');
  const wac = await waitForWacFrame(page);
  await wac.waitForSelector('[role="tab"]', { timeout: 30000 });
  await page.waitForTimeout(2000);
  console.log('[pptx-auth] ✅ エディタ準備完了');

  // Claude add-in を開く
  console.log('[pptx-auth] Claude add-in を開いています...');
  const knownUrls = new Set(page.frames().map(f => f.url()));

  const homeTab = wac.locator('#Home');
  if (await homeTab.isVisible({ timeout: 3000 }).catch(() => false)) {
    await homeTab.click();
    await page.waitForTimeout(500);
  }

  const claudeRibbonBtn = wac.locator('#AddinControl1');
  if (await claudeRibbonBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
    await claudeRibbonBtn.click();
  } else {
    const addinBtn = wac.locator('[aria-label="アドイン"]:not(#InsertAddInFlyout)').first();
    await addinBtn.click({ force: true });
    await page.waitForTimeout(2500);
    await wac.evaluate(() => {
      const btn = document.getElementById('AddinControl1') as HTMLElement | null;
      if (btn) btn.click();
    });
  }

  // Claude フレーム待機
  const deadline = Date.now() + 20000;
  let claudeFrame: import('playwright').Frame | null = null;
  while (Date.now() < deadline) {
    claudeFrame = page.frames().find(f => {
      const url = f.url();
      return url !== 'about:blank' && !knownUrls.has(url) && url.startsWith('http');
    }) ?? null;
    if (claudeFrame) break;
    await page.waitForTimeout(500);
  }

  if (!claudeFrame) {
    console.error('[pptx-auth] ❌ Claude タスクペインが開きませんでした');
    await context.close();
    process.exit(1);
  }

  await page.waitForTimeout(2000);
  await claudeFrame.waitForLoadState('domcontentloaded').catch(() => {});

  // ログインチェック
  const isLoginPage =
    claudeFrame.url().includes('/auth/login') ||
    (await claudeFrame.locator('button:has-text("Log in")').isVisible({ timeout: 3000 }).catch(() => false));

  if (isLoginPage) {
    console.log('');
    console.log('[pptx-auth] ⚠️ Claude add-in にログインが必要です');
    console.log('[pptx-auth] ブラウザの Claude タスクペインで「Log in」をクリックしてログインしてください');
    console.log('[pptx-auth] ログイン完了後、自動で続行します...');
    console.log('');

    // チャット UI が出るまで待つ（10分）
    await claudeFrame.waitForFunction(
      () => document.querySelector('textarea, [contenteditable="true"], [role="textbox"]') !== null,
      undefined,
      { timeout: 600000 },
    );
    console.log('[pptx-auth] ✅ Claude ログイン完了！');
  } else {
    const hasChatUI = await claudeFrame.locator('textarea, [contenteditable="true"], [role="textbox"]')
      .first().isVisible({ timeout: 3000 }).catch(() => false);
    if (hasChatUI) {
      console.log('[pptx-auth] ✅ Claude 認証済み（ログイン不要）');
    }
  }

  console.log('[pptx-auth] ✅ 認証完了。セッションを保存しています...');
  await page.waitForTimeout(1000);
  await context.close();
  console.log(`[pptx-auth] ✅ 保存先: ${USER_DATA_DIR}`);
  console.log('[pptx-auth] 次回からは pptx-claude.ts が自動でこのセッションを使います');
}

main().catch(e => {
  console.error('[pptx-auth] ❌ エラー:', e.message);
  process.exit(1);
});
