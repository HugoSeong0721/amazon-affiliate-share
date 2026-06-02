const STORAGE_KEY = "affiliate-share-records";

// 여기에 본인 Amazon Associates tracking ID를 넣으면 됩니다. 예: "mytag-20"
const OWNER_AFFILIATE_TAG = "soulful02-20";

const money = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

const form = document.querySelector("#linkForm");
const emptyState = document.querySelector("#emptyState");
const result = document.querySelector("#result");
const friendAmount = document.querySelector("#friendAmount");
const calcDetail = document.querySelector("#calcDetail");
const affiliateLink = document.querySelector("#affiliateLink");
const openAmazon = document.querySelector("#openAmazon");
const copyLink = document.querySelector("#copyLink");
const saveEstimate = document.querySelector("#saveEstimate");
const exportInvoice = document.querySelector("#exportInvoice");
const clearRecords = document.querySelector("#clearRecords");
const recordsBody = document.querySelector("#recordsBody");
const invoiceOutput = document.querySelector("#invoiceOutput");
const monthTotal = document.querySelector("#monthTotal");
const monthMeta = document.querySelector("#monthMeta");

let currentEstimate = null;

function readRecords() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || [];
  } catch {
    return [];
  }
}

function writeRecords(records) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
}

function extractAsin(pathname) {
  const match = pathname.match(/(?:\/dp\/|\/gp\/product\/)([A-Z0-9]{10})(?:[/?#]|$)/i);
  return match ? match[1].toUpperCase() : null;
}

function parseAmazonUrl(rawUrl) {
  const url = new URL(rawUrl);
  const host = url.hostname.replace(/^www\./, "");

  if (!host.endsWith("amazon.com")) {
    throw new Error("amazon.com 상품 링크만 넣어주세요.");
  }

  const asin = extractAsin(url.pathname);

  if (asin) {
    const canonicalUrl = new URL(`https://www.amazon.com/dp/${asin}`);
    canonicalUrl.searchParams.set("tag", OWNER_AFFILIATE_TAG);
    return canonicalUrl.toString();
  }

  url.hostname = "www.amazon.com";
  url.searchParams.set("tag", OWNER_AFFILIATE_TAG);
  return url.toString();
}

function calculateEstimate({ price, commissionRate, friendShare, taxReserve }) {
  const grossCommission = price * (commissionRate / 100);
  const afterTaxReserve = grossCommission * (1 - taxReserve / 100);
  const friendPayout = afterTaxReserve * (friendShare / 100);
  const ownerPayout = afterTaxReserve - friendPayout;

  return {
    grossCommission,
    afterTaxReserve,
    friendPayout,
    ownerPayout,
  };
}

function renderRecords() {
  const records = readRecords();
  const currentMonth = new Date().toISOString().slice(0, 7);
  const monthRecords = records.filter((record) => record.month === currentMonth);
  const total = monthRecords.reduce((sum, record) => sum + record.friendPayout, 0);

  monthTotal.textContent = money.format(total);
  monthMeta.textContent = `기록된 구매 후보 ${monthRecords.length}건`;

  if (!records.length) {
    recordsBody.innerHTML = '<tr><td colspan="5">아직 기록이 없습니다.</td></tr>';
    return;
  }

  recordsBody.innerHTML = records
    .slice()
    .reverse()
    .map((record) => `
      <tr>
        <td>${record.date}</td>
        <td>${money.format(record.price)}</td>
        <td>${money.format(record.grossCommission)}</td>
        <td>${money.format(record.friendPayout)}</td>
        <td><a href="${record.link}" target="_blank" rel="noopener">열기</a></td>
      </tr>
    `)
    .join("");
}

function makeInvoiceText(records) {
  const currentMonth = new Date().toISOString().slice(0, 7);
  const monthRecords = records.filter((record) => record.month === currentMonth);
  const total = monthRecords.reduce((sum, record) => sum + record.friendPayout, 0);

  if (!monthRecords.length) {
    return `${currentMonth} 정산 기록이 아직 없습니다.`;
  }

  const lines = monthRecords.map((record, index) => {
    return `${index + 1}. ${record.date} | 가격 ${money.format(record.price)} | 수수료 ${money.format(record.grossCommission)} | 친구 몫 ${money.format(record.friendPayout)}`;
  });

  return [
    `${currentMonth} Amazon affiliate share invoice`,
    "",
    ...lines,
    "",
    `총 지급 예정액: ${money.format(total)}`,
    "메모: 실제 지급액은 Amazon Associates 리포트와 입금액 확인 후 조정될 수 있습니다.",
  ].join("\n");
}

form.addEventListener("submit", (event) => {
  event.preventDefault();

  const rawUrl = document.querySelector("#amazonUrl").value;
  const price = Number(document.querySelector("#itemPrice").value);
  const commissionRate = Number(document.querySelector("#commissionRate").value);
  const friendShareValue = Number(document.querySelector("#friendShare").value);
  const taxReserve = Number(document.querySelector("#taxReserve").value);

  try {
    const link = parseAmazonUrl(rawUrl);
    const estimate = calculateEstimate({
      price,
      commissionRate,
      friendShare: friendShareValue,
      taxReserve,
    });

    currentEstimate = {
      date: new Date().toLocaleDateString("en-US"),
      month: new Date().toISOString().slice(0, 7),
      price,
      commissionRate,
      friendShare: friendShareValue,
      taxReserve,
      link,
      ...estimate,
    };

    friendAmount.textContent = money.format(estimate.friendPayout);
    calcDetail.textContent =
      `${money.format(price)} x ${commissionRate}% = ${money.format(estimate.grossCommission)}, ` +
      `${taxReserve}% 세금 보류 후 ${friendShareValue.toFixed(1).replace(".0", "")}% share`;
    affiliateLink.value = link;
    openAmazon.href = link;
    emptyState.hidden = true;
    result.hidden = false;
    saveEstimate.disabled = false;
  } catch (error) {
    currentEstimate = null;
    saveEstimate.disabled = true;
    alert(error.message);
  }
});

copyLink.addEventListener("click", async () => {
  await navigator.clipboard.writeText(affiliateLink.value);
  copyLink.textContent = "복사 완료";
  setTimeout(() => {
    copyLink.textContent = "링크 복사";
  }, 1400);
});

saveEstimate.addEventListener("click", () => {
  if (!currentEstimate) return;
  const records = readRecords();
  records.push(currentEstimate);
  writeRecords(records);
  renderRecords();
});

exportInvoice.addEventListener("click", () => {
  invoiceOutput.value = makeInvoiceText(readRecords());
});

clearRecords.addEventListener("click", () => {
  if (!confirm("정산 기록을 모두 지울까요?")) return;
  writeRecords([]);
  invoiceOutput.value = "";
  renderRecords();
});

renderRecords();
