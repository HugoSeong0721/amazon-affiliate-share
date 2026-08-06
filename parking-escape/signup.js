// 이메일 수집 — 구글 로그인(Google Identity Services)으로 탭 한 번에 가입.
//
// 정적 사이트라 서버가 없으므로 두 가지를 밖에서 빌려 쓴다:
//   1) 구글 OAuth 클라이언트 ID — 로그인 버튼/원탭이 이메일이 담긴 토큰을 준다
//   2) 수집 엔드포인트 — 받은 이메일을 구글 시트에 쌓는 Apps Script 웹앱
//      (tools/collect-emails.gs 에 코드와 배포 순서가 있다)
//
// 두 값이 비어 있으면 패널 자체가 뜨지 않는다 — 설정 전에도 게임은 멀쩡히 돌아간다.
// ?signup 을 붙이면 설정 없이도 패널 UI를 미리 볼 수 있다.
//
// UX 원칙: 가입은 문이 아니라 초대다. 건너뛰기가 항상 보이고, 거절하면
// 하루 동안 다시 묻지 않는다. 하이퍼캐주얼에서 강제 가입 게이트는 이탈 1순위다.

export const SIGNUP_CONFIG = {
  // console.cloud.google.com → API 및 서비스 → 사용자 인증 정보 → OAuth 클라이언트 ID(웹).
  // 승인된 자바스크립트 원본에 게임이 열리는 주소(https://hugoseong0721.github.io 등)를 등록한다.
  googleClientId: '',
  // Apps Script 웹앱 배포 URL (README와 tools/collect-emails.gs 참고)
  collectEndpoint: '',
  // 건너뛴 사람에게 다시 물을 때까지의 시간
  askAgainHours: 24,
};

const KEY_EMAIL = 'pke.signup.email';
const KEY_ASKED = 'pke.signup.askedAt';

// JWT의 payload를 읽는다. 서명 검증은 하지 않는다 — 여기서 얻는 건
// "메일링 리스트에 넣을 주소"뿐이고, 권한을 주는 게 아니기 때문이다.
function decodeJwtPayload(token) {
  try {
    const b64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(b64));
  } catch {
    return null;
  }
}

export class Signup {
  // dom: { root, googleSlot, skip }
  constructor({ dom, config = SIGNUP_CONFIG, force = false }) {
    this.dom = dom;
    this.config = config;
    this.force = force; // ?signup — 설정 없이 UI 미리보기
    this.dom.skip.addEventListener('click', () => this.dismiss());
    this.dom.root.addEventListener('click', (e) => {
      if (e.target === this.dom.root) this.dismiss();
    });
  }

  get email() {
    return localStorage.getItem(KEY_EMAIL) || null;
  }

  get configured() {
    return Boolean(this.config.googleClientId && this.config.collectEndpoint);
  }

  shouldAsk(now = Date.now()) {
    if (this.force) return true;
    if (!this.configured || this.email) return false;
    const asked = Number(localStorage.getItem(KEY_ASKED)) || 0;
    return now - asked > this.config.askAgainHours * 3600 * 1000;
  }

  maybeShow() {
    if (!this.shouldAsk()) return false;
    localStorage.setItem(KEY_ASKED, String(Date.now()));
    this.dom.root.classList.remove('hidden');
    this._mountGoogle();
    return true;
  }

  dismiss() {
    this.dom.root.classList.add('hidden');
  }

  // GIS 스크립트를 그때그때 불러온다. 광고 차단기 등으로 못 불러오면
  // 조용히 안내 문구만 남긴다 — 가입 패널이 게임을 인질로 잡으면 안 된다.
  _mountGoogle() {
    if (!this.config.googleClientId) {
      this.dom.googleSlot.textContent = 'Google sign-in not configured yet';
      this.dom.googleSlot.classList.add('su-placeholder');
      return;
    }
    const boot = () => {
      try {
        window.google.accounts.id.initialize({
          client_id: this.config.googleClientId,
          callback: (res) => this._onCredential(res.credential),
        });
        window.google.accounts.id.renderButton(this.dom.googleSlot, {
          theme: 'filled_blue',
          size: 'large',
          shape: 'pill',
          text: 'continue_with',
          width: 260,
        });
        // 원탭 — 화면 구석에 "내 이메일" 칩이 떠서 한 번 누르면 끝난다
        window.google.accounts.id.prompt();
      } catch {
        this.dom.googleSlot.textContent = 'Google sign-in unavailable';
        this.dom.googleSlot.classList.add('su-placeholder');
      }
    };
    if (window.google?.accounts?.id) {
      boot();
      return;
    }
    const s = document.createElement('script');
    s.src = 'https://accounts.google.com/gsi/client';
    s.async = true;
    s.onload = boot;
    s.onerror = () => {
      this.dom.googleSlot.textContent = 'Google sign-in unavailable';
      this.dom.googleSlot.classList.add('su-placeholder');
    };
    document.head.appendChild(s);
  }

  _onCredential(credential) {
    const p = decodeJwtPayload(credential);
    if (!p?.email) return;
    localStorage.setItem(KEY_EMAIL, p.email);
    this._send({ email: p.email, name: p.name || '', sub: p.sub || '' });
    this.dismiss();
  }

  // Apps Script는 정적 사이트에서 CORS 응답을 안 주므로 no-cors로 보낸다.
  // 응답은 못 읽지만 기록은 된다. 실패해도 게임 흐름은 절대 막지 않는다.
  _send(data) {
    if (!this.config.collectEndpoint) return;
    try {
      fetch(this.config.collectEndpoint, {
        method: 'POST',
        mode: 'no-cors',
        headers: { 'Content-Type': 'text/plain' },
        body: JSON.stringify({ ...data, game: 'parking-escape', ts: new Date().toISOString() }),
      }).catch(() => {});
    } catch {}
  }

  // 디버그/테스트용 — 실제 구글 팝업 없이 가입 흐름을 재현한다
  mockSignup(email) {
    localStorage.setItem(KEY_EMAIL, email);
    this._send({ email, name: 'mock', sub: 'mock' });
    this.dismiss();
  }
}
