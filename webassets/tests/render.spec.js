import { test, expect } from '@playwright/test';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const mainJsPath = resolve(__dirname, '../../Sources/MarkdownView/Resources/main.js');

const encode = (md) => encodeURIComponent(md);

test.beforeEach(async ({ page }) => {
  await page.setContent('<html><body><div id="contents"></div></body></html>');

  // WKWebView の webkit.messageHandlers をモック
  await page.evaluate(() => {
    window._postMessageCalls = [];
    window.webkit = {
      messageHandlers: {
        updateHeight: {
          postMessage: (height) => window._postMessageCalls.push(height),
        },
      },
    };
  });

  await page.addScriptTag({ path: mainJsPath });
});

// --- 基本レンダリング ---

test('見出し h1 がレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('# Hello World'));
  await expect(page.locator('#contents h1')).toContainText('Hello World');
});

test('見出し h2 がレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('## Section'));
  await expect(page.locator('#contents h2')).toContainText('Section');
});

test('段落がレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('Hello, world.'));
  await expect(page.locator('#contents p')).toContainText('Hello, world.');
});

test('箇条書きリストがレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('- Apple\n- Banana\n- Cherry'));
  await expect(page.locator('#contents ul li')).toHaveCount(3);
});

test('太字がレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('**bold**'));
  await expect(page.locator('#contents strong')).toContainText('bold');
});

test('インラインコードがレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('`hello`'));
  await expect(page.locator('#contents code')).toContainText('hello');
});

// --- highlight.js ---

test('コードブロックに hljs クラスが付与される', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('```js\nconsole.log("hi")\n```'));
  const code = page.locator('#contents pre code');
  await expect(code).toHaveClass(/hljs/);
});

test('Swift コードブロックがハイライトされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('```swift\nlet x = 42\n```'));
  const code = page.locator('#contents pre code');
  await expect(code).toHaveClass(/hljs/);
});

test('Python コードブロックがハイライトされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('```python\nprint("hello")\n```'));
  const code = page.locator('#contents pre code');
  await expect(code).toHaveClass(/hljs/);
});

// --- 絵文字 ---

test('絵文字ショートコードが変換される', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode(':smile:'));
  const text = await page.locator('#contents').textContent();
  expect(text).toContain('😄');
});

// --- テーブル ---

test('テーブルに Bootstrap の table クラスが付与される', async ({ page }) => {
  const md = '| A | B |\n|---|---|\n| 1 | 2 |';
  await page.evaluate((md) => window.showMarkdown(md), encode(md));
  await expect(page.locator('#contents table')).toHaveClass(/\btable\b/);
});

// --- 画像制御 ---

test('enableImage=true で画像がレンダリングされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md, true), encode('![alt](https://example.com/img.png)'));
  await expect(page.locator('#contents img')).toHaveCount(1);
});

test('enableImage=false で画像が除去される', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md, false), encode('![alt](https://example.com/img.png)'));
  await expect(page.locator('#contents img')).toHaveCount(0);
});

// --- webkit 高さ通知 ---

test('showMarkdown 呼び出し後に updateHeight が通知される', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('# Test'));
  const calls = await page.evaluate(() => window._postMessageCalls);
  expect(calls.length).toBeGreaterThan(0);
  expect(calls[0]).toBeGreaterThan(0);
});

// --- エッジケース ---

test('空文字列は何もレンダリングしない', async ({ page }) => {
  await page.evaluate(() => window.showMarkdown(''));
  const html = await page.locator('#contents').innerHTML();
  expect(html).toBe('');
});

test('showMarkdown を複数回呼ぶと内容が上書きされる', async ({ page }) => {
  await page.evaluate((md) => window.showMarkdown(md), encode('# First'));
  await page.evaluate((md) => window.showMarkdown(md), encode('# Second'));
  await expect(page.locator('#contents h1')).toContainText('Second');
  await expect(page.locator('#contents h1')).toHaveCount(1);
});
