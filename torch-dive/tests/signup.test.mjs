// 가입 게이트의 순수 부분 테스트 — node --test torch-dive/tests/signup.test.mjs
// DOM/네트워크 없이 검증할 수 있는 것: 이메일 검증, Google ID 토큰 payload 디코드, 수집 레코드.

import test from 'node:test';
import assert from 'node:assert/strict';
import { validateEmail, decodeJwtPayload, makeRecord } from '../signup.js';

test('validateEmail — 붙잡을 것과 놓아줄 것', () => {
  assert.ok(validateEmail('hugo.se@iottie.com'));
  assert.ok(validateEmail('  a.b+tag@sub.domain.co  ')); // 앞뒤 공백은 눈감아 준다
  assert.ok(!validateEmail(''));
  assert.ok(!validateEmail(null));
  assert.ok(!validateEmail('notanemail'));
  assert.ok(!validateEmail('a@b')); // TLD 없음
  assert.ok(!validateEmail('a b@c.com')); // 중간 공백
  assert.ok(!validateEmail('@no-local.com'));
});

function fakeJwt(payload) {
  const b64url = (obj) =>
    Buffer.from(JSON.stringify(obj)).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${b64url({ alg: 'RS256' })}.${b64url(payload)}.fake-signature`;
}

test('decodeJwtPayload — base64url + 패딩 없음 + 유니코드까지', () => {
  const payload = { email: 'diver@example.com', name: '토치 다이버', email_verified: true };
  assert.deepEqual(decodeJwtPayload(fakeJwt(payload)), payload);
});

test('decodeJwtPayload — 깨진 입력은 조용히 null', () => {
  assert.equal(decodeJwtPayload(null), null);
  assert.equal(decodeJwtPayload(''), null);
  assert.equal(decodeJwtPayload('not-a-jwt'), null);
  assert.equal(decodeJwtPayload('a.%%%.c'), null);
});

test('makeRecord — 이메일은 소문자로 접고, 게임과 날짜가 찍힌다', () => {
  const r = makeRecord('  Diver@Example.COM ', 'google', '2026-08-06');
  assert.equal(r.email, 'diver@example.com');
  assert.equal(r.via, 'google');
  assert.equal(r.day, '2026-08-06');
  assert.equal(r.game, 'torch-dive');
  assert.ok(!Number.isNaN(Date.parse(r.at)));
});
