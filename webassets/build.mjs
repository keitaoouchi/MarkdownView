import * as esbuild from 'esbuild';
import { readFileSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outdir = resolve(__dirname, '../Sources/MarkdownView/Resources');

// Step 1: Build JS and CSS bundles
await esbuild.build({
  entryPoints: { main: './src/js/index.js' },
  bundle: true,
  minify: true,
  outdir,
  target: ['safari13'],
  legalComments: 'none',
});

// Step 2: Read built artifacts
const mainJs = readFileSync(resolve(outdir, 'main.js'), 'utf-8');
const mainCss = readFileSync(resolve(outdir, 'main.css'), 'utf-8');

// Step 3: Generate self-contained HTML templates with inlined JS/CSS
const styledHtml = `<!doctype html>
<html>
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <style>${mainCss}</style>
        <script>${mainJs}</script>
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
        <script>${mainJs}</script>
    </head>
    <body>
        <div class="container markdown-body" id="contents"></div>
    </body>
</html>`;

writeFileSync(resolve(outdir, 'styled.html'), styledHtml);
writeFileSync(resolve(outdir, 'non_styled.html'), nonStyledHtml);
