import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mergeProgress,
  toFirestoreFields,
  fromFirestoreFields,
  jwtPayload,
  createFirestoreSync,
} from '../cloud.js';
import { AuthManager, AUTH_CONFIG, createFakeAuthProvider } from '../auth.js';

// --- 진행 병합 ---

test('병합은 항상 더 나아간 쪽을 취한다', () => {
  const m = mergeProgress(
    { level: 4, cleared: '11110', stars: '32100' },
    { level: 20, cleared: '00111', stars: '13020' }
  );
  assert.equal(m.level, 20);
  assert.equal(m.cleared, '11111');
  assert.equal(m.stars, '33120');
});

test('원격이 없거나 깨져 있으면 로컬만으로 병합한다', () => {
  const local = { level: 7, cleared: '111', stars: '321' };
  assert.deepEqual(mergeProgress(local, null), local);
  assert.deepEqual(mergeProgress(local, {}), { level: 7, cleared: '111', stars: '321' });
  assert.deepEqual(mergeProgress(local, { level: 'abc', cleared: 3, stars: null }), local);
});

test('길이가 다르면 긴 쪽에 맞춰 채운다 (레벨이 늘어난 업데이트 뒤에도 안전)', () => {
  const m = mergeProgress({ level: 1, cleared: '11', stars: '33' }, { level: 5, cleared: '00111', stars: '00122' });
  assert.equal(m.cleared, '11111');
  assert.equal(m.stars, '33122');
});

test('별은 3을 넘지 않는다 (오염된 원격 데이터 방어)', () => {
  const m = mergeProgress({ level: 0, cleared: '1', stars: '2' }, { level: 0, cleared: '1', stars: '9' });
  assert.equal(m.stars, '3');
});

// --- Firestore 필드 인코딩 ---

test('Firestore 필드 왕복 변환이 원본을 보존한다', () => {
  const data = { level: 42, cleared: '110101', stars: '321030' };
  assert.deepEqual(fromFirestoreFields(toFirestoreFields(data)), data);
});

test('빈 필드에서도 안전한 기본값이 나온다', () => {
  assert.deepEqual(fromFirestoreFields(undefined), { level: 0, cleared: '', stars: '' });
  assert.deepEqual(fromFirestoreFields({}), { level: 0, cleared: '', stars: '' });
});

// --- JWT 파싱과 REST 호출 ---

const b64url = (obj) =>
  Buffer.from(JSON.stringify(obj)).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const fakeToken = (payload) => `${b64url({ alg: 'none' })}.${b64url(payload)}.sig`;

test('JWT 페이로드에서 프로젝트(aud)와 uid 를 꺼낸다', () => {
  const p = jwtPayload(fakeToken({ aud: 'demo-proj', user_id: 'u1' }));
  assert.equal(p.aud, 'demo-proj');
  assert.equal(p.user_id, 'u1');
});

test('save 는 올바른 문서 주소로 PATCH 하고 토큰을 싣는다', async () => {
  const calls = [];
  const sync = createFirestoreSync({
    getIdToken: async () => fakeToken({ aud: 'demo-proj', user_id: 'u1' }),
    fetchFn: async (url, opts) => {
      calls.push({ url, opts });
      return { ok: true, status: 200 };
    },
  });
  await sync.save({ level: 3, cleared: '111', stars: '333' });

  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    'https://firestore.googleapis.com/v1/projects/demo-proj/databases/(default)/documents/players/u1'
  );
  assert.equal(calls[0].opts.method, 'PATCH');
  assert.match(calls[0].opts.headers.Authorization, /^Bearer /);
  const body = JSON.parse(calls[0].opts.body);
  assert.equal(body.fields.level.integerValue, '3');
  assert.equal(body.fields.cleared.stringValue, '111');
});

test('load 는 404를 "아직 문서 없음(null)"으로 읽는다', async () => {
  const sync = createFirestoreSync({
    getIdToken: async () => fakeToken({ aud: 'p', sub: 'u2' }),
    fetchFn: async () => ({ ok: false, status: 404 }),
  });
  assert.equal(await sync.load(), null);
});

test('load 는 문서 필드를 진행 스냅샷으로 돌려준다', async () => {
  const sync = createFirestoreSync({
    getIdToken: async () => fakeToken({ aud: 'p', user_id: 'u3' }),
    fetchFn: async () => ({
      ok: true,
      status: 200,
      json: async () => ({ fields: toFirestoreFields({ level: 9, cleared: '11', stars: '33' }) }),
    }),
  });
  assert.deepEqual(await sync.load(), { level: 9, cleared: '11', stars: '33' });
});

test('저장 실패(권한 등)는 조용히 삼키지 않고 던진다', async () => {
  const sync = createFirestoreSync({
    getIdToken: async () => fakeToken({ aud: 'p', user_id: 'u' }),
    fetchFn: async () => ({ ok: false, status: 403 }),
  });
  await assert.rejects(() => sync.save({ level: 1, cleared: '1', stars: '1' }), /403/);
});

// --- AuthManager ---
// node 에는 localStorage 가 없어 저장은 조용히 생략된다 (ads.js 와 같은 방어 패턴).
// 영속성 자체는 브라우저 e2e 에서 검증한다.

test('가입 권유는 정확히 한 번, 정해진 레벨에서만 나온다', async () => {
  const auth = new AuthManager({ provider: createFakeAuthProvider() });
  const at = AUTH_CONFIG.promptAfterLevel;

  // init 전(환경 미판정)에는 절대 안 뜬다
  assert.equal(auth.shouldPrompt(at), false);

  await auth.init();
  assert.equal(auth.shouldPrompt(at - 1), false, '다른 레벨에서 떴다');
  assert.equal(auth.shouldPrompt(at), true);

  auth.markPrompted();
  assert.equal(auth.shouldPrompt(at), false, '한 번 보여준 뒤에도 또 떴다');
});

test('provider 가 없으면(순수 웹) 로그인 기능이 통째로 꺼진다', async () => {
  const auth = new AuthManager({ provider: null });
  await auth.init();
  assert.equal(auth.available, false);
  assert.equal(auth.shouldPrompt(AUTH_CONFIG.promptAfterLevel), false);
});

test('이미 로그인한 유저에게는 권유하지 않는다', async () => {
  const auth = new AuthManager({ provider: createFakeAuthProvider() });
  await auth.init();
  await auth.signIn();
  assert.equal(auth.user.email, 'demo@example.com');
  assert.equal(auth.shouldPrompt(AUTH_CONFIG.promptAfterLevel), false);
});

test('sync 는 클라우드와 병합한 스냅샷을 돌려주고, 그 결과를 되민다', async () => {
  const provider = createFakeAuthProvider();
  provider.cloud.data = { level: 12, cleared: '1'.repeat(13), stars: '3'.repeat(13) };
  const auth = new AuthManager({ provider });
  await auth.init();
  await auth.signIn();

  const merged = await auth.sync({ level: 2, cleared: '111', stars: '222' });
  assert.equal(merged.level, 12);
  assert.equal(merged.cleared, '1'.repeat(13));
  assert.equal(merged.stars.slice(0, 3), '333');
  // 병합 결과가 클라우드에도 반영된다
  assert.equal(provider.cloud.data.level, 12);
});

test('클라우드 읽기가 실패해도 sync 는 로컬 병합으로 살아남는다', async () => {
  const provider = createFakeAuthProvider();
  provider.loadProgress = async () => {
    throw new Error('network down');
  };
  const auth = new AuthManager({ provider });
  await auth.init();
  await auth.signIn();
  const merged = await auth.sync({ level: 5, cleared: '11111', stars: '12321' });
  assert.equal(merged.level, 5);
});

test('로그아웃 전에는 push 가 클라우드로 가고, 후에는 가지 않는다', async () => {
  const provider = createFakeAuthProvider();
  const auth = new AuthManager({ provider });
  await auth.init();
  await auth.signIn();

  auth.push({ level: 3, cleared: '111', stars: '333' });
  await new Promise((r) => setTimeout(r, 0));
  assert.equal(provider.cloud.data.level, 3);

  await auth.signOut();
  assert.equal(auth.user, null);
  auth.push({ level: 9, cleared: '1', stars: '1' });
  await new Promise((r) => setTimeout(r, 0));
  assert.equal(provider.cloud.data.level, 3, '로그아웃 뒤에도 push 가 나갔다');
});

test('계정 삭제는 클라우드 진행도 지우고 로그아웃 상태가 된다', async () => {
  const provider = createFakeAuthProvider();
  const auth = new AuthManager({ provider });
  await auth.init();
  await auth.signIn();
  auth.push({ level: 3, cleared: '111', stars: '333' });
  await new Promise((r) => setTimeout(r, 0));

  await auth.deleteAccount();
  assert.equal(auth.user, null);
  assert.equal(provider.cloud.data, null);
});

test('provider 가 로그인만 되고 저장을 지원하지 않으면 sync 는 null (동기화 생략)', async () => {
  const provider = createFakeAuthProvider();
  delete provider.loadProgress;
  delete provider.saveProgress;
  const auth = new AuthManager({ provider });
  await auth.init();
  await auth.signIn();
  assert.equal(await auth.sync({ level: 1, cleared: '1', stars: '1' }), null);
});
