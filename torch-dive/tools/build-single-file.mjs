// 토치 다이브를 자립형 HTML 한 파일로 빌드한다.
//
// 사용법:  node torch-dive/tools/build-single-file.mjs [출력경로] [--fragment]
// 기본 출력: torch-dive/dist/torch-dive.html

import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { buildSingleFile, parseArgs } from '../../sort-engine/tools/bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const { fragment, outPath } = parseArgs(process.argv, (frag) =>
  join(REPO, 'torch-dive', 'dist', frag ? 'torch-dive.fragment.html' : 'torch-dive.html')
);

buildSingleFile({
  repoRoot: REPO,
  // 선언이 사용보다 먼저 오도록 정렬
  jsFiles: [
    'torch-dive/engine.js',
    'torch-dive/render.js',
    'torch-dive/audio.js',
    'torch-dive/ads.js',
    'torch-dive/game.js',
    'torch-dive/main.js',
  ],
  htmlFile: 'torch-dive/index.html',
  cssFile: 'torch-dive/style.css',
  title: 'Torch Dive — One More Floor',
  lang: 'en',
  favicon: '🔥',
  themeColor: '#0d0805',
  outPath: resolve(outPath),
  fragment,
});
