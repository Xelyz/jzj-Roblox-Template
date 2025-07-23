local M = {}

-- LeaderboardManager (Server) - 处理排行榜相关的远程调用

-- 导入SignalManager
local SignalManager = require(script.Parent.Parent.SignalManager)
local LeaderboardService = require(script.Parent.LeaderboardServiceServer)

-- 远程函数
local GetLeaderboard = SignalManager.GetRemoteFunction("GetLeaderboard")
local GetPlayerRank = SignalManager.GetRemoteFunction("GetPlayerRank")

-- 处理获取排行榜请求
GetLeaderboard:OnInvoke(function(player, pageSize)
    print("LeaderboardManager: Player", player.Name, "requesting leaderboard data with pageSize:", pageSize)
    pageSize = pageSize or 10
    if pageSize > 50 then
        pageSize = 50 -- 最多返回50名，避免性能问题
        print("LeaderboardManager: Limited pageSize to 50 for", player.Name)
    end
    
    local leaderboardData = LeaderboardService.GetLeaderboard(pageSize)
    
    -- 详细日志记录返回的数据
    print("LeaderboardManager: Returning leaderboard data to", player.Name, "with", #leaderboardData, "entries")
    for i, data in ipairs(leaderboardData) do
        print("LeaderboardManager: Entry", i, "- Player:", data.playerName, "Wins:", data.totalWins, "Matches:", data.totalMatches, "WinRatio:", data.winRatio)
    end
    
    return leaderboardData
end)

-- 处理获取玩家排名请求
GetPlayerRank:OnInvoke(function(player)
    print("LeaderboardManager: Player", player.Name, "requesting their rank")
    local rankData = LeaderboardService.GetPlayerRank(player)
    if rankData then
        print("LeaderboardManager: Player", player.Name, "rank data - Rank:", rankData.rank, "Wins:", rankData.totalWins, "Matches:", rankData.totalMatches, "WinRatio:", rankData.winRatio)
    else
        print("LeaderboardManager: Could not get rank for player", player.Name)
    end
    return rankData
end)

print("LeaderboardManager: Initialized and ready to handle requests")

return M 