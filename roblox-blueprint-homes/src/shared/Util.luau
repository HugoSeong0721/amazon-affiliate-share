--!strict
-- Small shared helpers.

local Util = {}

-- 1234567 -> "1,234,567"
function Util.comma(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if s:sub(1, 1) == "-" then
		sign = "-"
		s = s:sub(2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	out = out:gsub("^,", "")
	return sign .. out
end

function Util.money(n: number): string
	return "$" .. Util.comma(n)
end

-- Retry an async function with exponential backoff.
-- Returns ok, resultOrError.
function Util.retry(attempts: number, baseDelay: number, fn: () -> any): (boolean, any)
	local ok, result
	for i = 1, attempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if i < attempts then
			task.wait(baseDelay * 2 ^ (i - 1))
		end
	end
	return false, result
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = Util.deepCopy(v)
	end
	return copy
end

function Util.isInteger(n: any): boolean
	return type(n) == "number" and n == n and n % 1 == 0
end

return Util
