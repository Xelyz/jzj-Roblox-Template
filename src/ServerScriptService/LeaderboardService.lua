-- LeaderboardService: 管理玩家胜场统计和排行榜数据

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

-- 检查是否在Studio开发环境
local RunService = game:GetService("RunService")
local isStudio = RunService:IsStudio()

-- 数据存储 (带错误处理)
local playerStatsStore = nil
local leaderboardStore = nil

-- 开发模式的内存存储
local devModePlayerStats = {}
local devModeLeaderboard = {}

-- 初始化数据存储
local function initializeDataStores()
    if isStudio then
        print("Warning: Running in Studio mode - using memory storage instead of DataStore")
        return
    end
    
    local success, error = pcall(function()
        playerStatsStore = DataStoreService:GetDataStore("PlayerStats")
        leaderboardStore = DataStoreService:GetOrderedDataStore("WinsLeaderboard")
    end)
    
    if not success then
        print("Warning: DataStore unavailable, using memory storage:", error)
        playerStatsStore = nil
        leaderboardStore = nil
    end
end

-- 调用初始化
initializeDataStores()

-- 内存中的玩家统计缓存
local playerStatsCache = {}

-- 默认玩家数据结构
local function getDefaultPlayerData()
    return {
        totalWins = 0,
        totalMatches = 0,
        winRatio = 0,
        lastUpdated = tick()
    }
end

-- 更新玩家的Roblox leaderstats
local function updatePlayerLeaderstats(player, playerData)
    if not player or not playerData then 
        print("Warning: updatePlayerLeaderstats called with nil player or playerData")
        return 
    end
    
    print("Updating leaderstats for player:", player.Name, "Wins:", playerData.totalWins, "Matches:", playerData.totalMatches)
    
    -- 确保玩家有leaderstats文件夹
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
        print("Created leaderstats folder for", player.Name)
    end
    
    -- 胜场数
    local wins = leaderstats:FindFirstChild("Wins")
    if not wins then
        wins = Instance.new("IntValue")
        wins.Name = "Wins"
        wins.Parent = leaderstats
        print("Created Wins IntValue for", player.Name)
    end
    wins.Value = playerData.totalWins
    
    -- 胜率 (显示为百分比)
    local winRate = leaderstats:FindFirstChild("WinRate")
    if not winRate then
        winRate = Instance.new("StringValue")
        winRate.Name = "WinRate"
        winRate.Parent = leaderstats
        print("Created WinRate StringValue for", player.Name)
    end
    winRate.Value = string.format("%.1f%%", (playerData.winRatio or 0) * 100)
    
    print("Successfully updated leaderstats for", player.Name, "- Wins:", wins.Value, "WinRate:", winRate.Value)
end

-- 加载玩家数据
function LeaderboardService.LoadPlayerStats(player)
    if not player then 
        print("Warning: LoadPlayerStats called with nil player")
        return nil 
    end
    
    print("Loading player stats for:", player.Name, "UserId:", player.UserId)
    
    local userId = tostring(player.UserId)
    
    -- 如果已在缓存中，直接返回
    if playerStatsCache[userId] then
        print("Found cached stats for", player.Name, ":", playerStatsCache[userId].totalWins, "wins")
        updatePlayerLeaderstats(player, playerStatsCache[userId])
        return playerStatsCache[userId]
    end
    
    local data = nil
    
    if playerStatsStore then
        -- 生产模式：使用DataStore
        print("Loading from DataStore for", player.Name)
        local loadSuccess, result = pcall(function()
            return playerStatsStore:GetAsync(userId)
        end)
        
        if loadSuccess then
            data = result
            print("DataStore load successful for", player.Name, "Data:", data)
        else
            print("DataStore load failed for", player.Name)
        end
    else
        -- 开发模式：使用内存存储
        print("Loading from dev mode storage for", player.Name)
        data = devModePlayerStats[userId]
    end
    
    if data then
        playerStatsCache[userId] = data
        print("Loaded stats for player", player.Name, ":", data.totalWins, "wins")
    else
        -- 创建新玩家数据
        local newData = getDefaultPlayerData()
        playerStatsCache[userId] = newData
        print("Created new stats for player", player.Name)
        data = newData
    end
    
    -- 初始化或更新Roblox leaderstats
    print("Calling updatePlayerLeaderstats for", player.Name)
    updatePlayerLeaderstats(player, playerStatsCache[userId])
    
    return playerStatsCache[userId]
end

-- 保存玩家数据
function LeaderboardService.SavePlayerStats(player, playerData)
    if not player or not playerData then return false end
    
    local userId = tostring(player.UserId)
    playerData.lastUpdated = tick()
    
    -- 更新缓存
    playerStatsCache[userId] = playerData
    
    if playerStatsStore and leaderboardStore then
        -- 生产模式：使用DataStore
        local saveSuccess = pcall(function()
            -- 保存到普通DataStore
            playerStatsStore:SetAsync(userId, playerData)
            -- 同时更新排行榜OrderedDataStore
            leaderboardStore:SetAsync(userId, playerData.totalWins)
        end)
        
        if saveSuccess then
            print("Saved stats for player", player.Name, ":", playerData.totalWins, "wins")
            return true
        else
            print("Failed to save stats for player", player.Name)
            return false
        end
    else
        -- 开发模式：使用内存存储
        devModePlayerStats[userId] = playerData
        devModeLeaderboard[userId] = playerData.totalWins
        print("Saved stats (dev mode) for player", player.Name, ":", playerData.totalWins, "wins")
        return true
    end
end

-- 通用的记录匹配结果函数
local function recordMatchResult(player, isWin)
    if not player then return false end
    
    local playerData = LeaderboardService.LoadPlayerStats(player)
    if not playerData then return false end
    
    -- 更新统计数据
    if isWin then
        playerData.totalWins = playerData.totalWins + 1
    end
    playerData.totalMatches = playerData.totalMatches + 1
    playerData.winRatio = playerData.totalWins / playerData.totalMatches
    
    -- 更新Roblox leaderstats
    updatePlayerLeaderstats(player, playerData)
    
    return LeaderboardService.SavePlayerStats(player, playerData)
end

-- 记录玩家胜利
function LeaderboardService.RecordWin(player)
    return recordMatchResult(player, true)
end

-- 记录玩家败局
function LeaderboardService.RecordLoss(player)
    return recordMatchResult(player, false)
end

-- 获取排行榜数据
function LeaderboardService.GetLeaderboard(pageSize)
    pageSize = pageSize or 10 -- 默认返回前10名
    local leaderboardData = {}
    
    if leaderboardStore then
        -- 生产模式：使用DataStore
        local leaderboardSuccess, pages = pcall(function()
            return leaderboardStore:GetSortedAsync(false, pageSize)
        end)
        
        if not leaderboardSuccess then
            print("Failed to get leaderboard data")
            return {}
        end
        
        local currentPage = pages:GetCurrentPage()
        
        for rank, data in ipairs(currentPage) do
            local userId = tonumber(data.key)
            local wins = data.value
            
            -- 获取玩家姓名
            local nameSuccess, playerName = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            
            if nameSuccess and playerName then
                -- 获取完整的玩家统计数据
                local playerStats = nil
                local statsSuccess = pcall(function()
                    playerStats = playerStatsStore:GetAsync(tostring(userId))
                end)
                
                if statsSuccess and playerStats then
                    table.insert(leaderboardData, {
                        rank = rank,
                        userId = userId,
                        playerName = playerName,
                        totalWins = wins,
                        totalMatches = playerStats.totalMatches or 0,
                        winRatio = playerStats.winRatio or 0
                    })
                else
                    -- 如果无法获取详细统计，只显示基本信息
                    table.insert(leaderboardData, {
                        rank = rank,
                        userId = userId,
                        playerName = playerName,
                        totalWins = wins,
                        totalMatches = wins, -- 默认值
                        winRatio = 1.0 -- 默认值
                    })
                end
            end
        end
    else
        -- 开发模式：使用内存存储
        print("Using dev mode leaderboard")
        
        -- 转换内存排行榜为排序数组
        local sortedPlayers = {}
        for userId, wins in pairs(devModeLeaderboard) do
            local player = Players:GetPlayerByUserId(tonumber(userId))
            local playerName = player and player.Name or "Unknown"
            
            local playerStats = devModePlayerStats[userId] or getDefaultPlayerData()
            
            table.insert(sortedPlayers, {
                userId = tonumber(userId),
                playerName = playerName,
                totalWins = wins,
                totalMatches = playerStats.totalMatches or 0,
                winRatio = playerStats.winRatio or 0
            })
        end
        
        -- 按胜场数排序
        table.sort(sortedPlayers, function(a, b)
            return a.totalWins > b.totalWins
        end)
        
        -- 添加排名并限制数量
        for i = 1, math.min(pageSize, #sortedPlayers) do
            sortedPlayers[i].rank = i
            table.insert(leaderboardData, sortedPlayers[i])
        end
    end
    
    print("Retrieved leaderboard data for", #leaderboardData, "players")
    return leaderboardData
end

-- 获取玩家在排行榜中的排名
function LeaderboardService.GetPlayerRank(player)
    if not player then return nil end
    
    local playerData = LeaderboardService.LoadPlayerStats(player)
    if not playerData then return nil end
    
    local userId = tostring(player.UserId)
    local wins = playerData.totalWins
    
    if leaderboardStore then
        -- 生产模式：使用DataStore
        local rankSuccess, pages = pcall(function()
            return leaderboardStore:GetSortedAsync(false, 100) -- 获取前100名来计算排名
        end)
        
        if not rankSuccess then
            print("Failed to get player rank for", player.Name)
            return nil
        end
        
        local currentPage = pages:GetCurrentPage()
        for rank, data in ipairs(currentPage) do
            if data.key == userId then
                return {
                    rank = rank,
                    totalWins = wins,
                    totalMatches = playerData.totalMatches,
                    winRatio = playerData.winRatio
                }
            end
        end
        
        -- 如果在前100名中没找到，返回默认排名
        return {
            rank = 999,
            totalWins = wins,
            totalMatches = playerData.totalMatches,
            winRatio = playerData.winRatio
        }
    else
        -- 开发模式：使用内存存储
        local sortedPlayers = {}
        for uid, uWins in pairs(devModeLeaderboard) do
            table.insert(sortedPlayers, {userId = uid, wins = uWins})
        end
        
        -- 按胜场数排序
        table.sort(sortedPlayers, function(a, b)
            return a.wins > b.wins
        end)
        
        -- 查找玩家排名
        for rank, data in ipairs(sortedPlayers) do
            if data.userId == userId then
                return {
                    rank = rank,
                    totalWins = wins,
                    totalMatches = playerData.totalMatches,
                    winRatio = playerData.winRatio
                }
            end
        end
        
        -- 如果没找到，返回默认排名
        return {
            rank = #sortedPlayers + 1,
            totalWins = wins,
            totalMatches = playerData.totalMatches,
            winRatio = playerData.winRatio
        }
    end
end

-- 初始化服务时为所有在线玩家加载数据
function LeaderboardService.Initialize()
    print("=== Initializing LeaderboardService ===")
    print("Studio mode:", isStudio, "DataStore available:", playerStatsStore ~= nil, leaderboardStore ~= nil)
    
    local currentPlayers = Players:GetPlayers()
    print("Found", #currentPlayers, "current players to initialize")
    
    for _, player in pairs(currentPlayers) do
        print("Initializing stats for existing player:", player.Name)
        LeaderboardService.LoadPlayerStats(player)
    end
    
    -- 监听新玩家加入
    print("Setting up PlayerAdded listener")
    Players.PlayerAdded:Connect(function(player)
        print("=== New player joined:", player.Name, "===")
        -- 延迟一点确保玩家完全加载
        task.wait(1)
        LeaderboardService.LoadPlayerStats(player)
    end)
    
    -- 监听玩家离开时保存数据
    print("Setting up PlayerRemoving listener")
    Players.PlayerRemoving:Connect(function(player)
        print("=== Player leaving:", player.Name, "===")
        local userId = tostring(player.UserId)
        if playerStatsCache[userId] then
            print("Saving stats for leaving player:", player.Name)
            LeaderboardService.SavePlayerStats(player, playerStatsCache[userId])
            playerStatsCache[userId] = nil
        else
            print("No cached stats found for leaving player:", player.Name)
        end
    end)
    
    print("=== LeaderboardService initialized successfully ===")
end

-- 启动服务
LeaderboardService.Initialize()

return LeaderboardService 