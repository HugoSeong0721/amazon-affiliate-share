// 클라우드 진행 저장 — Firestore REST 호출과 진행 병합 규칙.
//
// 네이티브 앱에서 구글 로그인을 하면 이메일은 Firebase Authentication에 자동으로
// 쌓인다(그게 수집의 전부다). 이 파일은 그 위에 얹는 "진행 저장" — 유저가 로그인의
// 대가로 받는 혜택이다. 폰을 바꿔도 레벨과 별이 따라온다.
//
// SDK 없이 REST 를 직접 쓰는 이유: 게임 번들은 외부 스크립트 0개가 원칙이라
// (아티팩트/CSP 제약) Firebase JS SDK 를 실을 수 없다. 문서 주소와 프로젝트 ID는
// 로그인 토큰(JWT)의 aud/user_id 클레임에서 꺼내므로 설정 주입도 필요 없다.
//
// fetch 와 토큰 공급자를 주입받으므로 백엔드 없이도 유닛 테스트로 검증한다.

// 진행 스냅샷 형식은 로컬 저장과 같다: 레벨당 한 글자.
//   { level: 숫자(현재 레벨), cleared: '0101…', stars: '3120…' }

// 두 기기의 진행을 합친다 — 항상 "더 나아간 쪽"을 취하므로 잃는 것이 없다.
export function mergeProgress(local, remote) {
  const a = local || {};
  const b = remote || {};
  const ac = String(a.cleared || '');
  const bc = String(b.cleared || '');
  const as = String(a.stars || '');
  const bs = String(b.stars || '');
  const n = Math.max(ac.length, bc.length, as.length, bs.length);

  let cleared = '';
  let stars = '';
  for (let i = 0; i < n; i++) {
    cleared += ac[i] === '1' || bc[i] === '1' ? '1' : '0';
    const sa = parseInt(as[i] || '0', 10) || 0;
    const sb = parseInt(bs[i] || '0', 10) || 0;
    stars += String(Math.min(Math.max(sa, sb), 3));
  }

  return {
    level: Math.max(Number(a.level) || 0, Number(b.level) || 0),
    cleared,
    stars,
  };
}

// --- Firestore REST 문서 인코딩 ---
// Firestore JSON 은 값마다 타입 래퍼가 붙는다: {integerValue:'3'}, {stringValue:'…'}

export function toFirestoreFields(data) {
  return {
    level: { integerValue: String(Number(data.level) || 0) },
    cleared: { stringValue: String(data.cleared || '') },
    stars: { stringValue: String(data.stars || '') },
  };
}

export function fromFirestoreFields(fields) {
  const f = fields || {};
  return {
    level: Number(f.level?.integerValue) || 0,
    cleared: String(f.cleared?.stringValue || ''),
    stars: String(f.stars?.stringValue || ''),
  };
}

// JWT 페이로드(가운데 조각)를 푼다. 서명 검증은 하지 않는다 —
// 토큰은 방금 플러그인이 준 것이고, 진짜 검증은 Firestore 서버가 한다.
export function jwtPayload(token) {
  const part = String(token || '').split('.')[1] || '';
  const b64 = part.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  const text =
    typeof atob === 'function'
      ? atob(padded)
      : Buffer.from(padded, 'base64').toString('utf8');
  return JSON.parse(text);
}

// 문서는 프로젝트당 유저당 하나: players/{uid}
export function createFirestoreSync({ getIdToken, fetchFn }) {
  const doFetch = fetchFn || ((...a) => fetch(...a));

  async function docUrl() {
    const token = await getIdToken();
    const p = jwtPayload(token);
    const uid = p.user_id || p.sub;
    if (!p.aud || !uid) throw new Error('token missing aud/uid');
    return {
      token,
      url: `https://firestore.googleapis.com/v1/projects/${p.aud}/databases/(default)/documents/players/${uid}`,
    };
  }

  return {
    async save(data) {
      const { token, url } = await docUrl();
      const res = await doFetch(url, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ fields: toFirestoreFields(data) }),
      });
      if (!res.ok) throw new Error(`progress save failed: ${res.status}`);
    },

    async load() {
      const { token, url } = await docUrl();
      const res = await doFetch(url, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.status === 404) return null; // 첫 로그인 — 아직 문서가 없다
      if (!res.ok) throw new Error(`progress load failed: ${res.status}`);
      const body = await res.json();
      return fromFirestoreFields(body.fields);
    },
  };
}
