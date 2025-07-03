-- LeaderboardClient (ModuleScript) - 处理排行榜GUI功能

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 等待远程函数
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetLeaderboard = Remotes:WaitForChild("GetLeaderboard")
local GetPlayerRank = Remotes:WaitForChild("GetPlayerRank")

local UI = require(game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("UIUtils"))

local LeaderboardClient = {}

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
        listPadding = UDim.new(0, 2)
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
    local function createLeaderboardEntry(parent, index, data)
        local entryFrame = UI.createFrame({
            name = "Entry" .. index,
            parent = parent,
            size = UDim2.new(1, 0, 0, 35),
            backgroundColor = index % 2 == 0 and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(40, 40, 50),
            borderSize = 1,
            borderColor = UI.Colors.Border
        })
        entryFrame.LayoutOrder = index
        
        -- 排名颜色
        local rankColor = UI.Colors.TextWhite
        if index == 1 then
            rankColor = UI.Colors.TextYellow -- 金色
        elseif index == 2 then
            rankColor = Color3.fromRGB(192, 192, 192) -- 银色
        elseif index == 3 then
            rankColor = Color3.fromRGB(205, 127, 50) -- 铜色
        end
        
        -- 排名
        UI.createLabel({
            name = "RankLabel",
            text = "#" .. tostring(index),
            parent = entryFrame,
            size = UDim2.new(0.15, 0, 1, 0),
            position = UDim2.new(0, 0, 0, 0),
            textSize = 14,
            textColor = rankColor,
            font = Enum.Font.SourceSansBold,
            transparent = true
        })
        
        -- 玩家名称
        UI.createLabel({
            name = "NameLabel",
            text = data.displayName or data.name or "Unknown",
            parent = entryFrame,
            size = UDim2.new(0.35, 0, 1, 0),
            position = UDim2.new(0.15, 0, 0, 0),
            textSize = 14,
            textColor = data.userId == LocalPlayer.UserId and UI.Colors.TextGreen or UI.Colors.TextWhite,
            transparent = true
        })
        
        -- 胜场数
        UI.createLabel({
            name = "WinsLabel",
            text = tostring(data.wins or 0),
            parent = entryFrame,
            size = UDim2.new(0.15, 0, 1, 0),
            position = UDim2.new(0.5, 0, 0, 0),
            textSize = 14,
            textColor = UI.Colors.TextGreen,
            transparent = true
        })
        
        -- 总场次
        UI.createLabel({
            name = "MatchesLabel",
            text = tostring(data.totalMatches),
            parent = entryFrame,
            size = UDim2.new(0.15, 0, 1, 0),
            position = UDim2.new(0.65, 0, 0, 0),
            textSize = 14,
            textColor = UI.Colors.TextGray,
            transparent = true
        })
        
        -- 胜率
        UI.createLabel({
            name = "RatioLabel",
            text = string.format("%.1f%%", (data.winRatio or 0) * 100),
            parent = entryFrame,
            size = UDim2.new(0.2, 0, 1, 0),
            position = UDim2.new(0.8, 0, 0, 0),
            textSize = 14,
            textColor = UI.Colors.TextYellow,
            transparent = true
        })
    end
    
    -- 加载排行榜数据
    local function loadLeaderboard()
        local success, leaderboardData = pcall(function()
            return GetLeaderboard:InvokeServer()
        end)
        
        if success and leaderboardData then
            for i, playerData in ipairs(leaderboardData) do
                createLeaderboardEntry(listFrame, i, playerData)
            end
            
            -- 更新滚动区域大小
            listFrame.CanvasSize = UDim2.new(0, 0, 0, listFrame.UIListLayout.AbsoluteContentSize.Y)
        else
            print("Failed to load leaderboard:", leaderboardData)
        end
    end
    
    -- 加载我的排名
    local function loadMyRank()
        local success, rankData = pcall(function()
            return GetPlayerRank:InvokeServer()
        end)
        
        if success and rankData then
            local rankText = string.format("Rank: #%d | Wins: %d | Matches: %d | Win Rate: %.1f%%",
                rankData.rank or 0,
                rankData.wins or 0,
                rankData.totalMatches or 0,
                (rankData.winRatio or 0) * 100
            )
            myRankInfo.Text = rankText
        else
            myRankInfo.Text = "Failed to load rank data"
            print("Failed to load player rank:", rankData)
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
        onClick = function()
            screenGui:Destroy()
            
            -- 触发关闭事件通知RoomClient
            local Events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Client")
            local LeaderboardClosed = Events:FindFirstChild("LeaderboardClosed")
            if LeaderboardClosed then
                LeaderboardClosed:Fire()
            end
        end
    })
    
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- 加载数据
    loadMyRank()
    loadLeaderboard()
    
    print("Leaderboard GUI created")
end

return LeaderboardClient