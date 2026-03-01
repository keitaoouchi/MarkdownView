import * as esbuild from 'esbuild';
import { readFileSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outdir = resolve(__dirname, '../Sources/MarkdownView/Resources');

// Step 1: Build core bundle (~175KB) — 15 common languages
await esbuild.build({
  entryPoints: { 'main-core': './src/js/index-core.js' },
  bundle: true,
  minify: true,
  outdir,
  target: ['safari13'],
  legalComments: 'none',
});

// Step 2: Build full bundle (~715KB) — all 113 languages (for lazy injection)
await esbuild.build({
  entryPoints: { main: './src/js/index.js' },
  bundle: true,
  minify: true,
  outdir,
  target: ['safari13'],
  legalComments: 'none',
});

// Step 3: Read built artifacts (use core bundle for HTML inlining)
const coreJs = readFileSync(resolve(outdir, 'main-core.js'), 'utf-8');
const mainCss = readFileSync(resolve(outdir, 'main.css'), 'utf-8');

// Step 4: Generate self-contained HTML templates with inlined core JS/CSS
const styledHtml = `<!doctype html>
<html>
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <style>${mainCss}</style>
        <script>${coreJs}</script>
    </head>
    <body>
        <div class="container markdown-body" id="contents"></div>
    </body>
</html>`;

const nonStyledHtml = `<!doctype html>
<html>
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <script>${coreJs}</script>
    </head>
    <body>
        <div class="container markdown-body" id="contents"></div>
    </body>
</html>`;

writeFileSync(resolve(outdir, 'styled.html'), styledHtml);
writeFileSync(resolve(outdir, 'non_styled.html'), nonStyledHtml);
