// 친구 랭킹 — 서버 없이, 도전장 링크로 전염되는 순위표.
//
// 원리: 공유 링크(?beat=점수&by=이름)를 열 때마다 그 친구의 기록이 이 기기에
// 저장된다. 링크를 주고받는 사이끼리는 자연스럽게 서로의 최고 기록이 쌓이고,
// 그걸 정렬하면 친구 랭킹판이다. 서버도 계정도 필요 없다.
//
// 한계(정직하게): 친구 기록은 링크를 받은 시점의 것이다 — 실시간 갱신이 아니다.
// 실시간 전체 랭킹은 EMAIL-SETUP.md 의 시트 연동(endpoint)이 붙으면 그 위에 올린다.

const KEY_NAME = 'cms.name';
const KEY_FRIENDS = 'cms.friends';
const MAX_FRIENDS = 50;

// 내 이름 — 처음엔 부르기 쉬운 임의 콜사인을 주고, 랭킹판에서 바꿀 수 있다
export function myName() {
  let n = localStorage.getItem(KEY_NAME);
  if (!n) {
    n = 'Comet-' + (100 + Math.floor(Math.random() * 900));
    localStorage.setItem(KEY_NAME, n);
  }
  return n;
}

export function setMyName(name) {
  const n = String(name).trim().slice(0, 14);
  if (!n) return myName();
  localStorage.setItem(KEY_NAME, n);
  return n;
}

export function friends() {
  try {
    const list = JSON.parse(localStorage.getItem(KEY_FRIENDS) || '[]');
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

function saveFriends(list) {
  try {
    localStorage.setItem(KEY_FRIENDS, JSON.stringify(list.slice(0, MAX_FRIENDS)));
  } catch {}
}

// 도전장을 열면 그 친구의 기록을 저장한다 — 이름당 최고 기록만 남긴다
export function recordFriend(name, score) {
  const n = String(name || '').trim().slice(0, 14);
  const s = Math.floor(Number(score));
  if (!n || !(s > 0)) return;
  if (n === myName()) return; // 내 링크를 내가 열었을 때
  const list = friends();
  const at = new Date().toISOString();
  const existing = list.find((f) => f.name === n);
  if (existing) {
    if (s > existing.score) {
      existing.score = s;
      existing.at = at;
    }
  } else {
    list.push({ name: n, score: s, at });
  }
  // 점수 내림차순으로 저장해 두면 잘릴 때 낮은 기록부터 밀려난다
  list.sort((a, b) => b.score - a.score);
  saveFriends(list);
}

// 랭킹판 행 — 나 + 친구들, 점수 내림차순. 내 행에는 me 표시.
export function board(myBest) {
  const me = { name: myName(), score: Math.max(0, Math.floor(myBest) || 0), me: true };
  const rows = friends()
    .filter((f) => f.name !== me.name)
    .map((f) => ({ name: f.name, score: f.score, me: false }));
  rows.push(me);
  rows.sort((a, b) => b.score - a.score || (a.me ? -1 : 1));
  return rows;
}
