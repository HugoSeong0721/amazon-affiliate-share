// 친구 랭킹 로직 테스트 — node --test comet-sling/tests/leaderboard.test.mjs
// leaderboard.js 는 localStorage 를 쓰므로 노드에서는 메모리 셈을 깔아 준다.

import test from 'node:test';
import assert from 'node:assert/strict';

const mem = new Map();
globalThis.localStorage = {
  getItem: (k) => (mem.has(k) ? mem.get(k) : null),
  setItem: (k, v) => mem.set(k, String(v)),
  removeItem: (k) => mem.delete(k),
};

const { myName, setMyName, recordFriend, friends, board } = await import('../leaderboard.js');

test('이름: 처음엔 콜사인을 만들어 주고, 바꾸면 유지된다', () => {
  mem.clear();
  const n = myName();
  assert.match(n, /^Comet-\d{3}$/);
  assert.equal(myName(), n); // 다시 불러도 같다
  assert.equal(setMyName('  Hugo  '), 'Hugo');
  assert.equal(myName(), 'Hugo');
  assert.equal(setMyName(''), 'Hugo'); // 빈 이름은 무시
  assert.equal(setMyName('a'.repeat(30)), 'a'.repeat(14)); // 14자 제한
});

test('친구 기록: 이름당 최고 기록만, 내 이름과 쓰레기 값은 거른다', () => {
  mem.clear();
  setMyName('Me');
  recordFriend('Amy', 100);
  recordFriend('Amy', 50);   // 더 낮음 — 무시
  recordFriend('Amy', 200);  // 갱신
  recordFriend('Me', 999);   // 내 링크를 내가 엶 — 무시
  recordFriend('', 100);     // 이름 없음 — 무시
  recordFriend('Bob', 0);    // 0점 — 무시
  recordFriend('Bob', -5);   // 음수 — 무시
  const f = friends();
  assert.equal(f.length, 1);
  assert.equal(f[0].name, 'Amy');
  assert.equal(f[0].score, 200);
});

test('랭킹판: 나+친구를 점수 내림차순으로, 동점이면 내가 위', () => {
  mem.clear();
  setMyName('Me');
  recordFriend('Amy', 300);
  recordFriend('Bob', 100);
  const rows = board(200);
  assert.deepEqual(rows.map((r) => r.name), ['Amy', 'Me', 'Bob']);
  assert.equal(rows.find((r) => r.me).score, 200);

  const tie = board(300);
  assert.equal(tie[0].name, 'Me'); // 동점은 내가 위
});

test('용량 상한: 50명까지, 낮은 기록부터 밀려난다', () => {
  mem.clear();
  setMyName('Me');
  for (let i = 1; i <= 60; i++) recordFriend(`P${i}`, i * 10);
  const f = friends();
  assert.equal(f.length, 50);
  // 가장 낮은 10명이 밀려났다
  assert.ok(f.every((x) => x.score > 100));
});
