// 전면 광고 자리와 노출 빈도 관리 — 형제 게임들과 같은 뼈대, 다른 단위.
//
// 이 게임의 단위는 '다이브'다. 규칙:
//   - 처음 몇 다이브는 무조건 무광고 (긴장의 맛을 느끼기 전에 끊으면 그대로 이탈한다)
//   - 다이브 도중에는 절대 안 뜬다. 죽거나 챙겨 나온 뒤의 전환 순간에만 뜬다
//   - 몇 초 만에 끝난 다이브 뒤에는 안 뜬다 (2층 즉사에 광고까지 겹치면 최악이다)
//   - 하루 3다이브 구조라 실전 다이브 사이에는 거의 안 뜨고, 자연히 무료 다이브 구간에 몰린다

const STORAGE_AD = 'tdv.ads';

export const AD_CONFIG = {
  // 이 횟수만큼 다이브를 마치기 전에는 광고를 띄우지 않는다
  freeDives: 5,
  // 그 뒤로는 이 다이브 수마다
  everyNDives: 3,
  // 아무리 자주 끝나도 이 시간(초) 안에는 두 번 띄우지 않는다
  minSecondsBetween: 90,
  // 이 시간(초)보다 짧았던 다이브 뒤에는 띄우지 않는다
  minDiveSeconds: 12,
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
    this.divesTotal = Number(saved.divesTotal) || 0;
    this.divesSinceAd = Number(saved.divesSinceAd) || 0;
    // 마지막 광고 시각은 저장하지 않는다 — 앱을 다시 열었을 때
    // "너무 이르다"는 이유로 건너뛰는 게 더 이상하다.
    this.lastShownAt = 0;
  }

  _save() {
    try {
      localStorage.setItem(
        STORAGE_AD,
        JSON.stringify({ divesTotal: this.divesTotal, divesSinceAd: this.divesSinceAd })
      );
    } catch {}
  }

  // 다이브가 하나 끝났다. 노출 여부 판단은 maybeShow에서.
  noteDiveEnded() {
    this.divesTotal += 1;
    this.divesSinceAd += 1;
    this._save();
  }

  shouldShow(diveSeconds, now = Date.now()) {
    if (!this.enabled || this.showing) return false;
    if (this.divesTotal <= this.config.freeDives) return false;
    if (this.divesSinceAd < this.config.everyNDives) return false;
    if (diveSeconds < this.config.minDiveSeconds) return false;
    if (this.lastShownAt && now - this.lastShownAt < this.config.minSecondsBetween * 1000) {
      return false;
    }
    return this.provider.isReady();
  }

  // 조건이 맞으면 광고를 띄우고 닫힐 때까지 기다린다. 아니면 즉시 넘어간다.
  async maybeShow(diveSeconds, now = Date.now()) {
    if (!this.shouldShow(diveSeconds, now)) return false;
    this.showing = true;
    try {
      await this.provider.show();
    } catch {
      // 광고를 못 띄워도 게임 흐름은 멈추지 않는다
    }
    this.showing = false;
    this.divesSinceAd = 0;
    this.lastShownAt = Date.now();
    this._save();
    return true;
  }
}
