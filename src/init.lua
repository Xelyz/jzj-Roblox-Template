-- init.lua
-- This script is the main entry point for the game logic.
-- It detects the environment (client or server) and requires the
-- appropriate modules to start the game.

local RunService = game:GetService("RunService")

local M = {}

if RunService:IsServer() then
    print("Initializing server modules...")
    -- Services that are dependencies for other modules
    M.Utils = require(script.Server.ServerUtils)
    M.SignalManager = require(script.SignalManager)
    M.MatchService = require(script.Server.MatchService)
    M.LeaderboardService = require(script.Server.LeaderboardServiceServer)

    -- Managers that listen to events and execute logic
    require(script.Server.RoomManager)
    require(script.Server.ChatManager)
    require(script.Server.LeaderboardManager)
    require(script.Server.DisableMovementServer)

    print("Server modules initialized.")

elseif RunService:IsClient() then
    print("Initializing client modules...")
    -- Core modules needed by other client scripts
    M.Utils = require(script.Client.ClientUIUtils)
    M.SignalManager = require(script.SignalManager)

    -- UI and logic modules
    require(script.Client.RoomClient)
    require(script.Client.ChatClient)
    require(script.Client.DisableMovementClient)
    require(script.Client.LeaderboardClient)
    require(script.Client.MatchStateClient)
    
    print("Client modules initialized.")
end

return M 