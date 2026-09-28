import { build } from 'esbuild';
import { copyFile } from 'node:fs/promises';

const destination = '../../Sources/PopChat/Resources/MathJax/';
await build({
  entryPoints: ['renderer.mjs'],
  outfile: destination + 'renderer.js',
  bundle: true,
  format: 'iife',
  globalName: 'PopChatMath',
  platform: 'browser',
  target: 'safari17',
  minify: true,
  legalComments: 'eof',
});
await copyFile('node_modules/@mathjax/src/LICENSE', destination + 'LICENSE.mathjax');
await copyFile('node_modules/mhchemparser/LICENSE.txt', destination + 'LICENSE.mhchemparser');
