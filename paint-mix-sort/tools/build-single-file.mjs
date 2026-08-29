// 페인트 믹스를 자립형 HTML 한 파일로 빌드한다.
//
// 사용법:  node paint-mix-sort/tools/build-single-file.mjs [출력경로] [--fragment]
// 기본 출력: paint-mix-sort/dist/paint-mix-sort.html

import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { buildSingleFile, parseArgs } from '../../sort-engine/tools/bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const { fragment, outPath } = parseArgs(process.argv, (frag) =>
  join(REPO, 'paint-mix-sort', 'dist', frag ? 'paint-mix-sort.fragment.html' : 'paint-mix-sort.html')
);

buildSingleFile({
  repoRoot: REPO,
  // 선언이 사용보다 먼저 오도록 정렬. generator는 레벨이 미리 구워져 있어 제외한다.
  jsFiles: [
    'sort-engine/colors.js',
    'sort-engine/state.js',
    'sort-engine/moves.js',
    'sort-engine/solver.js',
    'paint-mix-sort/levels-data.js',
    'paint-mix-sort/render.js',
    'paint-mix-sort/audio.js',
    'paint-mix-sort/game.js',
    'paint-mix-sort/main.js',
  ],
  htmlFile: 'paint-mix-sort/index.html',
  cssFile: 'paint-mix-sort/style.css',
  title: '페인트 믹스 — 색을 섞는 소트 퍼즐',
  favicon: '🎨',
  themeColor: '#14152b',
  outPath: resolve(outPath),
  fragment,
});
