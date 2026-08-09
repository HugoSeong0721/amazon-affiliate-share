// 공유·랭킹의 순수 부분 테스트 — node --test sky-stack/tests/social.test.mjs
// 서버도 DOM도 없이 검증할 수 있는 것: 표시 이름, 서버 응답 정규화, 순위 계산, 공유 문구.

import test from 'node:test';
import assert from 'node:assert/strict';
import { displayName, normalizeTop, myRank, LEADERBOARD_CONFIG } from '../leaderboard.js';
import { shareText, shareUrl, share } from '../share.js';

test('displayName — 가입 이메일의 @ 앞부분이 최우선', () => {
  assert.equal(displayName({ email: 'hugo.se@iottie.com' }, null), 'hugo.se');
  assert.equal(displayName({ email: 'a@b.com' }, 'stored'), 'a');
});

test('displayName — 이메일이 없으면 저장된 이름, 그것도 없으면 Player###', () => {
  assert.equal(displayName(null, 'Stacker'), 'Stacker');
  assert.equal(displayName({ guest: true }, 'Stacker'), 'Stacker');
  assert.equal(displayName(null, null, () => 0.5), 'Player550');
  assert.match(displayName(null, '  ', () => 0), /^Player\d{3}$/);
});

test('displayName — 14자를 넘지 않는다 (보드가 깨지지 않게)', () => {
  const long = 'a'.repeat(40);
  assert.equal(displayName({ email: `${long}@x.com` }, null).length, 14);
  assert.equal(displayName(null, long).length, 14);
});

test('normalizeTop — 형식이 맞는 행만, 점수 내림차순, topN까지', () => {
  const raw = [
    { name: 'a', score: 5 },
    { name: 'b', score: '12' }, // 문자열 숫자도 받아준다
    { name: 'c', score: 9 },
    { name: 'bad' }, // 점수 없음 — 버린다
    { score: 100 }, // 이름 없음 — 버린다
    null,
    { name: 'd', score: 'NaN' },
  ];
  assert.deepEqual(normalizeTop(raw), [
    { name: 'b', score: 12 },
    { name: 'c', score: 9 },
    { name: 'a', score: 5 },
  ]);
});

test('normalizeTop — 배열이 아니면 빈 목록 (서버를 신뢰하지 않는다)', () => {
  assert.deepEqual(normalizeTop(null), []);
  assert.deepEqual(normalizeTop({ oops: true }), []);
  assert.deepEqual(normalizeTop('hacked'), []);
});

test('normalizeTop — 점수는 음수가 되지 않고 정수로 접힌다', () => {
  assert.deepEqual(normalizeTop([{ name: 'x', score: -5 }, { name: 'y', score: 3.9 }]), [
    { name: 'y', score: 3 },
    { name: 'x', score: 0 },
  ]);
});

test('normalizeTop — topN을 넘지 않는다', () => {
  const many = Array.from({ length: 50 }, (_, i) => ({ name: `p${i}`, score: i }));
  assert.equal(normalizeTop(many).length, LEADERBOARD_CONFIG.topN);
  assert.equal(normalizeTop(many, 5).length, 5);
});

test('myRank — 목록 안에서의 자리', () => {
  const top = [
    { name: 'a', score: 30 },
    { name: 'b', score: 20 },
    { name: 'c', score: 10 },
  ];
  assert.equal(myRank(top, 35), 1);
  assert.equal(myRank(top, 30), 1); // 동점이면 앞자리를 준다
  assert.equal(myRank(top, 25), 2);
  assert.equal(myRank(top, 5), 4); // 목록이 아직 짧으면 뒤에 붙는다
  assert.equal(myRank(top, 0), null);
});

test('myRank — 목록이 꽉 찼고 내 점수가 밖이면 null', () => {
  const full = Array.from({ length: LEADERBOARD_CONFIG.topN }, () => ({ name: 'x', score: 100 }));
  assert.equal(myRank(full, 5), null);
  assert.equal(myRank(full, 100), 1);
});

test('shareText — 점수가 있으면 자랑, 없으면 초대', () => {
  assert.match(shareText(42), /42 blocks/);
  assert.match(shareText(0), /How high/);
});

test('shareUrl — 테스트 쿼리(?seed 등)는 떼고 보낸다', () => {
  const loc = { origin: 'https://example.com', pathname: '/sky-stack/', search: '?seed=7&noads' };
  assert.equal(shareUrl(loc), 'https://example.com/sky-stack/');
});

test('share — 시스템 공유 시트가 있으면 그걸 쓴다', async () => {
  const calls = [];
  const nav = { share: async (d) => calls.push(d) };
  const loc = { origin: 'https://x.io', pathname: '/g/', search: '' };
  assert.equal(await share(12, { nav, loc }), 'shared');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://x.io/g/');
  assert.match(calls[0].text, /12 blocks/);
});

test('share — 사용자가 시트를 닫으면 조용히 넘어간다', async () => {
  const nav = { share: async () => { throw new Error('AbortError'); } };
  const loc = { origin: 'https://x.io', pathname: '/g/', search: '' };
  assert.equal(await share(3, { nav, loc }), 'cancelled');
});

test('share — 공유 시트가 없으면 클립보드로 폴백한다', async () => {
  let copied = '';
  const nav = { clipboard: { writeText: async (t) => { copied = t; } } };
  const loc = { origin: 'https://x.io', pathname: '/g/', search: '' };
  assert.equal(await share(7, { nav, loc }), 'copied');
  assert.match(copied, /7 blocks/);
  assert.match(copied, /https:\/\/x\.io\/g\//);
});

test('share — 클립보드마저 막히면 failed (게임은 계속된다)', async () => {
  const nav = { clipboard: { writeText: async () => { throw new Error('denied'); } } };
  const loc = { origin: 'https://x.io', pathname: '/g/', search: '' };
  assert.equal(await share(1, { nav, loc }), 'failed');
});
