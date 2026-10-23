-- Minimal assertions for Lune tests (v0.3). Each failure raises with a message the runner prints.

local Assert = {}

local function show(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function Assert.Equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {show(expected)}, got {show(actual)}`, 2)
	end
end

function Assert.Near(actual: number, expected: number, epsilon: number, label: string?)
	if math.abs(actual - expected) > epsilon then
		error(`{label or "value"}: expected {expected} ± {epsilon}, got {actual}`, 2)
	end
end

function Assert.True(condition: any, label: string?)
	if not condition then
		error(`{label or "condition"}: expected true`, 2)
	end
end

function Assert.Error(fn: () -> (), pattern: string?, label: string?)
	local ok, err = pcall(fn)
	if ok then
		error(`{label or "call"}: expected an error`, 2)
	end
	if pattern and not string.find(tostring(err), pattern) then
		error(`{label or "call"}: error {show(tostring(err))} does not match {show(pattern)}`, 2)
	end
end

-- Deep copy + deep compare, used to prove a rejected action left the profile unchanged.
function Assert.DeepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = Assert.DeepCopy(v)
	end
	return out
end

local function deepEqual(a: any, b: any, path: string): string?
	if type(a) ~= type(b) then
		return `{path}: type {type(a)} vs {type(b)}`
	end
	if type(a) ~= "table" then
		return if a == b then nil else `{path}: {show(a)} vs {show(b)}`
	end
	for k, v in a do
		local diff = deepEqual(v, b[k], `{path}.{tostring(k)}`)
		if diff then
			return diff
		end
	end
	for k in b do
		if a[k] == nil then
			return `{path}.{tostring(k)}: missing on the left`
		end
	end
	return nil
end

function Assert.DeepEqual(actual: any, expected: any, label: string?)
	local diff = deepEqual(actual, expected, label or "value")
	if diff then
		error(diff, 2)
	end
end

return Assert
