import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildShareText, shareResult, COLOR_EMOJI } from '../share.js';
import { DailyState } from '../daily.js';

const base = {
  label: 'Aug 11',
  moves: 12,
  par: 11,
  stars: 2,
  streak: 5,
  colors: ['R', 'Y', 'B'],
  url: 'https://example.com/game',
};

test('공유 카드에 날짜·색·기록·스트릭·링크가 다 담긴다', () => {
  const text = buildShareText(base);
  const lines = text.split('\n');
  assert.equal(lines[0], '🧲 Magnet Balls Daily — Aug 11');
  assert.equal(lines[1], '🔴🟡🔵');
  assert.equal(lines[2], '⭐⭐ 12 moves · Par 11');
  assert.equal(lines[3], '🔥 5-day streak');
  assert.ok(lines[4].endsWith(base.url), '링크가 마지막 줄에 없다');
});

test('스트릭 1일은 자랑거리가 아니라 줄을 뺀다', () => {
  const text = buildShareText({ ...base, streak: 1 });
  assert.ok(!text.includes('streak'), '1일 스트릭이 카드에 들어갔다');
});

test('수 기록이 없으면(예전 저장) 클리어 사실만 말한다', () => {
  const text = buildShareText({ ...base, moves: null });
  assert.ok(text.includes('Par 11 — cleared!'));
  assert.ok(!text.includes('null'));
});

test('팔레트 여덟 색 모두 이모지가 있다', () => {
  for (const c of ['R', 'O', 'Y', 'G', 'C', 'B', 'P', 'K']) {
    assert.ok(COLOR_EMOJI[c], `${c} 색 이모지가 없다`);
  }
});

test('네이티브 공유가 있으면 그쪽을, 없으면 클립보드를 쓴다', async () => {
  let shared = null;
  assert.equal(
    await shareResult('hi', { share: async (d) => (shared = d.text) }),
    'shared'
  );
  assert.equal(shared, 'hi');

  let copied = null;
  assert.equal(
    await shareResult('yo', { clipboard: { writeText: async (t) => (copied = t) } }),
    'copied'
  );
  assert.equal(copied, 'yo');
});

test('공유 시트를 닫은 것은 실패가 아니다', async () => {
  const abort = Object.assign(new Error('x'), { name: 'AbortError' });
  assert.equal(
    await shareResult('hi', {
      share: async () => {
        throw abort;
      },
    }),
    'cancelled'
  );
});

test('공유가 막히면 클립보드로 넘어가고, 그것도 안 되면 failed', async () => {
  const blocked = {
    share: async () => {
      throw new Error('NotAllowed');
    },
    clipboard: { writeText: async () => {} },
  };
  assert.equal(await shareResult('hi', blocked), 'copied');
  assert.equal(await shareResult('hi', {}), 'failed');
});

test('DailyState 는 별과 최소 수를 함께 기억한다 (더 좋은 기록만)', () => {
  const s = new DailyState();
  s.markDone('2026-08-11', 2, 14);
  assert.equal(s.starsFor('2026-08-11'), 2);
  assert.equal(s.movesFor('2026-08-11'), 14);
  s.markDone('2026-08-11', 3, 16); // 별은 좋아졌지만 수는 나빠짐
  assert.equal(s.starsFor('2026-08-11'), 3);
  assert.equal(s.movesFor('2026-08-11'), 14, '더 많은 수로 갱신됐다');
  s.markDone('2026-08-11', 1, 11); // 수는 좋아졌지만 별은 나빠짐
  assert.equal(s.starsFor('2026-08-11'), 3);
  assert.equal(s.movesFor('2026-08-11'), 11);
});

test('예전 형식(숫자 별)도 그대로 읽힌다', () => {
  const s = new DailyState();
  s.done['2026-08-10'] = 2; // 옛 저장 형식
  assert.equal(s.starsFor('2026-08-10'), 2);
  assert.equal(s.movesFor('2026-08-10'), null);
  assert.equal(s.isDone('2026-08-10'), true);
  s.markDone('2026-08-10', 3, 9);
  assert.equal(s.starsFor('2026-08-10'), 3);
  assert.equal(s.movesFor('2026-08-10'), 9);
});
