// 전면 광고 자리와 노출 빈도 관리 — 형제 게임들과 같은 뼈대, 다른 단위.
//
// 이 게임의 단위는 '런(한 판)'이다. 규칙:
//   - 처음 몇 런은 무조건 무광고 (긴장의 맛을 느끼기 전에 끊으면 그대로 이탈한다)
//   - 런 도중에는 절대 안 뜬다. 탑이 무너진 뒤의 전환 순간에만 뜬다
//   - 몇 초 만에 끝난 런 뒤에는 안 뜬다 (연속 즉사에 광고까지 겹치면 최악의 경험이다)
//   - 런 수 조건과 시간 간격을 함께 본다

const STORAGE_AD = 'sky.ads';

export const AD_CONFIG = {
  // 이 횟수만큼 런을 마치기 전에는 광고를 띄우지 않는다
  freeRuns: 3,
  // 그 뒤로는 이 런 수마다
  everyNRuns: 3,
  // 아무리 자주 끝나도 이 시간(초) 안에는 두 번 띄우지 않는다
  minSecondsBetween: 90,
  // 이 시간(초)보다 짧았던 런 뒤에는 띄우지 않는다
  minRunSeconds: 8,
  // 닫기 버튼이 열리기까지의 시간(초)
  countdownSeconds: 5,
};

// 광고 자리만 보여주는 기본 제공자 — 실제 SDK를 붙일 때 이 객체만 갈아끼운다.
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
    this.runsTotal = Number(saved.runsTotal) || 0;
    this.runsSinceAd = Number(saved.runsSinceAd) || 0;
    // 마지막 광고 시각은 저장하지 않는다 — 앱을 다시 열었을 때
    // "너무 이르다"는 이유로 건너뛰는 게 더 이상하다.
    this.lastShownAt = 0;
  }

  _save() {
    try {
      localStorage.setItem(
        STORAGE_AD,
        JSON.stringify({ runsTotal: this.runsTotal, runsSinceAd: this.runsSinceAd })
      );
    } catch {}
  }

  // 런이 하나 끝났다. 노출 여부 판단은 maybeShow에서.
  noteRunEnded() {
    this.runsTotal += 1;
    this.runsSinceAd += 1;
    this._save();
  }

  shouldShow(runSeconds, now = Date.now()) {
    if (!this.enabled || this.showing) return false;
    if (this.runsTotal <= this.config.freeRuns) return false;
    if (this.runsSinceAd < this.config.everyNRuns) return false;
    if (runSeconds < this.config.minRunSeconds) return false;
    if (this.lastShownAt && now - this.lastShownAt < this.config.minSecondsBetween * 1000) {
      return false;
    }
    return this.provider.isReady();
  }

  // 조건이 맞으면 광고를 띄우고 닫힐 때까지 기다린다. 아니면 즉시 넘어간다.
  async maybeShow(runSeconds, now = Date.now()) {
    if (!this.shouldShow(runSeconds, now)) return false;
    this.showing = true;
    try {
      await this.provider.show();
    } catch {
      // 광고를 못 띄워도 게임 흐름은 멈추지 않는다
    }
    this.showing = false;
    this.runsSinceAd = 0;
    this.lastShownAt = Date.now();
    this._save();
    return true;
  }
}
