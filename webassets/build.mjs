import * as esbuild from 'esbuild';

await esbuild.build({
  entryPoints: { main: './src/js/index.js' },
  bundle: true,
  minify: true,
  outdir: '../Sources/MarkdownView/Resources',
  target: ['safari13'],
  legalComments: 'none',
});
