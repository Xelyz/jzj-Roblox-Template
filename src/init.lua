-- init.lua
-- This script is the main entry point for the game logic.
-- It detects the environment (client or server) and requires the
-- appropriate modules to start the game.

local RunService = game:GetService("RunService")

local M = {}

if RunService:IsServer() then
    print("Initializing server modules...")
    -- Core configuration - must be loaded first
    M.Config = require(script.Config)
    
    -- Services that are dependencies for other modules
    M.ServerUtils = require(script.Server.ServerUtils)
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
    -- Core configuration - must be loaded first
    M.Config = require(script.Config)
    
    -- Core modules needed by other client scripts
    M.UI = require(script.Client.ClientUIUtils)
    M.SignalManager = require(script.SignalManager)
    M.MatchStateClient = require(script.Client.MatchStateClient)

    -- UI and logic modules
    require(script.Client.RoomClient)
    require(script.Client.ChatClient)
    require(script.Client.DisableMovementClient)
    require(script.Client.LeaderboardClient)
    
    print("Client modules initialized.")
end

return M 