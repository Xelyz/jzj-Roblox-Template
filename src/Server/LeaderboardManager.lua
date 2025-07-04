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
    print("Player", player.Name, "requesting leaderboard data")
    pageSize = pageSize or 10
    if pageSize > 50 then
        pageSize = 50 -- 最多返回50名，避免性能问题
    end
    local leaderboardData = LeaderboardService.GetLeaderboard(pageSize)
    print("Returning leaderboard data to", player.Name, ":", #leaderboardData, "entries")
    return leaderboardData
end)

-- 处理获取玩家排名请求
GetPlayerRank:OnInvoke(function(player)
    print("Player", player.Name, "requesting their rank")
    local rankData = LeaderboardService.GetPlayerRank(player)
    if rankData then
        print("Player", player.Name, "rank:", rankData.rank, "wins:", rankData.totalWins)
    else
        print("Could not get rank for player", player.Name)
    end
    return rankData
end)

print("LeaderboardManager initialized and ready to handle requests")

return M 