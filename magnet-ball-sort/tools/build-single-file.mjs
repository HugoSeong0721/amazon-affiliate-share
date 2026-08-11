// 자석 구슬 소트를 자립형 HTML 한 파일로 빌드한다.
//
// 사용법:  node magnet-ball-sort/tools/build-single-file.mjs [출력경로] [--fragment]
// 기본 출력: magnet-ball-sort/dist/magnet-ball-sort.html

import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { buildSingleFile, parseArgs } from '../../sort-engine/tools/bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const { fragment, outPath } = parseArgs(process.argv, (frag) =>
  join(REPO, 'magnet-ball-sort', 'dist', frag ? 'magnet-ball-sort.fragment.html' : 'magnet-ball-sort.html')
);

buildSingleFile({
  repoRoot: REPO,
  // 선언이 사용보다 먼저 오도록 정렬. generator는 레벨이 미리 구워져 있어 제외한다.
  jsFiles: [
    'sort-engine/colors.js',
    'sort-engine/state.js',
    'sort-engine/moves.js',
    'sort-engine/solver.js',
    'magnet-ball-sort/levels-data.js',
    'magnet-ball-sort/daily-data.js',
    'magnet-ball-sort/render.js',
    'magnet-ball-sort/audio.js',
    'magnet-ball-sort/ads.js',
    'magnet-ball-sort/cloud.js',
    'magnet-ball-sort/auth.js',
    'magnet-ball-sort/daily.js',
    'magnet-ball-sort/game.js',
    'magnet-ball-sort/main.js',
  ],
  htmlFile: 'magnet-ball-sort/index.html',
  cssFile: 'magnet-ball-sort/style.css',
  title: 'Magnet Balls — Color Sort Puzzle',
  lang: 'en',
  favicon: '🧲',
  themeColor: '#0f1830',
  outPath: resolve(outPath),
  fragment,
});
