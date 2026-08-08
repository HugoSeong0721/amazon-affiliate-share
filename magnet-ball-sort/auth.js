// 선택적 구글 로그인 — 이메일 수집과 진행 저장.
//
// 원칙: 게임을 절대 막지 않는다. 하이퍼캐주얼에서 첫 화면 가입 강요는 이탈 1순위라,
// 로그인은 언제나 선택이고 혜택(진행 저장)으로만 권한다:
//   - 첫 친구를 구한 직후(레벨 5 클리어) 딱 한 번 팝업 — 애정이 생긴 순간에만
//   - 그 뒤로는 여정 지도 아래 계정 줄에서 언제든 로그인/로그아웃/삭제
//   - 계정 삭제는 구글 플레이 정책상 의무다 (가입을 제공하면 삭제도 제공해야 한다)
//
// provider 는 광고와 같은 교체형 인터페이스다:
//   available(): Promise<boolean>       — 이 환경에서 로그인이 되는가
//   signIn(): Promise<{uid,email,name}> — 계정 선택 시트를 띄운다
//   signOut() / deleteAccount()
//   saveProgress(data) / loadProgress() — 클라우드 진행 저장 (없으면 동기화 생략)
//
// 웹 빌드에는 진짜 provider 가 없다(외부 스크립트 0개 원칙) — 로그인 UI가 통째로
// 숨는다. 실제 수집은 안드로이드 앱에서만 일어나고, ?debug 에서는 가짜 provider 로
// 흐름을 미리 볼 수 있다.

import { mergeProgress, createFirestoreSync } from './cloud.js';

const STORAGE_AUTH = 'mbs.auth';

export const AUTH_CONFIG = {
  // 이 레벨(0부터 셈)을 깬 직후 가입을 권한다 = 레벨 5, 첫 친구 구출 직후
  promptAfterLevel: 4,
};

export class AuthManager {
  constructor({ provider, config = AUTH_CONFIG }) {
    this.provider = provider || null;
    this.config = config;
    // init()이 판정하기 전에는 "안 됨"으로 시작 — UI가 미리 나타나지 않는다
    this.available = false;
    this.onChange = null;

    let saved = {};
    try {
      saved = JSON.parse(localStorage.getItem(STORAGE_AUTH) || '{}');
    } catch {
      saved = {};
    }
    this.user = saved.user || null;
    this.promptShown = !!saved.promptShown;
  }

  _save() {
    try {
      localStorage.setItem(
        STORAGE_AUTH,
        JSON.stringify({ user: this.user, promptShown: this.promptShown })
      );
    } catch {}
  }

  _changed() {
    this.onChange?.(this);
  }

  // 환경 판정은 비동기다 (네이티브 플러그인에 물어봐야 한다). 부트스트랩에서
  // 기다리지 않고 쏘고, 판정이 끝나면 onChange 로 UI가 따라온다.
  async init() {
    if (this.provider) {
      try {
        this.available = await this.provider.available();
      } catch {
        this.available = false;
      }
    }
    // 환경이 사라졌으면(예: Firebase 설정이 빠진 빌드) 유령 세션을 남기지 않는다
    if (!this.available && this.user) {
      this.user = null;
      this._save();
    }
    this._changed();
  }

  shouldPrompt(levelIndex) {
    return (
      this.available &&
      !this.user &&
      !this.promptShown &&
      levelIndex === this.config.promptAfterLevel
    );
  }

  // 팝업은 평생 한 번만. "나중에"를 눌러도 다시 조르지 않는다 — 계정 줄이 남아 있다.
  markPrompted() {
    this.promptShown = true;
    this._save();
  }

  async signIn() {
    const u = await this.provider.signIn();
    this.user = { uid: u.uid || '', email: u.email || '', name: u.name || '' };
    this._save();
    this._changed();
    return this.user;
  }

  async signOut() {
    try {
      await this.provider.signOut();
    } catch {
      // 네트워크가 없어도 로컬에서는 로그아웃되어야 한다
    }
    this.user = null;
    this._save();
    this._changed();
  }

  async deleteAccount() {
    await this.provider.deleteAccount();
    this.user = null;
    this._save();
    this._changed();
  }

  // 로그인 직후 호출: 클라우드와 로컬을 합쳐 더 나아간 쪽으로 맞춘 스냅샷을 돌려준다.
  // 클라우드를 못 읽어도 로컬만으로 병합한다 — 게임이 기다리다 멈추는 일은 없다.
  async sync(localData) {
    if (!this.user || !this.provider?.loadProgress) return null;
    let remote = null;
    try {
      remote = await this.provider.loadProgress();
    } catch {
      remote = null;
    }
    const merged = mergeProgress(localData, remote);
    this.push(merged);
    return merged;
  }

  // 레벨을 깰 때마다 부담 없이 밀어넣는다. 실패는 조용히 넘긴다 — 다음 클리어 때 또 민다.
  push(data) {
    if (!this.user || !this.provider?.saveProgress) return;
    Promise.resolve(this.provider.saveProgress(data)).catch(() => {});
  }
}

// ?debug 용 가짜 provider — 실제 구글 시트 대신 즉시 성공하는 데모 계정.
// cloud 객체를 노출해 e2e 가 "다른 기기의 진행"을 미리 넣어보고 병합을 검증한다.
export function createFakeAuthProvider() {
  const cloud = { data: null };
  return {
    name: 'fake',
    cloud,
    available: async () => true,
    signIn: async () => ({ uid: 'demo-user', email: 'demo@example.com', name: 'Demo Player' }),
    signOut: async () => {},
    deleteAccount: async () => {
      cloud.data = null;
    },
    saveProgress: async (d) => {
      cloud.data = { ...d };
    },
    loadProgress: async () => (cloud.data ? { ...cloud.data } : null),
  };
}

// 안드로이드 앱의 진짜 provider — @capacitor-firebase/authentication 플러그인.
// 네이티브 브리지로만 부르므로 웹 빌드에 Firebase SDK 를 싣지 않는다.
export function createCapacitorFirebaseProvider() {
  const cap = typeof window !== 'undefined' ? window.Capacitor : null;
  if (!cap?.isNativePlatform?.()) return null;

  let plugin = null;
  try {
    plugin = cap.registerPlugin('FirebaseAuthentication');
  } catch {
    return null;
  }
  if (!plugin) return null;

  const store = createFirestoreSync({
    getIdToken: async () => (await plugin.getIdToken()).token,
  });

  return {
    name: 'firebase',
    // Firebase 설정(google-services.json)이 없는 빌드에서는 첫 호출이 던진다 →
    // available=false → 로그인 UI가 숨는다. 설정이 들어오면 코드 변경 없이 켜진다.
    available: async () => {
      try {
        await plugin.getCurrentUser();
        return true;
      } catch {
        return false;
      }
    },
    signIn: async () => {
      const r = await plugin.signInWithGoogle();
      const u = r?.user || {};
      return { uid: u.uid, email: u.email || '', name: u.displayName || '' };
    },
    signOut: () => plugin.signOut(),
    deleteAccount: async () => {
      try {
        await plugin.deleteUser();
      } catch {
        // 세션이 오래되면 "최근 로그인 필요"로 거부된다 — 다시 로그인시키고 재시도
        await plugin.signInWithGoogle();
        await plugin.deleteUser();
      }
    },
    saveProgress: (d) => store.save(d),
    loadProgress: () => store.load(),
  };
}
