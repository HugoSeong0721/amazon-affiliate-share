const OWNER_AFFILIATE_TAG = "soulful02-20";
const FRIEND_TRACKING_IDS = {
  celina: "celina001-20",
};
const DEFAULT_COMMISSION_RATE = 0.03;
const DEFAULT_TAX_RESERVE = 0.25;
const DEFAULT_REBATE_SPLIT = 0.5;

const money = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

const form = document.querySelector("#linkForm");
const amazonUrl = document.querySelector("#amazonUrl");
const affiliateLink = document.querySelector("#affiliateLink");
const openAmazon = document.querySelector("#openAmazon");
const copyLink = document.querySelector("#copyLink");
const result = document.querySelector("#result");
const estimateBox = document.querySelector("#estimateBox");
const rebateAmount = document.querySelector("#rebateAmount");
const rebateDetail = document.querySelector("#rebateDetail");
const statusMessage = document.querySelector("#statusMessage");

const AMAZON_HOSTS = ["amazon.com", "a.co", "amzn.to"];

function getTrackingId() {
  const friendKey = new URLSearchParams(window.location.search).get("friend");
  if (!friendKey) return OWNER_AFFILIATE_TAG;
  return FRIEND_TRACKING_IDS[friendKey.trim().toLowerCase()] || OWNER_AFFILIATE_TAG;
}

function extractAsin(pathname) {
  const match = pathname.match(/(?:\/dp\/|\/gp\/product\/)([A-Z0-9]{10})(?:[/?#]|$)/i);
  return match ? match[1].toUpperCase() : null;
}

function normalizeUrl(rawUrl) {
  if (/^https?:\/\//i.test(rawUrl)) return rawUrl;
  return `https://${rawUrl}`;
}

function isSupportedAmazonHost(host) {
  return AMAZON_HOSTS.some((amazonHost) => host === amazonHost || host.endsWith(`.${amazonHost}`));
}

function makeAffiliateLink(rawUrl) {
  const url = new URL(normalizeUrl(rawUrl));
  const host = url.hostname.replace(/^www\./, "");

  if (!isSupportedAmazonHost(host)) {
    throw new Error("Paste an Amazon, a.co, or amzn.to product link.");
  }

  const asin = extractAsin(url.pathname);

  if (asin) {
    const cleanUrl = new URL(`https://www.amazon.com/dp/${asin}`);
    cleanUrl.searchParams.set("tag", getTrackingId());
    return cleanUrl.toString();
  }

  url.searchParams.set("tag", getTrackingId());
  return url.toString();
}

function estimateRebateFromProductData(productData) {
  if (!productData || !productData.price) return null;

  const commissionRate = productData.commissionRate || DEFAULT_COMMISSION_RATE;
  const taxReserve = productData.taxReserve || DEFAULT_TAX_RESERVE;
  const rebateSplit = productData.rebateSplit || DEFAULT_REBATE_SPLIT;
  const estimatedCommission = productData.price * commissionRate;
  const afterTaxEstimate = estimatedCommission * (1 - taxReserve);
  const estimatedRebate = afterTaxEstimate * rebateSplit;

  return {
    afterTaxEstimate,
    commissionRate,
    estimatedCommission,
    estimatedRebate,
    price: productData.price,
    rebateSplit,
    taxReserve,
  };
}

async function lookupProductEstimate() {
  // Static GitHub Pages cannot securely read Amazon price/category data.
  // This function is the hook for a future backend or Amazon Product Advertising API lookup.
  return null;
}

async function updateAffiliateLink() {
  try {
    const rawUrl = amazonUrl.value.trim();

    if (!rawUrl) {
      result.hidden = true;
      estimateBox.hidden = true;
      statusMessage.textContent = "Paste a full Amazon, a.co, or amzn.to link to generate your shopping link.";
      statusMessage.className = "status-message";
      return;
    }

    const link = makeAffiliateLink(rawUrl);

    affiliateLink.value = link;
    openAmazon.href = link;
    result.hidden = false;
    rebateAmount.textContent = "Calculating";
    rebateDetail.textContent = "Checking the item price and commission estimate for this Amazon link.";
    estimateBox.hidden = false;
    statusMessage.textContent = "Your Amazon shopping link is ready below.";
    statusMessage.className = "status-message success";

    const estimate = estimateRebateFromProductData(await lookupProductEstimate(link));

    if (estimate) {
      rebateAmount.textContent = money.format(estimate.estimatedRebate);
      rebateDetail.textContent =
        `${money.format(estimate.price)} item price x ${(estimate.commissionRate * 100).toFixed(1)}% estimated Amazon commission ` +
        `minus ${(estimate.taxReserve * 100).toFixed(0)}% estimated tax reserve, then ${(estimate.rebateSplit * 100).toFixed(0)}% split. ` +
        `Final amount may change after Amazon confirms the order.`;
    } else {
      rebateAmount.textContent = "Estimate pending";
      rebateDetail.textContent =
        "Your Amazon link is ready. Estimated rebate will be calculated from the final Amazon commission after the purchase is confirmed.";
    }
  } catch (error) {
    result.hidden = true;
    estimateBox.hidden = true;
    statusMessage.textContent = error.message;
    statusMessage.className = "status-message error";
  }
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  updateAffiliateLink();
});

amazonUrl.addEventListener("input", updateAffiliateLink);
amazonUrl.addEventListener("change", updateAffiliateLink);
amazonUrl.addEventListener("paste", () => {
  setTimeout(() => {
    updateAffiliateLink();
    result.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }, 50);
});

copyLink.addEventListener("click", async () => {
  await navigator.clipboard.writeText(affiliateLink.value);
  copyLink.textContent = "Copied";
  setTimeout(() => {
    copyLink.textContent = "Copy link";
  }, 1400);
});
