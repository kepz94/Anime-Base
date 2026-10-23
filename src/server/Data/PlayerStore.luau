-- Player store (v0.3): loads and saves profiles in the DataStore with a session lock.
--
-- Record shape: { Profile = <Profile v1>, Lock = { JobId, LockedAt } | nil }
-- * Load claims the lock. A lock held by another server and younger than LOCK_TTL is respected:
--   retry LOCKED_RETRIES times, then the caller kicks the player. (Studio sessions share JobId "".)
-- * Save writes only while this server holds the lock; Release also clears it.
-- * Errors retry with backoff; a load that still fails returns an error so the caller kicks
--   instead of starting a fresh profile over saved data.
-- Studio uses the same DataStore as the live game (owner-accepted; test copy before release).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Profile = require(ReplicatedStorage.Shared.Base.Profile)
local DevFlags = require(script.Parent.Parent.DevFlags)

local PlayerStore = {}

PlayerStore.StoreName = "AB_Profile_v1"
local LOCK_TTL = 30 * 60 -- seconds; a crashed server's lock expires after this
local ERROR_RETRIES = 3
local LOCKED_RETRIES = 3
local LOCKED_WAIT = 5

local store = DataStoreService:GetDataStore(PlayerStore.StoreName)

local function key(userId: number): string
	return `u_{userId}`
end

local function lockedByOther(record, now: number): boolean
	local lock = record and record.Lock
	return lock ~= nil and lock.JobId ~= game.JobId and now - (lock.LockedAt or 0) < LOCK_TTL
end

-- UpdateAsync with retries on errors. transform returns the new record or nil (no write).
local function update(userId: number, transform): (boolean, any)
	local lastErr
	for attempt = 1, ERROR_RETRIES do
		local ok, result = pcall(function()
			return store:UpdateAsync(key(userId), transform)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < ERROR_RETRIES then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastErr
end

-- Returns (profile, nil) or (nil, reason) with reason "Locked" | "Error: <message>".
function PlayerStore.Load(userId: number)
	if RunService:IsStudio() and DevFlags.ForceLoadFailureInStudio then
		return nil, "Error: forced load failure (DevFlags.ForceLoadFailureInStudio)"
	end
	for _ = 1, LOCKED_RETRIES do
		local locked, badData = false, nil
		local ok, result = update(userId, function(record)
			local now = os.time()
			if lockedByOther(record, now) then
				locked = true
				return nil -- leave the record untouched
			end
			local readOk, profileOrErr = pcall(Profile.FromSaved, record and record.Profile)
			if not readOk then
				badData = profileOrErr
				return nil -- never overwrite data this server cannot read
			end
			return { Profile = profileOrErr, Lock = { JobId = game.JobId, LockedAt = now } }
		end)
		if not ok then
			return nil, `Error: {result}`
		end
		if badData then
			return nil, `Error: {badData}`
		end
		if not locked then
			return result.Profile, nil
		end
		task.wait(LOCKED_WAIT)
	end
	return nil, "Locked"
end

-- Writes the profile if this server still holds the lock. release = true also clears the lock.
-- Returns (true, nil) or (false, reason) with reason "LockLost" | "Error: <message>".
function PlayerStore.Save(userId: number, profile, release: boolean)
	local lost = false
	local ok, result = update(userId, function(record)
		local now = os.time()
		if lockedByOther(record, now) then
			lost = true
			return nil
		end
		return { Profile = profile, Lock = if release then nil else { JobId = game.JobId, LockedAt = now } }
	end)
	if not ok then
		return false, `Error: {result}`
	end
	if lost then
		return false, "LockLost"
	end
	return true, nil
end

return PlayerStore
