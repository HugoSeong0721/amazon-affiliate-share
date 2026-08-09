// 랭킹 — 이메일 수집과 같은 원칙: 서버 없이 시작하고, 주소 하나 붙이면 전역이 된다.
//
//   - LEADERBOARD_CONFIG.url 이 비어 있으면: 이 기기의 최고 기록만 보여준다
//   - url 에 Apps Script 웹앱 주소를 넣으면: 전 세계 TOP 20 이 뜬다 (README 스니펫 참고)
//
// 통신은 두 가지뿐이다:
//   제출: POST no-cors JSON {type:'score', pid, name, score, game} — 신기록일 때만
//   조회: JSONP GET ?type=top&callback=… — Apps Script 는 CORS 헤더를 못 다니 <script> 로 받는다
//
// pid 는 기기당 무작위 ID — 서버가 사람당 최고 기록 하나만 남기는 데 쓴다.

export const LEADERBOARD_CONFIG = {
  // Apps Script 웹앱 URL (이메일 수집과 같은 배포를 함께 쓸 수 있다). 비우면 로컬 전용.
  url: '',
  topN: 20,
  timeoutMs: 8000,
};

const STORAGE_PID = 'sky.pid';
const STORAGE_NAME = 'sky.name';
const STORAGE_CACHE = 'sky.lbCache';

// ----- 순수 헬퍼 (테스트 대상) -----

// 표시 이름: 가입 이메일의 @ 앞부분 → 없으면 저장된 이름 → 없으면 Player###
export function displayName(user, stored, rand = Math.random) {
  const fromEmail = user && user.email ? String(user.email).split('@')[0] : '';
  const name = (fromEmail || String(stored || '')).trim();
  if (name) return name.slice(0, 14);
  return `Player${String(Math.floor(rand() * 900) + 100)}`;
}

// 서버 응답을 신뢰하지 않는다 — 형식이 맞는 행만, 점수순으로, topN 개만
export function normalizeTop(data, topN = LEADERBOARD_CONFIG.topN) {
  if (!Array.isArray(data)) return [];
  return data
    .filter((r) => r && typeof r.name === 'string' && Number.isFinite(Number(r.score)))
    .map((r) => ({ name: String(r.name).slice(0, 14), score: Math.max(0, Math.floor(Number(r.score))) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topN);
}

// 내 점수가 목록 몇 위인지 (1부터). 목록 밖이면 null.
export function myRank(top, score) {
  if (!Number.isFinite(score) || score <= 0) return null;
  const idx = top.findIndex((r) => score >= r.score);
  if (idx === -1) return top.length < LEADERBOARD_CONFIG.topN ? top.length + 1 : null;
  return idx + 1;
}

// ----- 매니저 -----

export class Leaderboard {
  constructor({ config = LEADERBOARD_CONFIG, getUser } = {}) {
    this.config = config;
    this.getUser = getUser || (() => null);

    let pid = localStorage.getItem(STORAGE_PID);
    if (!pid) {
      pid = `p${Math.floor(Math.random() * 1e9).toString(36)}${Date.now().toString(36)}`;
      try {
        localStorage.setItem(STORAGE_PID, pid);
      } catch {}
    }
    this.pid = pid;
  }

  get online() {
    return !!this.config.url;
  }

  get name() {
    const n = displayName(this.getUser(), localStorage.getItem(STORAGE_NAME));
    try {
      localStorage.setItem(STORAGE_NAME, n);
    } catch {}
    return n;
  }

  cachedTop() {
    try {
      return normalizeTop(JSON.parse(localStorage.getItem(STORAGE_CACHE) || '[]'), this.config.topN);
    } catch {
      return [];
    }
  }

  // 신기록을 서버에 알린다 — 실패해도 게임은 모른 척 (다음 신기록 때 또 시도)
  async submit(score) {
    if (!this.online || !Number.isFinite(score) || score <= 0) return false;
    try {
      await fetch(this.config.url, {
        method: 'POST',
        mode: 'no-cors',
        headers: { 'Content-Type': 'text/plain' },
        body: JSON.stringify({ type: 'score', pid: this.pid, name: this.name, score: Math.floor(score), game: 'sky-stack' }),
      });
      return true;
    } catch {
      return false;
    }
  }

  // TOP N 을 JSONP 로 받아온다. 성공하면 캐시에 남긴다.
  fetchTop() {
    if (!this.online) return Promise.resolve(this.cachedTop());
    return new Promise((resolve) => {
      const cb = `__skyLb${Math.floor(Math.random() * 1e6)}`;
      const script = document.createElement('script');
      let done = false;
      const finish = (data) => {
        if (done) return;
        done = true;
        delete window[cb];
        script.remove();
        clearTimeout(timer);
        const top = normalizeTop(data, this.config.topN);
        if (Array.isArray(data)) {
          try {
            localStorage.setItem(STORAGE_CACHE, JSON.stringify(top));
          } catch {}
        }
        resolve(top.length || !Array.isArray(data) ? top : this.cachedTop());
      };
      const timer = setTimeout(() => finish(null), this.config.timeoutMs);
      window[cb] = (data) => finish(data);
      script.onerror = () => finish(null);
      const sep = this.config.url.includes('?') ? '&' : '?';
      script.src = `${this.config.url}${sep}type=top&limit=${this.config.topN}&callback=${cb}`;
      document.head.appendChild(script);
    }).then((top) => (top.length ? top : this.cachedTop()));
  }
}
