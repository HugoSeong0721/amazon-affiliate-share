const OWNER_AFFILIATE_TAG = "soulful02-20";

const form = document.querySelector("#linkForm");
const affiliateLink = document.querySelector("#affiliateLink");
const openAmazon = document.querySelector("#openAmazon");
const copyLink = document.querySelector("#copyLink");
const result = document.querySelector("#result");

function extractAsin(pathname) {
  const match = pathname.match(/(?:\/dp\/|\/gp\/product\/)([A-Z0-9]{10})(?:[/?#]|$)/i);
  return match ? match[1].toUpperCase() : null;
}

function makeAffiliateLink(rawUrl) {
  const url = new URL(rawUrl);
  const host = url.hostname.replace(/^www\./, "");

  if (!host.endsWith("amazon.com")) {
    throw new Error("amazon.com 상품 링크만 넣어주세요.");
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
    affiliateLink.value = link;
    openAmazon.href = link;
    result.hidden = false;
  } catch (error) {
    result.hidden = true;
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
