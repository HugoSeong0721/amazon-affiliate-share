const OWNER_AFFILIATE_TAG = "soulful02-20";
const COMMISSION_RATE = 0.03;
const FRIEND_SHARE = 0.5;

const money = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

const form = document.querySelector("#linkForm");
const affiliateLink = document.querySelector("#affiliateLink");
const openAmazon = document.querySelector("#openAmazon");
const copyLink = document.querySelector("#copyLink");
const result = document.querySelector("#result");
const estimateBox = document.querySelector("#estimateBox");
const rebateAmount = document.querySelector("#rebateAmount");
const rebateDetail = document.querySelector("#rebateDetail");

function extractAsin(pathname) {
  const match = pathname.match(/(?:\/dp\/|\/gp\/product\/)([A-Z0-9]{10})(?:[/?#]|$)/i);
  return match ? match[1].toUpperCase() : null;
}

function makeAffiliateLink(rawUrl) {
  const url = new URL(rawUrl);
  const host = url.hostname.replace(/^www\./, "");

  if (!host.endsWith("amazon.com")) {
    throw new Error("Please paste an amazon.com product link.");
  }

  const asin = extractAsin(url.pathname);

  if (asin) {
    const cleanUrl = new URL(`https://www.amazon.com/dp/${asin}`);
    cleanUrl.searchParams.set("tag", OWNER_AFFILIATE_TAG);
    return cleanUrl.toString();
  }

  url.hostname = "www.amazon.com";
  url.searchParams.set("tag", OWNER_AFFILIATE_TAG);
  return url.toString();
}

form.addEventListener("submit", (event) => {
  event.preventDefault();

  try {
    const link = makeAffiliateLink(document.querySelector("#amazonUrl").value);
    const itemPrice = Number(document.querySelector("#itemPrice").value);

    affiliateLink.value = link;
    openAmazon.href = link;
    result.hidden = false;

    if (itemPrice > 0) {
      const estimatedCommission = itemPrice * COMMISSION_RATE;
      const estimatedRebate = estimatedCommission * FRIEND_SHARE;

      rebateAmount.textContent = money.format(estimatedRebate);
      rebateDetail.textContent =
        `${money.format(itemPrice)} x 3% commission x 50% share. Estimate only; final amount may change.`;
      estimateBox.hidden = false;
    } else {
      estimateBox.hidden = true;
    }
  } catch (error) {
    result.hidden = true;
    estimateBox.hidden = true;
    alert(error.message);
  }
});

copyLink.addEventListener("click", async () => {
  await navigator.clipboard.writeText(affiliateLink.value);
  copyLink.textContent = "Copied";
  setTimeout(() => {
    copyLink.textContent = "Copy link";
  }, 1400);
});
