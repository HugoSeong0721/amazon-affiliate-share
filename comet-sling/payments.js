// 인앱 결제 자리 — ads.js 와 같은 철학: 제공자(provider)만 갈아끼우면 된다.
//
// 기본 제공자는 "TEST MODE" 라벨이 붙은 데모 결제 시트다. 실제 과금은 없고,
// 결제 흐름(시트가 올라오고 → 처리 중 → 완료)의 호흡만 그대로 체험할 수 있다.
// 실제 연동 지점:
//   - 앱(Capacitor): Google Play Billing / Apple StoreKit 플러그인으로 purchase() 구현
//   - 웹: Stripe Checkout 등으로 교체
// 어느 쪽이든 purchase(sku)가 Promise<boolean>(구매 성공 여부)을 지키면 게임 코드는 그대로다.

export const SKUS = {
  rescue: { id: 'comet.rescue', title: '☄️ Comet Rescue', price: '$0.99' },
};

export function createDemoPayProvider({ root, titleEl, priceEl, payBtn, cancelBtn }) {
  return {
    name: 'demo',
    // sku 를 받아 데모 결제 시트를 띄운다. 성공 시 true, 취소 시 false.
    purchase(sku) {
      return new Promise((resolve) => {
        titleEl.textContent = sku.title;
        priceEl.textContent = sku.price;
        payBtn.disabled = false;
        payBtn.textContent = `Pay ${sku.price}`;
        root.classList.remove('hidden');

        const cleanup = (ok) => {
          payBtn.removeEventListener('click', onPay);
          cancelBtn.removeEventListener('click', onCancel);
          root.classList.add('hidden');
          resolve(ok);
        };
        const onCancel = () => cleanup(false);
        const onPay = () => {
          payBtn.disabled = true;
          payBtn.textContent = 'Processing…';
          // 실제 결제망 왕복과 비슷한 호흡
          setTimeout(() => {
            payBtn.textContent = '✓ Paid';
            setTimeout(() => cleanup(true), 450);
          }, 1100);
        };
        payBtn.addEventListener('click', onPay);
        cancelBtn.addEventListener('click', onCancel);
      });
    },
  };
}
