-- MatchService: Shared match state for server scripts

local Utils = require(game.ServerScriptService:WaitForChild("ServerUtils"))

local MatchService = {}

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
    if not players or #players < 2 then
        print("Error: AddMatch called with invalid parameters")
        print("  players:", players and #players or "nil")
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

