-- LeaderboardManager (Server) - 处理排行榜相关的远程调用

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaderboardService = require(game.ServerScriptService:WaitForChild("LeaderboardService"))

-- 等待远程函数
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetLeaderboard = Remotes:WaitForChild("GetLeaderboard")
local GetPlayerRank = Remotes:WaitForChild("GetPlayerRank")

-- 处理获取排行榜请求
GetLeaderboard.OnServerInvoke = function(player, pageSize)
    print("Player", player.Name, "requesting leaderboard data")
    
    -- 设置页面大小限制
    pageSize = pageSize or 10
    if pageSize > 50 then
        pageSize = 50 -- 最多返回50名，避免性能问题
    end
    
    local leaderboardData = LeaderboardService.GetLeaderboard(pageSize)
    
    print("Returning leaderboard data to", player.Name, ":", #leaderboardData, "entries")
    return leaderboardData
end

-- 处理获取玩家排名请求
GetPlayerRank.OnServerInvoke = function(player)
    print("Player", player.Name, "requesting their rank")
    
    local rankData = LeaderboardService.GetPlayerRank(player)
    
    if rankData then
        print("Player", player.Name, "rank:", rankData.rank, "wins:", rankData.totalWins)
    else
        print("Could not get rank for player", player.Name)
    end
    
    return rankData
end

-- LeaderboardService 已在其自身模块中自动初始化

print("LeaderboardManager initialized and ready to handle requests") 