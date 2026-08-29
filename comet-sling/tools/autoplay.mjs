// 자동 조종 봇 — 사람이 조준선 보고 하는 판단을 그대로 흉내낸다:
// 계속 누르고 있다가, 위쪽 앵커에 조준이 잠기면 그 순간 놓는다.
//
// 사람 없이 게임이 '플레이 가능한지'를 확인하는 도구다. 실제로 이 봇이
//   - 같은 앵커를 다시 잡아 제자리를 도는 문제
//   - 금색 조준선이 소행성을 통과하는 경로를 안전하다고 알려주는 문제
//   - 오래 플레이할수록 스캔 비용이 늘어 프레임이 끊기는 문제 (maxWindow로 확인)
// 를 찾아냈다.
//
// 사용법: node comet-sling/tools/autoplay.mjs
import { newRun, step, aim, score } from '../engine.js';

export function play(seed, maxSteps = 300000) {
  const s = newRun(seed);
  let maxWA = 0, maxWH = 0, releases = 0;
  for (let i = 0; i < maxSteps && !s.dead; i++) {
    let hold = true;
    if (s.mode === 'orbit') {
      const a = aim(s);
      if (a.snapped !== null && a.dy > 0.4) { hold = false; releases++; }
    }
    step(s, { hold });
    maxWA = Math.max(maxWA, s.anchors.length - s.anchorFrom);
    maxWH = Math.max(maxWH, s.hazards.length - s.hazardFrom);
  }
  return { seed, height: Math.round(s.height), score: score(s), dead: s.dead, cause: s.deathCause,
    releases, anchors: s.anchors.length, anchorFrom: s.anchorFrom, maxWindow: maxWA, maxWindowH: maxWH };
}
if (import.meta.url === `file://${process.argv[1]}`) {
  for (const seed of [1, 42, 777, 2024]) console.log(play(seed));
}
