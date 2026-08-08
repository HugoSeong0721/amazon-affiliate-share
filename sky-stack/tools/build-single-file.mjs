// 스카이 스택을 자립형 HTML 한 파일로 빌드한다.
//
// 사용법:  node sky-stack/tools/build-single-file.mjs [출력경로] [--fragment]
// 기본 출력: sky-stack/dist/sky-stack.html

import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { buildSingleFile, parseArgs } from '../../sort-engine/tools/bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const { fragment, outPath } = parseArgs(process.argv, (frag) =>
  join(REPO, 'sky-stack', 'dist', frag ? 'sky-stack.fragment.html' : 'sky-stack.html')
);

buildSingleFile({
  repoRoot: REPO,
  // 선언이 사용보다 먼저 오도록 정렬
  jsFiles: [
    'sky-stack/engine.js',
    'sky-stack/render.js',
    'sky-stack/audio.js',
    'sky-stack/ads.js',
    'sky-stack/signup.js',
    'sky-stack/game.js',
    'sky-stack/main.js',
  ],
  htmlFile: 'sky-stack/index.html',
  cssFile: 'sky-stack/style.css',
  title: 'Sky Stack — Tap to Stack',
  lang: 'en',
  favicon: '🧱',
  themeColor: '#aee1f7',
  outPath: resolve(outPath),
  fragment,
});
