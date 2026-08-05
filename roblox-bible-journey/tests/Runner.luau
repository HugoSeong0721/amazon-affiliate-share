--!strict
-- A ~100 line test runner so the prototype has no package manager and no excuse
-- not to run its tests. Swap for TestEZ whenever you add Wally.

export type Expectation = {
	toBe: (expected: any) -> Expectation,
	toEqual: (expected: any) -> Expectation,
	toBeTruthy: () -> Expectation,
	toBeFalsy: () -> Expectation,
	toBeNil: () -> Expectation,
	toBeCloseTo: (expected: number, tolerance: number?) -> Expectation,
	toHaveLength: (expected: number) -> Expectation,
	toThrow: (substring: string?) -> Expectation,
}

export type Env = {
	describe: (title: string, body: () -> ()) -> (),
	it: (title: string, body: () -> ()) -> (),
	expect: (value: any) -> Expectation,
}

local function stringify(value: any): string
	if type(value) == "table" then
		local ok, encoded = pcall(function()
			local parts = {}
			for key, inner in value do
				table.insert(parts, `{tostring(key)}={tostring(inner)}`)
			end
			table.sort(parts)
			return "{" .. table.concat(parts, ", ") .. "}"
		end)
		return if ok then encoded else "<table>"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function expect(value: any): Expectation
	local api: any = {}

	function api.toBe(expected: any)
		if value ~= expected then
			error(`expected {stringify(expected)}, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toEqual(expected: any)
		if not deepEqual(value, expected) then
			error(`expected {stringify(expected)}, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toBeTruthy()
		if not value then
			error(`expected truthy, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toBeFalsy()
		if value then
			error(`expected falsy, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toBeNil()
		if value ~= nil then
			error(`expected nil, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toBeCloseTo(expected: number, tolerance: number?)
		local limit = tolerance or 1e-6
		if type(value) ~= "number" or math.abs(value - expected) > limit then
			error(`expected {expected} ± {limit}, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toHaveLength(expected: number)
		if type(value) ~= "table" or #value ~= expected then
			error(`expected length {expected}, got {stringify(value)}`, 0)
		end
		return api
	end

	function api.toThrow(substring: string?)
		if type(value) ~= "function" then
			error("toThrow expects a function", 0)
		end
		local ok, err = pcall(value)
		if ok then
			error("expected the call to throw, but it returned", 0)
		end
		if substring and not string.find(tostring(err), substring, 1, true) then
			error(`expected error containing "{substring}", got "{tostring(err)}"`, 0)
		end
		return api
	end

	return api
end

local Runner = {}

function Runner.run(specs: { ModuleScript }): boolean
	local stack: { string } = {}
	local passed = 0
	local failures: { string } = {}

	local function describe(title: string, body: () -> ())
		table.insert(stack, title)
		local ok, err = pcall(body)
		table.remove(stack)
		if not ok then
			table.insert(failures, `{title} (describe body errored)\n      {tostring(err)}`)
		end
	end

	local function it(title: string, body: () -> ())
		table.insert(stack, title)
		local path = table.concat(stack, " › ")
		local ok, err = pcall(body)
		table.remove(stack)

		if ok then
			passed += 1
		else
			table.insert(failures, `{path}\n      {tostring(err)}`)
		end
	end

	local env: Env = { describe = describe, it = it, expect = expect }

	for _, module in specs do
		local ok, result = pcall(require, module)
		if not ok then
			table.insert(failures, `{module.Name} failed to require\n      {tostring(result)}`)
			continue
		end
		local ranOk, err = pcall(result :: any, env)
		if not ranOk then
			table.insert(failures, `{module.Name} errored at top level\n      {tostring(err)}`)
		end
	end

	if #failures == 0 then
		print(`[tests] {passed} passed`)
		return true
	end

	warn(`[tests] {passed} passed, {#failures} failed`)
	for _, failure in failures do
		warn(`  ✗ {failure}`)
	end
	return false
end

return Runner
