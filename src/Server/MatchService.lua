-- MatchService: Shared match state for server scripts

local MatchService = {}

local Utils = require(script.Parent.ServerUtils)
local Config = require(script.Parent.Parent.Config)

-- [matchId] = {players = {player1, player2, ...}, state = {}}
MatchService.activeGames = {}

function MatchService.GetMatch(matchId)
    if not matchId then
        print("Warning: GetMatch called with nil matchId")
        return nil
    end
    return MatchService.activeGames[matchId]
end

function MatchService.AddMatch(players)
    local minPlayers = Config.game.minPlayers or 2 -- 默认2人，防止配置缺失
    if not players or #players < minPlayers then
        print("Error: AddMatch called with invalid parameters")
        print("  players:", players and #players or "nil")
        print("  minPlayers required:", minPlayers)
        return nil
    end

    local matchId = Utils.generateId("match")
    local playerNames = {}
    for i, player in ipairs(players) do
        table.insert(playerNames, player.Name)
    end

    print("Adding match:", matchId, "with", #players, "players:", table.concat(playerNames, ", "))
    MatchService.activeGames[matchId] = {
        players = players
    }
    return matchId
end

function MatchService.RemoveMatch(matchId)
    if not matchId then
        print("Warning: RemoveMatch called with nil matchId")
        return
    end
    
    if MatchService.activeGames[matchId] then
        print("Removing match:", matchId)
        MatchService.activeGames[matchId] = nil
    else
        print("Warning: Attempted to remove non-existent match:", matchId)
    end
end

function MatchService.GetMatchByPlayer(player)
    if not player then
        print("Warning: GetMatchByPlayer called with nil player")
        return nil
    end
    
    for matchId, match in pairs(MatchService.activeGames) do
        for _, matchPlayer in ipairs(match.players) do
            if matchPlayer == player then
                return matchId, match
            end
        end
    end
    
    return nil, nil
end

return MatchService

