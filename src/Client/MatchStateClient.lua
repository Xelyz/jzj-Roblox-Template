-- ClientMatchState: Shared client match state (currentMatchId, playerUserId, opponentUserIds)

local ClientMatchState = {}

local currentMatchId = nil
local playerUserId = nil
local opponentUserIds = {}

function ClientMatchState.GetMatchId()
    return currentMatchId
end

function ClientMatchState.SetMatchId(matchId)
    currentMatchId = matchId
end

function ClientMatchState.GetPlayerUserId()
    return playerUserId
end

function ClientMatchState.GetOpponentUserIds()
    return opponentUserIds
end

function ClientMatchState.SetPlayerUserIds(myUserId, enemyUserIds)
    playerUserId = myUserId
    opponentUserIds = {}
    for i, userId in ipairs(enemyUserIds) do
        table.insert(opponentUserIds, userId)
    end
end

function ClientMatchState.Clear()
    currentMatchId = nil
    playerUserId = nil
    opponentUserIds = {}
end

return ClientMatchState

