// 가입 게이트 — 게임 시작 전에 이메일을 모은다. 서버 없이도 굴러가는 3단 구조:
//
//   1) 이메일 직접 입력 — 항상 켜져 있다. 어디서든(file:// 포함) 동작한다
//   2) Google 원탭 버튼 — SIGNUP_CONFIG.googleClientId를 넣으면 켜진다.
//      구글이 검증한 이메일이 토큰으로 오므로 오타·가짜 메일이 없다
//   3) 수집 — SIGNUP_CONFIG.collectUrl(Apps Script → 구글 시트)로 보낸다.
//      아직 URL이 없거나 오프라인이면 로컬 큐에 쌓아 두고 다음 실행 때 재시도한다
//
// 게이트는 건너뛸 수 있다(play as guest) — 가입 벽에 첫 손맛을 막히게 하지 않는다.
// 건너뛴 사람에게는 HUD에 ✉️ 버튼이 남아 언제든 다시 가입할 수 있다.

export const SIGNUP_CONFIG = {
  // Google Cloud Console → APIs & Services → Credentials → OAuth client ID (Web)
  // 예: '1234567890-abc.apps.googleusercontent.com'  (비우면 Google 버튼이 숨는다)
  googleClientId: '',
  // 이메일을 받을 곳. 두 가지 중 하나 (비우면 로컬 큐에만 쌓인다):
  //  A) 구글 폼 (가장 쉬움, 스크립트·배포 불필요): 폼의 …/formResponse URL을 넣고
  //     아래 formEntry에 이메일 질문의 필드 이름(entry.123456789)을 넣는다
  //  B) Apps Script 웹앱 URL (README의 스니펫 참고): formEntry는 비워 둔다
  collectUrl: '',
  formEntry: '',
};

const STORAGE_USER = 'tdv.user';
const STORAGE_QUEUE = 'tdv.signupQueue';
const GIS_SRC = 'https://accounts.google.com/gsi/client';

// ----- 순수 헬퍼 (테스트 대상) -----

export function validateEmail(s) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(s || '').trim());
}

// Google ID 토큰(JWT)의 payload를 읽는다 — 서명 검증은 하지 않는다.
// 여기서는 인증이 아니라 이메일 수집이 목적이라 payload의 email만 쓰면 충분하다.
export function decodeJwtPayload(jwt) {
  try {
    const part = String(jwt).split('.')[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
    const bin = atob(pad);
    const json = decodeURIComponent(
      Array.from(bin, (c) => '%' + c.charCodeAt(0).toString(16).padStart(2, '0')).join('')
    );
    return JSON.parse(json);
  } catch {
    return null;
  }
}

export function makeRecord(email, via, dayKey) {
  return { game: 'torch-dive', email: String(email).trim().toLowerCase(), via, day: dayKey, at: new Date().toISOString() };
}

// 수집 요청의 본문을 만든다 — 구글 폼이면 urlencoded, Apps Script면 JSON.
// 둘 다 CORS preflight가 없는 '단순 요청'이라 no-cors로 어디서든 보내진다.
export function buildCollectRequest(record, config) {
  if (config.formEntry) {
    return {
      contentType: 'application/x-www-form-urlencoded',
      body: new URLSearchParams({ [config.formEntry]: record.email }).toString(),
    };
  }
  return { contentType: 'text/plain', body: JSON.stringify(record) };
}

// ----- 게이트 -----

export class Signup {
  constructor({ dom, sound, dayKey, config = SIGNUP_CONFIG, onDone }) {
    this.dom = dom;
    this.sound = sound;
    this.dayKey = dayKey;
    this.config = config;
    this.onDone = onDone;
    this._gisLoaded = false;

    dom.emailForm.addEventListener('submit', (e) => {
      e.preventDefault();
      this._joinWithEmail();
    });
    dom.btnSkip.addEventListener('click', () => this.skip());
    dom.btnSignup.addEventListener('click', (e) => {
      e.stopPropagation();
      this.show();
    });
  }

  get user() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_USER) || 'null');
    } catch {
      return null;
    }
  }

  _saveUser(u) {
    try {
      localStorage.setItem(STORAGE_USER, JSON.stringify(u));
    } catch {}
  }

  // 아직 가입도 거절도 안 했으면 게이트를 보여준다
  needsGate() {
    return !this.user;
  }

  show() {
    this.dom.gate.classList.remove('hidden');
    this.dom.emailInput.setCustomValidity('');
    this._mountGoogleButton();
    this._updateBadge();
  }

  hide() {
    this.dom.gate.classList.add('hidden');
    this._updateBadge();
    this.onDone?.(this.user);
  }

  // 게스트로 계속 — 강요하지 않는다. HUD의 ✉️로 언제든 돌아올 수 있다
  skip() {
    if (!this.user) this._saveUser({ guest: true });
    this.sound?.ui();
    this.hide();
  }

  _updateBadge() {
    const u = this.user;
    this.dom.btnSignup.classList.toggle('hidden', !!(u && u.email));
  }

  _joinWithEmail() {
    const email = this.dom.emailInput.value;
    if (!validateEmail(email)) {
      this.dom.emailInput.setCustomValidity('Please enter a valid email');
      this.dom.emailInput.reportValidity();
      return;
    }
    this._finish(email, 'email');
  }

  _finish(email, via) {
    this._saveUser({ email: String(email).trim().toLowerCase(), via });
    this._enqueue(makeRecord(email, via, this.dayKey));
    this.flushQueue();
    this.sound?.bank();
    this.hide();
  }

  // ----- Google Identity Services (설정했을 때만) -----

  async _mountGoogleButton() {
    const { googleClientId } = this.config;
    const slot = this.dom.googleBtn;
    const or = this.dom.gateOr;
    if (!googleClientId) {
      slot.classList.add('hidden');
      or.classList.add('hidden');
      return;
    }
    slot.classList.remove('hidden');
    or.classList.remove('hidden');
    try {
      await this._loadGis();
      window.google.accounts.id.initialize({
        client_id: googleClientId,
        callback: (resp) => {
          const payload = decodeJwtPayload(resp && resp.credential);
          if (payload && payload.email) this._finish(payload.email, 'google');
        },
      });
      slot.replaceChildren();
      window.google.accounts.id.renderButton(slot, {
        theme: 'filled_black',
        size: 'large',
        shape: 'pill',
        text: 'continue_with',
        width: 260,
      });
    } catch {
      // GIS를 못 불러오는 환경(오프라인, file://, 웹뷰) — 이메일 폼만으로 계속
      slot.classList.add('hidden');
      or.classList.add('hidden');
    }
  }

  _loadGis() {
    if (this._gisLoaded && window.google?.accounts?.id) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = GIS_SRC;
      s.async = true;
      s.onload = () => {
        this._gisLoaded = true;
        resolve();
      };
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  // ----- 수집 큐 -----

  _queue() {
    try {
      const q = JSON.parse(localStorage.getItem(STORAGE_QUEUE) || '[]');
      return Array.isArray(q) ? q : [];
    } catch {
      return [];
    }
  }

  _setQueue(q) {
    try {
      localStorage.setItem(STORAGE_QUEUE, JSON.stringify(q));
    } catch {}
  }

  _enqueue(record) {
    const q = this._queue();
    q.push(record);
    this._setQueue(q);
  }

  // 쌓인 기록을 시트로 보낸다. 성공한 것만 큐에서 뺀다 (앱을 켤 때마다 재시도)
  async flushQueue() {
    const { collectUrl } = this.config;
    if (!collectUrl) return;
    const q = this._queue();
    if (!q.length) return;
    const remaining = [];
    for (const record of q) {
      try {
        const { contentType, body } = buildCollectRequest(record, this.config);
        await fetch(collectUrl, {
          method: 'POST',
          mode: 'no-cors',
          headers: { 'Content-Type': contentType },
          body,
        });
      } catch {
        remaining.push(record);
      }
    }
    this._setQueue(remaining);
  }
}
