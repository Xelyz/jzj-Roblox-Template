-- LeaderboardClient (ModuleScript) - 处理排行榜GUI功能

local LeaderboardClient = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 导入SignalManager
local SignalManager = require(script.Parent.Parent.SignalManager)
local UI = require(script.Parent.ClientUIUtils)

-- 远程函数
local GetLeaderboard = SignalManager.GetRemoteFunction("GetLeaderboard")
local GetPlayerRank = SignalManager.GetRemoteFunction("GetPlayerRank")

-- 显示排行榜界面
function LeaderboardClient.ShowLeaderboard()
    -- 清理现有GUI
    local existingGui = LocalPlayer.PlayerGui:FindFirstChild("LeaderboardGui")
    if existingGui then
        existingGui:Destroy()
    end
    
    local screenGui = UI.createScreen("LeaderboardGui")
    local backgroundFrame = UI.createBackground(screenGui)
    UI.createTitle("Leaderboard", backgroundFrame)
    
    -- 我的排名显示区域
    local myRankFrame = UI.createFrame({
        name = "MyRankFrame",
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.12, 0),
        position = UDim2.new(0.1, 0, 0.18, 0),
        backgroundColor = Color3.fromRGB(60, 80, 60),
        borderSize = 2,
        borderColor = UI.Colors.BorderAccent
    })
    
    -- 我的排名标题
    UI.createLabel({
        name = "MyRankTitle",
        text = "My Rank",
        parent = myRankFrame,
        size = UDim2.new(1, 0, 0.4, 0),
        position = UDim2.new(0, 0, 0.1, 0),
        textSize = 20,
        font = Enum.Font.SourceSansBold,
        transparent = true
    })
    
    -- 我的排名信息
    local myRankInfo = UI.createLabel({
        name = "MyRankInfo",
        text = "Loading...",
        parent = myRankFrame,
        size = UDim2.new(1, 0, 0.4, 0),
        position = UDim2.new(0, 0, 0.5, 0),
        textSize = 16,
        textColor = Color3.fromRGB(220, 220, 220),
        transparent = true
    })
    
    -- 排行榜列表容器
    local listFrame = UI.createScrollingFrame({
        name = "LeaderboardList",
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.5, 0),
        position = UDim2.new(0.1, 0, 0.33, 0),
        listLayout = true,
        listPadding = UDim.new(0, 2),
        cornerRadius = UDim.new(0, 8)
    })
    
    -- 排行榜表头
    local headerFrame = UI.createFrame({
        name = "Header",
        parent = listFrame,
        size = UDim2.new(1, 0, 0, 40),
        backgroundColor = Color3.fromRGB(50, 50, 60),
        borderSize = 1,
        borderColor = UI.Colors.BorderAccent
    })
    headerFrame.LayoutOrder = 0
    
    -- 表头标签
    local headers = {"Rank", "Player", "Wins", "Matches", "Win Rate"}
    local headerWidths = {0.15, 0.35, 0.15, 0.15, 0.2}
    
    -- 计算表头位置
    local currentPosition = 0
    for i, headerText in ipairs(headers) do
        UI.createLabel({
            name = "Header" .. i,
            text = headerText,
            parent = headerFrame,
            size = UDim2.new(headerWidths[i], 0, 1, 0),
            position = UDim2.new(currentPosition, 0, 0, 0),
            textSize = 14,
            font = Enum.Font.SourceSansBold,
            transparent = true
        })
        
        currentPosition = currentPosition + headerWidths[i]
    end
    
    -- 创建排行榜条目的函数
    local function createLeaderboardEntry(data, index)
        -- 数据验证和默认值设置
        if not data then
            print("LeaderboardClient: Warning - Received nil data for entry", index)
            data = {}
        end
        
        local playerName = data.playerName or data.name or "Unknown Player"
        local totalWins = tonumber(data.totalWins) or 0
        local totalMatches = tonumber(data.totalMatches) or 0
        local winRatio = tonumber(data.winRatio) or 0
        
        -- 确保数据的逻辑一致性
        if totalMatches < totalWins then
            totalMatches = totalWins -- 修正不合理的数据
        end
        if totalMatches > 0 and winRatio == 0 then
            winRatio = totalWins / totalMatches -- 重新计算胜率
        end
        
        print("LeaderboardClient: Creating entry", index, "for", playerName, "- Wins:", totalWins, "Matches:", totalMatches, "WinRatio:", winRatio)
        
        local entryFrame = UI.createFrame({
            name = "Entry" .. index,
            parent = listFrame,
            size = UDim2.new(1, 0, 0, 40),
            backgroundColor = index % 2 == 0 and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(40, 40, 50),
            borderSize = 1,
            borderColor = UI.Colors.BorderAccent
        })
        entryFrame.LayoutOrder = index
        
        -- 使用与表头匹配的宽度和位置
        local currentPos = 0
        
        -- 排名 (15%宽度)
        UI.createLabel({
            name = "Rank",
            text = tostring(index),
            parent = entryFrame,
            size = UDim2.new(headerWidths[1], 0, 1, 0),
            position = UDim2.new(currentPos, 0, 0, 0),
            textColor = UI.Colors.TextWhite,
            textSize = 16,
            font = Enum.Font.SourceSansBold,
            transparent = true
        })
        currentPos = currentPos + headerWidths[1]
        
        -- 玩家名 (35%宽度)
        UI.createLabel({
            name = "PlayerName",
            text = playerName,
            parent = entryFrame,
            size = UDim2.new(headerWidths[2], 0, 1, 0),
            position = UDim2.new(currentPos, 0, 0, 0),
            textColor = UI.Colors.TextWhite,
            textSize = 16,
            font = Enum.Font.SourceSans,
            transparent = true
        })
        currentPos = currentPos + headerWidths[2]
        
        -- 胜场数 (15%宽度)
        UI.createLabel({
            name = "Wins",
            text = tostring(totalWins),
            parent = entryFrame,
            size = UDim2.new(headerWidths[3], 0, 1, 0),
            position = UDim2.new(currentPos, 0, 0, 0),
            textColor = UI.Colors.TextWhite,
            textSize = 16,
            font = Enum.Font.SourceSans,
            transparent = true
        })
        currentPos = currentPos + headerWidths[3]
        
        -- 总场数 (15%宽度)
        UI.createLabel({
            name = "Matches",
            text = tostring(totalMatches),
            parent = entryFrame,
            size = UDim2.new(headerWidths[4], 0, 1, 0),
            position = UDim2.new(currentPos, 0, 0, 0),
            textColor = UI.Colors.TextWhite,
            textSize = 16,
            font = Enum.Font.SourceSans,
            transparent = true
        })
        currentPos = currentPos + headerWidths[4]
        
        -- 胜率 (20%宽度)
        local winRateText = "0.0%"
        if totalMatches > 0 then
            winRateText = string.format("%.1f%%", winRatio * 100)
        end
        
        UI.createLabel({
            name = "WinRate",
            text = winRateText,
            parent = entryFrame,
            size = UDim2.new(headerWidths[5], 0, 1, 0),
            position = UDim2.new(currentPos, 0, 0, 0),
            textColor = UI.Colors.TextWhite,
            textSize = 16,
            font = Enum.Font.SourceSans,
            transparent = true
        })
        
        return entryFrame
    end
    
    -- 加载排行榜数据
    local function loadLeaderboard()
        print("LeaderboardClient: Starting to load leaderboard data...")
        
        local success, leaderboardData = pcall(function()
            return GetLeaderboard:Invoke()
        end)
        
        if success and leaderboardData then
            print("LeaderboardClient: Received leaderboard data with", #leaderboardData, "entries")
            
            -- 验证数据是否为表格
            if type(leaderboardData) ~= "table" then
                print("LeaderboardClient: Error - leaderboardData is not a table, type:", type(leaderboardData))
                return
            end
            
            -- 如果没有数据，显示空状态
            if #leaderboardData == 0 then
                print("LeaderboardClient: No leaderboard data available")
                local emptyLabel = UI.createLabel({
                    name = "EmptyState",
                    text = "No leaderboard data available",
                    parent = listFrame,
                    size = UDim2.new(1, 0, 0, 40),
                    textColor = UI.Colors.TextGray,
                    textSize = 16,
                    transparent = true
                })
                emptyLabel.LayoutOrder = 1
                return
            end
            
            for i, playerData in ipairs(leaderboardData) do
                print("LeaderboardClient: Processing entry", i, "- Raw data:", playerData)
                createLeaderboardEntry(playerData, i)
            end
            
            -- 更新滚动区域大小
            if listFrame.UIListLayout then
                listFrame.CanvasSize = UDim2.new(0, 0, 0, listFrame.UIListLayout.AbsoluteContentSize.Y)
            end
        else
            print("LeaderboardClient: Failed to load leaderboard. Success:", success, "Error:", leaderboardData)
            
            -- 显示错误状态
            local errorLabel = UI.createLabel({
                name = "ErrorState",
                text = "Failed to load leaderboard data",
                parent = listFrame,
                size = UDim2.new(1, 0, 0, 40),
                textColor = UI.Colors.TextRed,
                textSize = 16,
                transparent = true
            })
            errorLabel.LayoutOrder = 1
        end
    end
    
    -- 加载我的排名
    local function loadMyRank()
        print("LeaderboardClient: Starting to load player rank...")
        
        local success, rankData = pcall(function()
            return GetPlayerRank:Invoke()
        end)
        
        if success and rankData then
            print("LeaderboardClient: Received rank data:", rankData)
            
            -- 验证数据
            local rank = tonumber(rankData.rank) or 0
            local totalWins = tonumber(rankData.totalWins) or 0
            local totalMatches = tonumber(rankData.totalMatches) or 0
            local winRatio = tonumber(rankData.winRatio) or 0
            
            local rankText = string.format("Rank: #%d | Wins: %d | Matches: %d | Win Rate: %.1f%%",
                rank, totalWins, totalMatches, winRatio * 100)
            myRankInfo.Text = rankText
        else
            print("LeaderboardClient: Failed to load player rank. Success:", success, "Error:", rankData)
            myRankInfo.Text = "Failed to load rank data"
            myRankInfo.TextColor3 = UI.Colors.TextRed
        end
    end
    
    -- 关闭按钮
    UI.createButton({
        name = "CloseButton",
        text = "Close",
        parent = backgroundFrame,
        size = UDim2.new(0.2, 0, 0.08, 0),
        position = UDim2.new(0.4, 0, 0.88, 0),
        backgroundColor = UI.Colors.ButtonGray,
        cornerRadius = UDim.new(0, 6),
        onClick = function()
            screenGui:Destroy()
            
            -- 触发关闭事件通知RoomClient
            local LeaderboardClosed = SignalManager.GetBindable("LeaderboardClosed")
            LeaderboardClosed:Fire()
        end
    })
    
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- 加载数据
    loadMyRank()
    loadLeaderboard()
    
    print("LeaderboardClient: Leaderboard GUI created and data loading initiated")
end

return LeaderboardClient