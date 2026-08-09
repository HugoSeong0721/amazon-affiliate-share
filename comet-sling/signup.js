// 이메일 가입 게이트 — 첫 실행 때 한 번만 뜬다.
//
// 두 가지 경로로 이메일을 받는다:
//   1) 직접 입력 → 시작하기
//   2) 구글 로그인 버튼 (SIGNUP_CONFIG.googleClientId 를 채우면 켜진다)
//
// 받은 이메일은 기기에 저장하고, SIGNUP_CONFIG.endpoint(Apps Script 웹앱 URL)가
// 설정돼 있으면 구글 시트로도 보낸다. 전송 실패분은 큐에 쌓았다가 다음 실행 때 재시도한다.
// 설정 방법은 EMAIL-SETUP.md 참고.
//
// 강제 가입은 이탈을 부르므로 "그냥 플레이" 를 반드시 남겨 둔다 — 이메일 몇 개보다
// 플레이어 전부를 잃는 쪽이 훨씬 비싸다.

export const SIGNUP_CONFIG = {
  // 구글 클라우드 콘솔에서 발급한 웹 OAuth 클라이언트 ID (비어 있으면 구글 버튼 숨김)
  googleClientId: '',
  // 이메일이 쌓일 Apps Script 웹앱 URL (비어 있으면 기기 저장만)
  endpoint: '',
};

const SIGNUP_STORE = {
  email: 'cms.email',
  skipped: 'cms.emailSkipped',
  queue: 'cms.emailQueue',
};

function validEmail(v) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v);
}

function loadQueue() {
  try {
    return JSON.parse(localStorage.getItem(SIGNUP_STORE.queue) || '[]');
  } catch {
    return [];
  }
}

function saveQueue(q) {
  try {
    localStorage.setItem(SIGNUP_STORE.queue, JSON.stringify(q.slice(-20)));
  } catch {}
}

// Apps Script는 no-cors 로 쏜다 — 응답은 못 읽지만 도착은 한다.
// 도착 확인이 불가능하므로 큐에서 지우는 건 fetch 가 예외 없이 끝났을 때다.
async function send(entry, config) {
  if (!config.endpoint) return false;
  try {
    await fetch(config.endpoint, {
      method: 'POST',
      mode: 'no-cors',
      headers: { 'Content-Type': 'text/plain' },
      body: JSON.stringify(entry),
    });
    return true;
  } catch {
    return false;
  }
}

async function flushQueue(config) {
  const q = loadQueue();
  if (!q.length || !config.endpoint) return;
  const remain = [];
  for (const entry of q) {
    if (!(await send(entry, config))) remain.push(entry);
  }
  saveQueue(remain);
}

// 랭킹용 점수 제출 — 이메일과 같은 endpoint 로 보낸다 (시트의 scores 탭에 쌓임).
// 신기록일 때만 부르면 시트가 깔끔하다. 실패분은 이메일과 같은 큐로 재시도.
export function submitScore(score, config = SIGNUP_CONFIG) {
  const entry = {
    type: 'score',
    score,
    email: localStorage.getItem(SIGNUP_STORE.email) || '',
    game: 'comet-sling',
    at: new Date().toISOString(),
  };
  send(entry, config).then((ok) => {
    if (!ok && config.endpoint) {
      const q = loadQueue();
      q.push(entry);
      saveQueue(q);
    }
  });
}

function decodeJwtEmail(credential) {
  try {
    const payload = JSON.parse(
      atob(credential.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))
    );
    return payload.email || null;
  } catch {
    return null;
  }
}

// 구글 로그인 버튼 — 클라이언트 ID가 있을 때만 스크립트를 불러와 렌더한다.
// 스크립트 로드에 실패해도 이메일 입력은 그대로 살아 있다.
function initGoogleButton(dom, config, onEmail) {
  if (!config.googleClientId) return;
  const s = document.createElement('script');
  s.src = 'https://accounts.google.com/gsi/client';
  s.async = true;
  s.onload = () => {
    try {
      window.google.accounts.id.initialize({
        client_id: config.googleClientId,
        callback: (resp) => {
          const email = decodeJwtEmail(resp.credential);
          if (email) onEmail(email, 'google');
        },
      });
      window.google.accounts.id.renderButton(dom.googleBtn, {
        theme: 'filled_black',
        size: 'large',
        text: 'continue_with',
        width: 280,
      });
      dom.googleBtn.classList.remove('hidden');
      dom.orDivider.classList.remove('hidden');
    } catch {}
  };
  document.head.appendChild(s);
}

export class SignupGate {
  constructor({ dom, config = SIGNUP_CONFIG, onDone }) {
    this.dom = dom;
    this.config = config;
    this.onDone = onDone || (() => {});

    // 이미 가입했거나 건너뛴 사람에게는 다시 묻지 않는다
    if (localStorage.getItem(SIGNUP_STORE.email) || localStorage.getItem(SIGNUP_STORE.skipped) === '1') {
      this.dom.signup.classList.add('hidden');
      flushQueue(this.config); // 미전송분 재시도
      this.onDone();
      return;
    }

    this.dom.signup.classList.remove('hidden');

    const accept = (email, via) => this._accept(email, via);

    this.dom.emailForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const v = this.dom.emailInput.value.trim();
      if (!validEmail(v)) {
        this.dom.emailInput.classList.add('shake');
        setTimeout(() => this.dom.emailInput.classList.remove('shake'), 400);
        return;
      }
      accept(v, 'form');
    });

    this.dom.skipBtn.addEventListener('click', () => {
      localStorage.setItem(SIGNUP_STORE.skipped, '1');
      this._close();
    });

    initGoogleButton(this.dom, this.config, accept);
  }

  _accept(email, via) {
    localStorage.setItem(SIGNUP_STORE.email, email);
    const entry = { email, via, game: 'comet-sling', at: new Date().toISOString() };
    send(entry, this.config).then((ok) => {
      if (!ok) {
        const q = loadQueue();
        q.push(entry);
        saveQueue(q);
      }
    });
    this._close();
  }

  _close() {
    this.dom.signup.classList.add('hidden');
    this.onDone();
  }
}
