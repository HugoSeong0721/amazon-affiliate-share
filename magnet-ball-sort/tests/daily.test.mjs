import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pour, isWin, CLASSIC_RULES } from '../../sort-engine/index.js';
import {
  dateKey,
  dayNumber,
  keyOf,
  levelForDate,
  streakFrom,
  monthGrid,
  DailyState,
} from '../daily.js';
import { DAILY_POOL } from '../daily-data.js';

const decodeTubes = (tubes) => tubes.map((s) => s.split(''));
const decodeSolution = (sol) => {
  const moves = [];
  for (let i = 0; i + 1 < sol.length; i += 2) moves.push({ from: Number(sol[i]), to: Number(sol[i + 1]) });
  return moves;
};
const colorsOf = (tubes) => [...new Set(tubes.join(''))];

// --- 날짜 계산 ---

test('dateKey 는 로컬 날짜를 YYYY-MM-DD 로 만든다', () => {
  assert.equal(dateKey(new Date(2026, 7, 11)), '2026-08-11');
  assert.equal(dateKey(new Date(2026, 0, 5)), '2026-01-05');
});

test('dayNumber/keyOf 는 서로 역함수다 (자정 경계에서도)', () => {
  for (const key of ['2026-08-11', '2026-01-01', '2026-12-31', '2028-02-29']) {
    assert.equal(keyOf(dayNumber(key)), key);
  }
  assert.equal(dayNumber('2026-08-12') - dayNumber('2026-08-11'), 1);
  assert.equal(dayNumber('2027-01-01') - dayNumber('2026-12-31'), 1);
});

// --- 날짜 → 퍼즐 매핑 ---

test('같은 날짜는 언제나 같은 퍼즐이다 (모두가 같은 판)', () => {
  assert.equal(levelForDate('2026-08-11'), levelForDate('2026-08-11'));
});

test('연이은 날들은 서로 다른 퍼즐이고 난이도가 오르내린다', () => {
  const week = [];
  for (let d = 0; d < 7; d++) week.push(levelForDate(keyOf(dayNumber('2026-08-11') + d)));
  assert.equal(new Set(week).size, 7, '한 주 안에 같은 판이 반복됐다');
  assert.ok(new Set(week.map((l) => l.par)).size >= 3, '한 주의 난이도가 단조롭다');
});

test('풀을 다 돌면 처음부터 재사용된다 (넘어가도 죽지 않는다)', () => {
  const start = dayNumber('2026-08-11');
  assert.equal(
    levelForDate(keyOf(start)),
    levelForDate(keyOf(start + DAILY_POOL.length))
  );
});

// --- 데일리 풀 데이터 자체 ---

test('데일리 풀 전 판의 해가 실제로 클리어로 이어진다', () => {
  assert.ok(DAILY_POOL.length >= 150, `풀이 ${DAILY_POOL.length}판뿐`);
  DAILY_POOL.forEach((lv, i) => {
    assert.ok(lv.tubes.length <= 10, `데일리 ${i}: 튜브 ${lv.tubes.length}개`);
    const targets = colorsOf(lv.tubes);
    let st = { capacity: lv.cap, bottles: decodeTubes(lv.tubes) };
    assert.equal(isWin(st, targets), false, `데일리 ${i}이 시작부터 클리어`);
    const moves = decodeSolution(lv.sol);
    assert.equal(moves.length, lv.par, `데일리 ${i}의 par 불일치`);
    for (const mv of moves) {
      const r = pour(st, mv.from, mv.to, CLASSIC_RULES);
      assert.ok(r, `데일리 ${i} 해 재생 중 불가능한 수`);
      st = r.state;
    }
    assert.equal(isWin(st, targets), true, `데일리 ${i} 해 재생해도 미클리어`);
  });
});

test('데일리 난이도는 "출근길 한 판" 구간에 있다', () => {
  for (const lv of DAILY_POOL) {
    assert.ok(lv.par >= 6 && lv.par <= 28, `par ${lv.par} — 데일리 구간(6~28) 밖`);
  }
});

// --- 스트릭 ---

const k = (offset) => keyOf(dayNumber('2026-08-11') + offset);

test('스트릭: 아무것도 안 했으면 0', () => {
  assert.equal(streakFrom({}, k(0)), 0);
});

test('스트릭: 오늘 하나 깨면 1', () => {
  assert.equal(streakFrom({ [k(0)]: 3 }, k(0)), 1);
});

test('스트릭: 연속된 날들이 이어진다', () => {
  const done = { [k(-2)]: 1, [k(-1)]: 2, [k(0)]: 3 };
  assert.equal(streakFrom(done, k(0)), 3);
});

test('스트릭: 오늘 아직 안 했다고 끊기지 않는다 (자정 전까지 기회)', () => {
  const done = { [k(-2)]: 3, [k(-1)]: 3 };
  assert.equal(streakFrom(done, k(0)), 2);
});

test('스트릭: 하루를 통째로 건너뛰면 끊긴다', () => {
  const done = { [k(-3)]: 3, [k(-2)]: 3, [k(0)]: 3 };
  assert.equal(streakFrom(done, k(0)), 1, '금 것을 빼먹었는데 스트릭이 이어졌다');
  assert.equal(streakFrom({ [k(-3)]: 3, [k(-2)]: 3 }, k(0)), 0, '어제를 빼먹었는데 살아 있다');
});

// --- 달력 모델 ---

test('monthGrid 는 그 달의 모든 날짜 키를 순서대로 준다', () => {
  const g = monthGrid(2026, 7); // 2026년 8월
  assert.equal(g.label, 'August 2026');
  assert.equal(g.keys.length, 31);
  assert.equal(g.keys[0], '2026-08-01');
  assert.equal(g.keys.at(-1), '2026-08-31');
  assert.ok(g.firstDow >= 0 && g.firstDow <= 6);
});

// --- DailyState (node 에는 localStorage 가 없어 메모리로만 돈다) ---

test('도장은 더 좋은 별만 남기고, 최고 스트릭을 기억한다', () => {
  const s = new DailyState();
  s.markDone(k(-1), 2);
  s.markDone(k(0), 1);
  assert.equal(s.streak(k(0)), 2);
  assert.equal(s.best, 2);
  s.markDone(k(0), 3);
  assert.equal(s.starsFor(k(0)), 3, '더 좋은 별로 안 올라갔다');
  s.markDone(k(0), 1);
  assert.equal(s.starsFor(k(0)), 3, '더 나쁜 별로 내려갔다');
});
