local M = {}

-- LeaderboardManager (Server) - 处理排行榜相关的远程调用

local SignalManager = require(script.Parent.Parent.SignalManager)
local LeaderboardService = require(script.Parent.LeaderboardServiceServer)

local GetLeaderboard = SignalManager.GetRemoteFunction("GetLeaderboard")
local GetPlayerRank = SignalManager.GetRemoteFunction("GetPlayerRank")

local function sanitizeBoard(boardName)
    if type(boardName) == "string" and table.find(LeaderboardService.Boards, boardName) then
        return boardName
    end
    return LeaderboardService.DefaultBoard
end

-- 返回某张排行榜（"wins" / "score"）的前几名；条数由服务端 Config.leaderboard.maxEntries 限制
GetLeaderboard:OnInvoke(function(_player, pageSize, boardName)
    if type(pageSize) ~= "number" or pageSize ~= pageSize then
        pageSize = nil
    end
    return LeaderboardService.GetLeaderboard(pageSize, sanitizeBoard(boardName))
end)

GetPlayerRank:OnInvoke(function(player, boardName)
    return LeaderboardService.GetPlayerRank(player, sanitizeBoard(boardName))
end)

return M
