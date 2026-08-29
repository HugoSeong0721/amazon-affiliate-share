const OWNER_AFFILIATE_TAG = "soulful02-20";
const FRIEND_TRACKING_IDS = {
  celina: "celina001-20",
};

const form = document.querySelector("#linkForm");
const amazonUrl = document.querySelector("#amazonUrl");
const openAmazon = document.querySelector("#openAmazon");
const result = document.querySelector("#result");
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

function updateAffiliateLink() {
  try {
    const rawUrl = amazonUrl.value.trim();

    if (!rawUrl) {
      result.hidden = true;
      statusMessage.textContent = "Paste a full Amazon, a.co, or amzn.to link to generate your shopping link.";
      statusMessage.className = "status-message";
      return;
    }

    const link = makeAffiliateLink(rawUrl);
    openAmazon.href = link;
    result.hidden = false;
    statusMessage.textContent = "Your Amazon shopping link is ready below.";
    statusMessage.className = "status-message success";
  } catch (error) {
    result.hidden = true;
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
