// 데일리 결과 공유 — Wordle 식 도전장.
//
// 경쟁의식은 "남이 보일 때" 생긴다. 서버 랭킹 없이 그걸 만드는 검증된 방법이
// 결과 카드다: 오늘의 색·수·별·스트릭을 이모지 몇 줄로 압축해 메신저로 보낸다.
// 받는 쪽에는 도전장이고, 링크가 붙어 있으니 신규 유입 경로이기도 하다.
//
// 모바일은 네이티브 공유 시트(navigator.share → 카톡/문자/뭐든), 데스크톱은
// 클립보드 복사로 떨어진다. 어느 쪽도 안 되면 조용히 실패를 알린다.

export const COLOR_EMOJI = {
  R: '🔴', O: '🟠', Y: '🟡', G: '🟢', C: '🩵', B: '🔵', P: '🟣', K: '⚫',
};

// 카드 본문. 날마다 색 줄이 달라져서 같은 게임 카드라도 매일 다르게 보인다.
export function buildShareText({ label, moves, par, stars, streak, colors, url }) {
  const colorRow = (colors || []).map((c) => COLOR_EMOJI[c] || '').join('');
  const starRow = '⭐'.repeat(Math.max(0, Math.min(stars || 0, 3)));
  const score =
    moves == null
      ? `${starRow} Par ${par} — cleared!`
      : `${starRow} ${moves} moves · Par ${par}`;

  const lines = [`🧲 Magnet Balls Daily — ${label}`];
  if (colorRow) lines.push(colorRow);
  lines.push(score);
  if ((streak || 0) >= 2) lines.push(`🔥 ${streak}-day streak`);
  lines.push(`Can you beat me? ${url}`);
  return lines.join('\n');
}

// 공유 실행. 결과: 'shared' | 'copied' | 'cancelled' | 'failed'
// (cancelled = 유저가 공유 시트를 닫음 — 실패로 보여주면 안 된다)
export async function shareResult(text, nav = typeof navigator !== 'undefined' ? navigator : {}) {
  if (nav.share) {
    try {
      await nav.share({ text });
      return 'shared';
    } catch (e) {
      if (e?.name === 'AbortError') return 'cancelled';
      // 공유 시트가 막힌 환경이면 클립보드로 넘어간다
    }
  }
  try {
    await nav.clipboard.writeText(text);
    return 'copied';
  } catch {
    return 'failed';
  }
}
