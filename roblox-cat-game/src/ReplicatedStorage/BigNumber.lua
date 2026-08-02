-- BigNumber (ModuleScript / ReplicatedStorage)
--
-- Pet Simulator 계열 게임은 숫자가 금방 커진다.
-- 1234567 을 "1.23M" 처럼 읽기 좋게 줄여준다.

local BigNumber = {}

local SUFFIXES = {
	{ 1e33, "De" }, -- 데실리언
	{ 1e30, "No" },
	{ 1e27, "Oc" },
	{ 1e24, "Sp" },
	{ 1e21, "Sx" },
	{ 1e18, "Qi" },
	{ 1e15, "Qa" },
	{ 1e12, "T" }, -- 조
	{ 1e9, "B" }, -- 십억
	{ 1e6, "M" }, -- 백만
	{ 1e3, "K" }, -- 천
}

-- 1234 → "1.23K",  999 → "999",  12300000 → "12.3M"
function BigNumber.Short(value)
	value = tonumber(value) or 0
	local sign = value < 0 and "-" or ""
	local amount = math.abs(value)

	if amount < 1000 then
		return sign .. tostring(math.floor(amount))
	end

	for _, entry in ipairs(SUFFIXES) do
		local threshold, suffix = entry[1], entry[2]
		if amount >= threshold then
			local scaled = amount / threshold
			-- 자릿수에 따라 소수점을 줄여 항상 4글자 안팎으로 유지
			local text
			if scaled < 10 then
				text = string.format("%.2f", scaled)
			elseif scaled < 100 then
				text = string.format("%.1f", scaled)
			else
				text = string.format("%.0f", scaled)
			end
			-- 1.00K 처럼 의미 없는 0은 지운다
			text = text:gsub("%.?0+$", "")
			return sign .. text .. suffix
		end
	end

	return sign .. tostring(math.floor(amount))
end

return BigNumber
