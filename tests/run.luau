-- Lune test runner (v0.3). Usage from the repo root: lune run tests/run
-- Runs every tests/*.spec.luau. A spec returns { [caseName] = function() ... end }.
-- Prints PASS/FAIL per case; exits 1 if any case fails or any spec fails to load.

local fs = require("@lune/fs")
local process = require("@lune/process")

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, name)
	end
end
table.sort(specs)

local passed, failed = 0, 0
for _, file in specs do
	local moduleName = string.gsub(file, "%.luau$", "")
	local ok, cases = pcall(require, "./" .. moduleName)
	if not ok then
		failed += 1
		print(`FAIL {file} (load): {cases}`)
	elseif type(cases) ~= "table" then
		failed += 1
		print(`FAIL {file} (load): spec must return a table of cases`)
	else
		local names = {}
		for caseName in cases do
			table.insert(names, caseName)
		end
		table.sort(names)
		for _, caseName in names do
			local caseOk, err = pcall(cases[caseName])
			if caseOk then
				passed += 1
			else
				failed += 1
				print(`FAIL {file} :: {caseName}\n     {err}`)
			end
		end
	end
end

print(`{passed} passed, {failed} failed ({#specs} spec files)`)
process.exit(if failed == 0 then 0 else 1)
