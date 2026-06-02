const OWNER_AFFILIATE_TAG = "soulful02-20";
const DEFAULT_COMMISSION_RATE = 0.03;
const DEFAULT_TAX_RESERVE = 0.25;
const DEFAULT_REBATE_SPLIT = 0.5;

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

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  try {
    const link = makeAffiliateLink(document.querySelector("#amazonUrl").value);

    affiliateLink.value = link;
    openAmazon.href = link;
    result.hidden = false;
    rebateAmount.textContent = "Calculating";
    rebateDetail.textContent = "Checking the item price and commission estimate for this Amazon link.";
    estimateBox.hidden = false;

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
