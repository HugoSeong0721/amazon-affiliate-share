// 주차장 탈출을 자립형 HTML 한 파일로 빌드한다.
//
// 사용법:  node parking-escape/tools/build-single-file.mjs [출력경로] [--fragment]
// 기본 출력: parking-escape/dist/parking-escape.html

import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { buildSingleFile, parseArgs } from '../../sort-engine/tools/bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const { fragment, outPath } = parseArgs(process.argv, (frag) =>
  join(REPO, 'parking-escape', 'dist', frag ? 'parking-escape.fragment.html' : 'parking-escape.html')
);

buildSingleFile({
  repoRoot: REPO,
  // 선언이 사용보다 먼저 오도록 정렬. 레벨은 미리 구워져 있어 generator가 필요 없지만
  // engine.js 안에 함께 살고 순수 함수라 그대로 담는다.
  jsFiles: [
    'parking-escape/engine.js',
    'parking-escape/levels-data.js',
    'parking-escape/render.js',
    'parking-escape/audio.js',
    'parking-escape/ads.js',
    'parking-escape/signup.js',
    'parking-escape/game.js',
    'parking-escape/main.js',
  ],
  htmlFile: 'parking-escape/index.html',
  cssFile: 'parking-escape/style.css',
  title: 'Taxi Out — Parking Escape Puzzle',
  lang: 'en',
  favicon: '🚕',
  themeColor: '#101728',
  outPath: resolve(outPath),
  fragment,
});
