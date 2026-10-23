-- Server entry point.
-- v0.1: Rojo sync smoke test only. No game logic yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)

print(`[Server] Anime-Base {Version.Build} ({Version.Name}) loaded`)
