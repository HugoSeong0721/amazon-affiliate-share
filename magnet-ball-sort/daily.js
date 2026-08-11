// 데일리 챌린지 — 매일 하나의 특별 퍼즐, 달력 도장, 스트릭(연속 출석).
//
// 돌아올 이유를 만드는 층이다. 여정(캠페인)은 "계속 하게" 만들지만
// "내일 다시 오게" 만들지는 못한다 — 그 빈 자리를 채운다:
//   - 퍼즐은 모두에게 같다 (친구와 "오늘 거 몇 수에 깼어?"가 성립한다)
//   - 날짜가 지나면 사라진다 (오늘 안 하면 도장이 빈다 — 가벼운 손실 회피)
//   - 스트릭은 오늘 것을 아직 안 했다고 끊기지 않는다. 하루를 통째로
//     건너뛰어야 끊긴다 (자기 전에 열어본 사람을 벌주지 않는다)
//
// 날짜는 기기 로컬 기준이다 — 플레이어의 자정에 바뀌는 게 자연스럽다.

import { DAILY_POOL } from './daily-data.js';

const STORAGE_DAILY = 'mbs.daily'; // { done: {"2026-08-11": 별수}, best: n }

export const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// 로컬 날짜 → 'YYYY-MM-DD'
export function dateKey(d = new Date()) {
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
}

// 키 → 통산 일수 (키는 이미 로컬로 확정된 날짜라 UTC 산술이 안전하다)
export function dayNumber(key) {
  const [y, m, d] = key.split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / 86400000);
}

export function keyOf(dayNum) {
  return new Date(dayNum * 86400000).toISOString().slice(0, 10);
}

// 그 날의 퍼즐. 풀은 구울 때 섞여 있어 연이은 날의 난이도가 오르내린다.
// 풀을 다 돌면 처음부터 재사용된다.
export function levelForDate(key, pool = DAILY_POOL) {
  return pool[dayNumber(key) % pool.length];
}

// 스트릭: 오늘(아직 안 했으면 어제)부터 거꾸로 이어진 완료 일수.
export function streakFrom(done, todayKey) {
  let day = dayNumber(todayKey);
  if (!done[todayKey]) day -= 1; // 오늘 몫은 자정 전까지 기회가 남아 있다
  let n = 0;
  while (done[keyOf(day)]) {
    n += 1;
    day -= 1;
  }
  return n;
}

// 달력 한 달 치 모델. UI는 이걸 그대로 그린다.
export function monthGrid(year, month /* 0-11 */) {
  const first = new Date(year, month, 1);
  const days = new Date(year, month + 1, 0).getDate();
  return {
    label: `${MONTHS[month]} ${year}`,
    firstDow: first.getDay(), // 0 = 일요일
    keys: Array.from({ length: days }, (_, i) =>
      dateKey(new Date(year, month, i + 1))
    ),
  };
}

export class DailyState {
  constructor() {
    let saved = {};
    try {
      saved = JSON.parse(localStorage.getItem(STORAGE_DAILY) || '{}');
    } catch {
      saved = {};
    }
    this.done = saved.done && typeof saved.done === 'object' ? saved.done : {};
    this.best = Number(saved.best) || 0;
  }

  _save() {
    try {
      localStorage.setItem(STORAGE_DAILY, JSON.stringify({ done: this.done, best: this.best }));
    } catch {}
  }

  isDone(key) {
    return !!this.done[key];
  }

  starsFor(key) {
    return Number(this.done[key]) || 0;
  }

  // 다시 깨면 별은 더 좋은 쪽만 남는다
  markDone(key, stars) {
    this.done[key] = Math.max(this.starsFor(key), Math.min(Math.max(stars, 1), 3));
    this.best = Math.max(this.best, this.streak(key));
    this._save();
  }

  streak(todayKey = dateKey()) {
    return streakFrom(this.done, todayKey);
  }
}
