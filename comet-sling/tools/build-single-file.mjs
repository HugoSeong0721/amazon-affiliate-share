// 코멧 슬링을 자립형 HTML 한 파일로 빌드한다.
//
// 사용법:  node comet-sling/tools/build-single-file.mjs [출력경로] [--fragment]
// 기본 출력: comet-sling/dist/comet-sling.html

import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { buildSingleFile, parseArgs } from '../../sort-engine/tools/bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const { fragment, outPath } = parseArgs(process.argv, (frag) =>
  join(REPO, 'comet-sling', 'dist', frag ? 'comet-sling.fragment.html' : 'comet-sling.html')
);

buildSingleFile({
  repoRoot: REPO,
  // 선언이 사용보다 먼저 오도록 정렬
  jsFiles: [
    'comet-sling/engine.js',
    'comet-sling/render.js',
    'comet-sling/audio.js',
    'comet-sling/ads.js',
    'comet-sling/signup.js',
    'comet-sling/leaderboard.js',
    'comet-sling/game.js',
    'comet-sling/main.js',
  ],
  htmlFile: 'comet-sling/index.html',
  cssFile: 'comet-sling/style.css',
  title: 'Comet Sling — One-Touch Orbit Dash',
  lang: 'en',
  favicon: '☄️',
  themeColor: '#05040c',
  outPath: resolve(outPath),
  fragment,
});
