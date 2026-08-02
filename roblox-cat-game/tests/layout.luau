-- UI 배치 검사기 (스크린샷 대용)
--
-- 클라이언트 스크립트를 실제로 실행시킨 뒤, 만들어진 UI 요소들의
-- 화면 좌표를 계산해서 문제를 찾고 SVG 도면으로 그려준다.
--
-- 이 도구가 없었으면 못 잡았을 종류의 문제:
--   · 안내창이 다른 패널 뒤에 가려짐 (실제로 겪었던 버그)
--   · 요소가 화면 밖으로 나감
--   · 버튼 위 글자가 버튼보다 넓어서 잘림
--
--   ./tests/runner/target/release/luarun tests/layout.luau
--
-- 주의: 진짜 렌더링이 아니다. 색·폰트·실제 글자 크기는 확인할 수 없다.

local boot = _loadChunk(_readFile(_scriptDir .. "/boot.luau"), "boot.luau")()

local VIEWPORT_W, VIEWPORT_H = 1280, 720

local env = boot({})
local Mock = env.Mock
local player = env.player

-- 튜토리얼 안내창까지 뜬 상태로 만든다
env.remotes:FindFirstChild("RequestData"):FireServer()
Mock.step(0.5)

---------------------------------------------------------------
-- 좌표 계산
---------------------------------------------------------------
local GUI_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, ImageLabel = true,
	ImageButton = true, ScrollingFrame = true, TextBox = true,
}

local function resolve(udim2, parentW, parentH)
	if type(udim2) ~= "table" or not udim2.X then
		return 0, 0
	end
	return udim2.X.Scale * parentW + udim2.X.Offset,
		udim2.Y.Scale * parentH + udim2.Y.Offset
end

local elements = {}

local function walk(node, parentX, parentY, parentW, parentH, inheritedZ, visible, screenName)
	for _, child in ipairs(node:GetChildren()) do
		if GUI_CLASSES[child.ClassName] then
			local w, h = resolve(child.Size, parentW, parentH)
			local x, y = resolve(child.Position, parentW, parentH)
			local absX, absY = parentX + x, parentY + y
			local childVisible = visible and (child.Visible ~= false)
			local z = child.ZIndex or inheritedZ

			table.insert(elements, {
				Name = child.Name,
				Class = child.ClassName,
				Text = child.Text,
				X = absX, Y = absY, W = w, H = h,
				Z = z,
				Visible = childVisible,
				Screen = screenName,
			})

			walk(child, absX, absY, w, h, z, childVisible, screenName)
		else
			walk(child, parentX, parentY, parentW, parentH, inheritedZ, visible, screenName)
		end
	end
end

local playerGui = player:FindFirstChild("PlayerGui")
for _, screen in ipairs(playerGui:GetChildren()) do
	if screen.ClassName == "ScreenGui" then
		local enabled = screen.Enabled ~= false
		walk(screen, 0, 0, VIEWPORT_W, VIEWPORT_H, screen.DisplayOrder or 0, enabled, screen.Name)
	end
end

_write(("=== UI 요소 %d개 (화면 %dx%d 기준) ==="):format(#elements, VIEWPORT_W, VIEWPORT_H))

---------------------------------------------------------------
-- 문제 찾기
---------------------------------------------------------------
local problems = {}

local function report(kind, detail)
	table.insert(problems, ("[%s] %s"):format(kind, detail))
end

for _, e in ipairs(elements) do
	if e.Visible and e.W > 0 and e.H > 0 then
		-- 화면 밖
		if e.X < -1 or e.Y < -1 or e.X + e.W > VIEWPORT_W + 1 or e.Y + e.H > VIEWPORT_H + 1 then
			report("화면 밖", ("%s/%s  (%d,%d %dx%d)"):format(e.Screen, e.Name, e.X, e.Y, e.W, e.H))
		end
		-- 글자가 상자보다 넓을 가능성 (한글은 폭이 넓다고 보고 넉넉히 잡는다)
		if type(e.Text) == "string" and #e.Text > 0 and e.Class ~= "TextBox" then
			local charCount = utf8.len(e.Text) or #e.Text
			-- 줄바꿈이 있으면 가장 긴 줄로 계산
			local longest = 0
			for line in (e.Text .. "\n"):gmatch("([^\n]*)\n") do
				longest = math.max(longest, utf8.len(line) or #line)
			end
			charCount = longest
			-- TextScaled/TextWrapped 는 알아서 줄이므로 제외
			if not e.TextScaled and not e.TextWrapped then
				local estimated = charCount * 11 -- 대략적인 글자 폭
				if estimated > e.W * 1.6 then
					report("글자 넘침 의심", ("%s/%s  \"%s\"  칸 폭 %d"):format(
						e.Screen, e.Name, e.Text, e.W))
				end
			end
		end
	end
end

-- 같은 ZIndex에서 서로 겹치는 최상위 요소들
local function overlaps(a, b)
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

local topLevel = {}
for _, e in ipairs(elements) do
	if e.Visible and e.W > 40 and e.H > 20 then
		table.insert(topLevel, e)
	end
end

for i = 1, #topLevel do
	for j = i + 1, #topLevel do
		local a, b = topLevel[i], topLevel[j]
		-- 부모-자식 관계면 겹치는 게 정상이라, 완전 포함은 넘어간다
		local contained = (a.X <= b.X and a.Y <= b.Y and a.X + a.W >= b.X + b.W and a.Y + a.H >= b.Y + b.H)
			or (b.X <= a.X and b.Y <= a.Y and b.X + b.W >= a.X + a.W and b.Y + b.H >= a.Y + a.H)
		if not contained and overlaps(a, b) and a.Z == b.Z and a.Screen == b.Screen then
			report("겹침(같은 층)", ("%s ↔ %s  (Z=%d)"):format(a.Name, b.Name, a.Z))
		end
	end
end

---------------------------------------------------------------
-- SVG 도면
---------------------------------------------------------------
local svg = {}
table.insert(svg, ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">')
	:format(VIEWPORT_W, VIEWPORT_H, VIEWPORT_W, VIEWPORT_H))
table.insert(svg, '<rect width="100%" height="100%" fill="#1d2733"/>')

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- 한글은 한 글자가 여러 바이트라, 바이트로 자르면 UTF-8이 깨진다
local function truncate(text, maxChars)
	local count = utf8.len(text)
	if not count or count <= maxChars then
		return text
	end
	local cutoff = utf8.offset(text, maxChars + 1)
	return text:sub(1, (cutoff or 0) - 1) .. "…"
end

table.sort(elements, function(a, b) return (a.Z or 0) < (b.Z or 0) end)

for _, e in ipairs(elements) do
	if e.W > 0 and e.H > 0 then
		local stroke = e.Visible and "#7fd3ff" or "#4a5a68"
		local fill = e.Visible and "rgba(127,211,255,0.10)" or "rgba(80,90,100,0.06)"
		table.insert(svg, ('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="%s" stroke="%s" stroke-width="1"/>')
			:format(e.X, e.Y, e.W, e.H, fill, stroke))
		local caption = e.Name
		if type(e.Text) == "string" and #e.Text > 0 then
			local firstLine = e.Text:match("^[^\n]*") or ""
			caption = caption .. " · " .. firstLine
		end
		if e.W > 60 and e.H > 14 then
			table.insert(svg, ('<text x="%.0f" y="%.0f" fill="%s" font-family="sans-serif" font-size="11">%s</text>')
				:format(e.X + 4, e.Y + 13, e.Visible and "#dff0ff" or "#6b7a88", escape(truncate(caption, 40))))
		end
	end
end

table.insert(svg, '</svg>')

local outPath = _scriptDir .. "/../build/ui-layout.svg"
_writeFile(outPath, table.concat(svg, "\n"))

---------------------------------------------------------------
_write("")
if #problems == 0 then
	_write("문제 없음 ✓")
else
	_write(("발견된 문제 %d건:"):format(#problems))
	for _, item in ipairs(problems) do
		_write("  · " .. item)
	end
end
_write("")
_write("도면 저장: build/ui-layout.svg")

-- 눈에 띄는 요소들의 좌표를 표로도 남긴다
_write("")
_write("주요 요소:")
for _, e in ipairs(elements) do
	if e.Visible and e.W >= 100 and e.H >= 30 then
		_write(("  %-14s %-16s x=%4d y=%4d  %3dx%-3d  Z=%d"):format(
			e.Screen, e.Name:sub(1, 16), e.X, e.Y, e.W, e.H, e.Z or 0))
	end
end
