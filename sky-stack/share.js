// 친구 공유 — 모바일이면 시스템 공유 시트(카톡·문자·인스타 다 뜬다),
// 그 외에는 클립보드 복사로 폴백한다. 어느 쪽이든 한 번의 탭이다.

export function shareText(score) {
  return score > 0
    ? `Sky Stack 🧱 I stacked ${score} blocks — can you beat me?`
    : `Sky Stack 🧱 tap to stack. How high can you go?`;
}

// 게임의 공유용 주소 — 테스트 쿼리(?seed 등)는 떼고 보낸다
export function shareUrl(loc = location) {
  return `${loc.origin}${loc.pathname}`;
}

export async function share(score, { nav = navigator, loc = location } = {}) {
  const text = shareText(score);
  const url = shareUrl(loc);
  if (nav.share) {
    try {
      await nav.share({ title: 'Sky Stack', text, url });
      return 'shared';
    } catch {
      return 'cancelled'; // 사용자가 시트를 닫음 — 조용히 넘어간다
    }
  }
  try {
    await nav.clipboard.writeText(`${text} ${url}`);
    return 'copied';
  } catch {
    return 'failed';
  }
}
