// 게임 하나를 외부 요청이 전혀 없는 자립형 HTML 한 파일로 묶는다.
// 이 엔진 위에 올라가는 게임들이 공유하는 빌드 로직 — 게임마다 얇은 래퍼만 두면 된다.
//
// 공유 링크, 웹뷰 앱 패키징(Capacitor 등), 오프라인 배포에 그대로 쓸 수 있다.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';

// 모든 파일이 하나의 모듈 스코프로 합쳐지므로 import/export 구문만 걷어내면 된다.
function stripModuleSyntax(src) {
  return src
    .replace(/^import\s[\s\S]*?from\s*'[^']*';\s*$/gm, '')
    .replace(/^export\s*\{[^}]*\}\s*;?\s*$/gm, '')
    .replace(/^export\s+(?=(async\s+function|const|let|var|function|class))/gm, '');
}

// 샌드박스(iframe 등)에서 localStorage 접근이 차단돼도 게임이 죽지 않도록 폴백을 끼운다.
const SAFE_STORAGE = `
const safeStorage = (() => {
  try {
    localStorage.setItem('__probe', '1');
    localStorage.removeItem('__probe');
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

/**
 * @param {object} opts
 * @param {string} opts.repoRoot     레포 루트 절대경로
 * @param {string[]} opts.jsFiles    레포 기준 상대경로. 선언이 사용보다 먼저 오도록 정렬해야 한다.
 * @param {string} opts.htmlFile     #app 마크업을 꺼낼 index.html (레포 기준 상대경로)
 * @param {string} opts.cssFile      인라인할 CSS (레포 기준 상대경로)
 * @param {string} opts.title        <title>
 * @param {string} opts.favicon      파비콘 이모지
 * @param {string} opts.themeColor   theme-color 메타값
 * @param {string} [opts.lang]      html lang 속성 (기본 'ko')
 * @param {string} opts.outPath      출력 절대경로
 * @param {boolean} [opts.fragment]  true면 <!DOCTYPE>/<html>/<head>/<body> 껍데기를 뺀다
 */
export function buildSingleFile(opts) {
  const { repoRoot, jsFiles, htmlFile, cssFile, title, favicon, themeColor, outPath, fragment, lang = 'ko' } = opts;
  const read = (p) => readFileSync(join(repoRoot, p), 'utf8');

  let bundle = jsFiles.map((f) => `// ===== ${f} =====\n${stripModuleSyntax(read(f))}`).join('\n');
  bundle = bundle.replace(/\blocalStorage\./g, 'safeStorage.');
  if (/^\s*(import|export)\s/m.test(bundle)) {
    throw new Error('번들에 import/export가 남아 있습니다 — jsFiles 순서나 strip 규칙을 확인하세요');
  }
  // 파일들이 한 스코프로 합쳐지므로 최상위 선언이 충돌하면 페이지 전체가 죽는다.
  // 배포 전에 파싱해서 잡는다 (예: 두 파일이 같은 이름의 const를 선언).
  try {
    new Function(SAFE_STORAGE + bundle);
  } catch (e) {
    throw new Error(`번들이 파싱되지 않습니다 — 최상위 선언 충돌 가능성: ${e.message}`);
  }

  const html = read(htmlFile);
  const app = html.match(/(<div id="app">[\s\S]*<\/div>)\s*<script/);
  if (!app) throw new Error(`${htmlFile}에서 #app 마크업을 찾지 못했습니다`);

  const HEAD = `<title>${title}</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="theme-color" content="${themeColor}">
<style>
${read(cssFile)}
</style>`;

  const BODY = `${app[1]}
<script type="module">
${SAFE_STORAGE}
${bundle}
</script>`;

  // 조각 모드에서는 호스트가 <head>를 따로 주지 않으므로 전부 이어서 낸다.
  // 브라우저는 body 안의 <title>/<meta>/<style>도 정상 처리한다.
  const page = fragment
    ? `${HEAD}\n${BODY}\n`
    : `<!DOCTYPE html>
<html lang="${lang}">
<head>
<meta charset="UTF-8">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>${favicon}</text></svg>">
${HEAD}
</head>
<body>
${BODY}
</body>
</html>
`;

  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, page);
  console.log(
    `${fragment ? '조각' : '단일 파일'} 빌드 완료 → ${outPath} (${(page.length / 1024).toFixed(0)}KB, 외부 의존 0)`
  );
  return page;
}

// 커맨드라인 인자 파싱: [출력경로] [--fragment]
export function parseArgs(argv, defaultOut) {
  const args = argv.slice(2);
  const fragment = args.includes('--fragment');
  const outArg = args.find((a) => !a.startsWith('--'));
  return { fragment, outPath: outArg || defaultOut(fragment) };
}
