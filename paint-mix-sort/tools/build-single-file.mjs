// 단일 HTML 파일로 번들링 — 외부 요청이 전혀 없는 자립형 페이지를 만든다.
// 공유 링크, 웹뷰 앱 패키징(Capacitor 등), 오프라인 배포에 그대로 쓸 수 있다.
//
// 사용법:  node paint-mix-sort/tools/build-single-file.mjs [출력경로]
// 기본 출력: paint-mix-sort/dist/paint-mix-sort.html

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const outPath = process.argv[2]
  ? resolve(process.argv[2])
  : join(REPO, 'paint-mix-sort', 'dist', 'paint-mix-sort.html');

const read = (p) => readFileSync(join(REPO, p), 'utf8');

// 런타임에 실제로 쓰이는 모듈만, 선언이 사용보다 먼저 오도록 정렬.
// generator.js는 레벨이 미리 구워져 있으므로 제외한다.
const JS_FILES = [
  'sort-engine/colors.js',
  'sort-engine/state.js',
  'sort-engine/moves.js',
  'sort-engine/solver.js',
  'paint-mix-sort/levels-data.js',
  'paint-mix-sort/render.js',
  'paint-mix-sort/audio.js',
  'paint-mix-sort/game.js',
  'paint-mix-sort/main.js',
];

// 모든 파일이 하나의 모듈 스코프로 합쳐지므로 import/export 구문만 걷어내면 된다.
function stripModuleSyntax(src) {
  return src
    .replace(/^import\s[\s\S]*?from\s*'[^']*';\s*$/gm, '')
    .replace(/^export\s*\{[^}]*\}\s*;?\s*$/gm, '')
    .replace(/^export\s+(?=(const|let|var|function|class))/gm, '');
}

// 샌드박스(iframe 등)에서 localStorage 접근이 차단돼도 게임이 죽지 않도록 폴백을 끼운다.
const SAFE_STORAGE = `
const safeStorage = (() => {
  try {
    localStorage.setItem('__pms_probe', '1');
    localStorage.removeItem('__pms_probe');
    return localStorage;
  } catch {
    const mem = new Map();
    return {
      getItem: (k) => (mem.has(k) ? mem.get(k) : null),
      setItem: (k, v) => mem.set(k, String(v)),
      removeItem: (k) => mem.delete(k),
    };
  }
})();
`;

let bundle = JS_FILES.map((f) => `// ===== ${f} =====\n${stripModuleSyntax(read(f))}`).join('\n');
bundle = bundle.replace(/\blocalStorage\./g, 'safeStorage.');
if (/^\s*(import|export)\s/m.test(bundle)) {
  throw new Error('번들에 import/export가 남아 있습니다 — JS_FILES 순서나 strip 규칙을 확인하세요');
}

const html = read('paint-mix-sort/index.html');
const appMarkup = html.match(/(<div id="app">[\s\S]*<\/div>)\s*<script/);
if (!appMarkup) throw new Error('index.html에서 #app 마크업을 찾지 못했습니다');

const page = `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="theme-color" content="#14152b">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🎨</text></svg>">
<title>페인트 믹스 — 색을 섞는 소트 퍼즐</title>
<style>
${read('paint-mix-sort/style.css')}
</style>
</head>
<body>
${appMarkup[1]}
<script type="module">
${SAFE_STORAGE}
${bundle}
</script>
</body>
</html>
`;

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, page);
console.log(`단일 파일 빌드 완료 → ${outPath} (${(page.length / 1024).toFixed(0)}KB, 외부 의존 0)`);
