// 전면 광고(인터스티셜) 자리와 노출 빈도 관리.
//
// 광고 네트워크는 갈아끼울 수 있게 provider 로 분리했다. 기본값은 자리만 보여주는
// 플레이스홀더고, 실제 SDK를 붙일 때는 provider 하나만 바꾸면 된다 (README 참고).
//
// 빈도 규칙이 이 파일의 핵심이다. 광고는 수익보다 리텐션을 더 빨리 망가뜨릴 수 있어서
// "언제 안 띄울지"가 "언제 띄울지"보다 중요하다:
//   - 초반 몇 판은 무조건 안 띄운다 (재미를 느끼기 전에 끊으면 그대로 이탈한다)
//   - 퍼즐 도중에는 절대 안 띄운다. 레벨을 깬 뒤 "다음 레벨"을 누를 때만 띄운다
//   - 다시하기(재도전)에는 안 띄운다. 재도전에 벌을 주면 아무도 안 한다
//   - 레벨 수 조건과 시간 간격을 함께 본다 (빨리 깨는 사람에게 연속으로 뜨지 않게)

const STORAGE_AD = 'mbs.ads';

export const AD_CONFIG = {
  // 이 판수를 깨기 전에는 광고를 띄우지 않는다
  freeLevels: 3,
  // 그 뒤로는 이 판수마다
  everyNLevels: 2,
  // 아무리 빨리 깨도 이 시간(초) 안에는 두 번 띄우지 않는다
  minSecondsBetween: 45,
  // 닫기 버튼이 열리기까지의 시간(초). 실제 전면 광고와 비슷한 호흡을 준다
  countdownSeconds: 5,
};

// 광고 자리만 보여주는 기본 제공자. 실제 광고를 넣지 않아도 흐름과 호흡을 확인할 수 있다.
// config 는 값이 아니라 객체째로 받는다 — 매니저와 같은 객체를 공유해야 설정이 엇갈리지 않는다.
export function createPlaceholderProvider({ root, closeBtn, config = AD_CONFIG }) {
  return {
    name: 'placeholder',
    isReady: () => true,
    show() {
      return new Promise((resolve) => {
        let left = config.countdownSeconds;
        root.classList.remove('hidden');
        closeBtn.disabled = true;
        closeBtn.textContent = String(left);

        const tick = setInterval(() => {
          left -= 1;
          if (left > 0) {
            closeBtn.textContent = String(left);
            return;
          }
          clearInterval(tick);
          closeBtn.disabled = false;
          closeBtn.textContent = '✕';
          closeBtn.setAttribute('aria-label', 'Close ad');
        }, 1000);

        const done = () => {
          clearInterval(tick);
          closeBtn.removeEventListener('click', done);
          root.classList.add('hidden');
          resolve();
        };
        closeBtn.addEventListener('click', done);
      });
    },
  };
}

export class AdManager {
  constructor({ provider, config = AD_CONFIG, enabled = true }) {
    this.provider = provider;
    this.config = config;
    this.enabled = enabled;
    this.showing = false;

    let saved = {};
    try {
      saved = JSON.parse(localStorage.getItem(STORAGE_AD) || '{}');
    } catch {
      saved = {};
    }
    this.clearedTotal = Number(saved.clearedTotal) || 0;
    this.clearedSinceAd = Number(saved.clearedSinceAd) || 0;
    // 마지막 광고 시각은 저장하지 않는다 — 앱을 다시 열었을 때
    // "너무 이르다"는 이유로 건너뛰는 게 더 이상하다.
    this.lastShownAt = 0;
  }

  _save() {
    try {
      localStorage.setItem(
        STORAGE_AD,
        JSON.stringify({ clearedTotal: this.clearedTotal, clearedSinceAd: this.clearedSinceAd })
      );
    } catch {}
  }

  // 레벨을 하나 깼다. 광고를 띄울지는 여기서 세고, 실제 노출은 maybeShow에서 한다.
  noteLevelCleared() {
    this.clearedTotal += 1;
    this.clearedSinceAd += 1;
    this._save();
  }

  shouldShow(now = Date.now()) {
    if (!this.enabled || this.showing) return false;
    if (this.clearedTotal <= this.config.freeLevels) return false;
    if (this.clearedSinceAd < this.config.everyNLevels) return false;
    if (this.lastShownAt && now - this.lastShownAt < this.config.minSecondsBetween * 1000) {
      return false;
    }
    return this.provider.isReady();
  }

  // 조건이 맞으면 광고를 띄우고, 닫힐 때까지 기다린다. 조건이 안 맞으면 즉시 넘어간다.
  async maybeShow(now = Date.now()) {
    if (!this.shouldShow(now)) return false;
    this.showing = true;
    try {
      await this.provider.show();
    } catch {
      // 광고를 못 띄워도 게임 흐름은 멈추지 않는다
    }
    this.showing = false;
    this.clearedSinceAd = 0;
    this.lastShownAt = Date.now();
    this._save();
    return true;
  }
}
