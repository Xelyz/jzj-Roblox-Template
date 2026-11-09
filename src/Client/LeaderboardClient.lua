-- LeaderboardClient (ModuleScript) - 排行榜界面

local LeaderboardClient = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SignalManager = require(script.Parent.Parent.SignalManager)
local UI = require(script.Parent.ClientUIUtils)

local Colors = UI.Colors
local Fonts = UI.Fonts

-- 远程函数
local GetLeaderboard = SignalManager.GetRemoteFunction("GetLeaderboard")
local GetPlayerRank = SignalManager.GetRemoteFunction("GetPlayerRank")

-- 表格列：表头、宽度占比、对齐
local COLUMNS = {
    { key = "Rank", title = "Rank", width = 0.13 },
    { key = "PlayerName", title = "Player", width = 0.39, align = Enum.TextXAlignment.Left },
    { key = "Wins", title = "Wins", width = 0.15 },
    { key = "Matches", title = "Matches", width = 0.15 },
    { key = "WinRate", title = "Win Rate", width = 0.18 },
}

-- 前三名奖牌色
local MEDAL_COLORS = {
    [1] = Color3.fromRGB(242, 190, 60),
    [2] = Color3.fromRGB(196, 200, 206),
    [3] = Color3.fromRGB(206, 134, 82),
}

local function formatWinRate(totalMatches, winRatio)
    if totalMatches <= 0 then
        return "0.0%"
    end
    return string.format("%.1f%%", winRatio * 100)
end

-- 统一整理一条排行数据
local function normalizeEntry(data)
    data = data or {}
    local totalWins = tonumber(data.totalWins) or 0
    local totalMatches = tonumber(data.totalMatches) or 0
    local winRatio = tonumber(data.winRatio) or 0
    if totalMatches < totalWins then
        totalMatches = totalWins
    end
    if totalMatches > 0 and winRatio == 0 then
        winRatio = totalWins / totalMatches
    end
    return {
        userId = tonumber(data.userId),
        playerName = data.playerName or data.name or "Unknown Player",
        totalWins = totalWins,
        totalMatches = totalMatches,
        winRatio = winRatio,
    }
end

-- 我的排名中的单个数值块
local function createStat(parent, name, title, order)
    local tile = UI.createFrame({
        name = name,
        parent = parent,
        size = UDim2.new(0.25, -12, 1, 0),
        backgroundColor = Colors.Paper,
        corner = true,
        cornerRadius = UDim.new(0, 12),
        stroke = true,
        layoutOrder = order,
    })
    UI.createLabel({
        name = "Title",
        parent = tile,
        text = title,
        position = UDim2.new(0, 0, 0, 8),
        size = UDim2.new(1, 0, 0, 20),
        textSize = 16,
        font = Fonts.Bold,
        textColor = Colors.InkSoft,
    })
    return UI.createLabel({
        name = "Value",
        parent = tile,
        text = "–",
        position = UDim2.new(0, 0, 0, 28),
        size = UDim2.new(1, 0, 1, -34),
        textSize = 32,
        font = Fonts.Display,
        textScaled = true,
    })
end

-- 显示排行榜界面
function LeaderboardClient.ShowLeaderboard()
    local existingGui = LocalPlayer.PlayerGui:FindFirstChild("LeaderboardGui")
    if existingGui then
        existingGui:Destroy()
    end

    local screenGui = UI.createScreen("LeaderboardGui")
    local stage = UI.createStage(screenGui)
    stage.Name = "BackgroundFrame"

    UI.createLabel({
        name = "TitleLabel",
        parent = stage,
        text = "Leaderboard",
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 20),
        size = UDim2.new(0, 600, 0, 60),
        textSize = 50,
        font = Fonts.Display,
        textColor = Colors.Paper,
    })

    local content = UI.createFrame({
        name = "Content",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 92),
        size = UDim2.new(0, 900, 1, -200),
        backgroundTransparency = 1,
    })

    -- 我的排名
    local myRankFrame = UI.createPanel({
        name = "MyRankFrame",
        parent = content,
        size = UDim2.new(1, 0, 0, 132),
        backgroundColor = Colors.Honey,
    })
    UI.createAvatarImage({
        parent = myRankFrame,
        userId = LocalPlayer.UserId,
        position = UDim2.new(0, 18, 0.5, -46),
        size = UDim2.new(0, 92, 0, 92),
        strokeThickness = 3,
    })
    UI.createLabel({
        name = "MyRankTitle",
        parent = myRankFrame,
        text = "My Rank",
        position = UDim2.new(0, 124, 0, 14),
        size = UDim2.new(0, 160, 0, 30),
        textSize = 26,
        font = Fonts.Display,
        textXAlignment = Enum.TextXAlignment.Left,
    })
    -- 旧版的单行汇总文本，加载失败时显示错误
    local myRankInfo = UI.createLabel({
        name = "MyRankInfo",
        parent = myRankFrame,
        text = "Loading...",
        position = UDim2.new(0, 124, 0, 48),
        size = UDim2.new(0, 160, 0, 60),
        textSize = 18,
        font = Fonts.Bold,
        textXAlignment = Enum.TextXAlignment.Left,
        textYAlignment = Enum.TextYAlignment.Top,
    })

    local statsRow = UI.createFrame({
        name = "Stats",
        parent = myRankFrame,
        position = UDim2.new(0, 296, 0, 16),
        size = UDim2.new(1, -312, 1, -32),
        backgroundTransparency = 1,
    })
    UI.addList(statsRow, { direction = Enum.FillDirection.Horizontal, padding = 12 })
    local rankValue = createStat(statsRow, "RankStat", "Rank", 1)
    local winsValue = createStat(statsRow, "WinsStat", "Wins", 2)
    local matchesValue = createStat(statsRow, "MatchesStat", "Matches", 3)
    local rateValue = createStat(statsRow, "WinRateStat", "Win Rate", 4)

    -- 排行榜表格
    local tablePanel = UI.createPanel({
        name = "LeaderboardPanel",
        parent = content,
        position = UDim2.new(0, 0, 0, 152),
        size = UDim2.new(1, 0, 1, -152),
    })

    local headerFrame = UI.createFrame({
        name = "Header",
        parent = tablePanel,
        position = UDim2.new(0, 16, 0, 12),
        size = UDim2.new(1, -32, 0, 40),
        backgroundColor = Colors.PaperDeep,
        corner = true,
    })
    local x = 0
    for i, column in ipairs(COLUMNS) do
        UI.createLabel({
            name = "Header" .. i,
            parent = headerFrame,
            text = column.title,
            position = UDim2.new(x, column.align and 12 or 0, 0, 0),
            size = UDim2.new(column.width, 0, 1, 0),
            textSize = 18,
            font = Fonts.Heavy,
            textXAlignment = column.align or Enum.TextXAlignment.Center,
        })
        x = x + column.width
    end

    local listFrame = UI.createScrollingFrame({
        name = "LeaderboardList",
        parent = tablePanel,
        position = UDim2.new(0, 16, 0, 60),
        size = UDim2.new(1, -24, 1, -72),
        backgroundTransparency = 1,
        listLayout = true,
        listPadding = UDim.new(0, 6),
    })
    UI.addPadding(listFrame, 2, 0)

    local function createLeaderboardEntry(data, index)
        local entry = normalizeEntry(data)
        local isMe = entry.userId == LocalPlayer.UserId

        local entryFrame = UI.createFrame({
            name = "Entry" .. index,
            parent = listFrame,
            size = UDim2.new(1, -10, 0, 52),
            backgroundColor = isMe and Color3.fromRGB(214, 230, 248) or (index % 2 == 0 and Colors.PaperDark or Colors.Paper),
            corner = true,
            layoutOrder = index,
        })
        UI.addStroke(entryFrame, isMe and 3 or 1, isMe and Colors.Blue or Colors.PaperDeep)

        local pos = 0
        -- 名次：前三名使用奖牌圆片
        local rankCell = UI.createFrame({
            name = "RankCell",
            parent = entryFrame,
            position = UDim2.new(pos, 0, 0, 0),
            size = UDim2.new(COLUMNS[1].width, 0, 1, 0),
            backgroundTransparency = 1,
        })
        local rank = UI.createLabel({
            name = "Rank",
            parent = rankCell,
            text = tostring(index),
            anchorPoint = Vector2.new(0.5, 0.5),
            position = UDim2.new(0.5, 0, 0.5, 0),
            size = UDim2.new(0, 38, 0, 38),
            textSize = 22,
            font = Fonts.Display,
            backgroundColor = MEDAL_COLORS[index],
        })
        if MEDAL_COLORS[index] then
            UI.addCorner(rank, UDim.new(1, 0))
            UI.addStroke(rank, 2, Colors.Outline)
        end
        pos = pos + COLUMNS[1].width

        local nameCell = UI.createFrame({
            name = "NameCell",
            parent = entryFrame,
            position = UDim2.new(pos, 0, 0, 0),
            size = UDim2.new(COLUMNS[2].width, 0, 1, 0),
            backgroundTransparency = 1,
        })
        local nameOffset = 12
        if entry.userId then
            UI.createAvatarImage({
                parent = nameCell,
                userId = entry.userId,
                position = UDim2.new(0, 8, 0.5, -18),
                size = UDim2.new(0, 36, 0, 36),
            })
            nameOffset = 54
        end
        UI.createLabel({
            name = "PlayerName",
            parent = nameCell,
            text = entry.playerName .. (isMe and " (You)" or ""),
            position = UDim2.new(0, nameOffset, 0, 0),
            size = UDim2.new(1, -nameOffset - 4, 1, 0),
            textSize = 20,
            font = Fonts.Bold,
            textXAlignment = Enum.TextXAlignment.Left,
            truncate = true,
            textWrapped = false,
        })
        pos = pos + COLUMNS[2].width

        local values = {
            { "Wins", tostring(entry.totalWins) },
            { "Matches", tostring(entry.totalMatches) },
            { "WinRate", formatWinRate(entry.totalMatches, entry.winRatio) },
        }
        for i, value in ipairs(values) do
            local column = COLUMNS[i + 2]
            UI.createLabel({
                name = value[1],
                parent = entryFrame,
                text = value[2],
                position = UDim2.new(pos, 0, 0, 0),
                size = UDim2.new(column.width, 0, 1, 0),
                textSize = 20,
                font = i == 1 and Fonts.Heavy or Fonts.Medium,
            })
            pos = pos + column.width
        end

        return entryFrame
    end

    local function showListMessage(name, text, color)
        UI.createLabel({
            name = name,
            parent = listFrame,
            text = text,
            size = UDim2.new(1, 0, 0, 80),
            textSize = 22,
            font = Fonts.Bold,
            textColor = color,
            layoutOrder = 1,
        })
    end

    local function loadLeaderboard()
        local success, leaderboardData = pcall(function()
            return GetLeaderboard:Invoke()
        end)
        if not listFrame.Parent then
            return
        end

        if success and type(leaderboardData) == "table" then
            if #leaderboardData == 0 then
                showListMessage("EmptyState", "No leaderboard data available", Colors.InkSoft)
                return
            end
            for i, playerData in ipairs(leaderboardData) do
                createLeaderboardEntry(playerData, i)
            end
        else
            warn("LeaderboardClient: Failed to load leaderboard:", leaderboardData)
            showListMessage("ErrorState", "Failed to load leaderboard data", Colors.TextError)
        end
    end

    local function loadMyRank()
        local success, rankData = pcall(function()
            return GetPlayerRank:Invoke()
        end)
        if not myRankInfo.Parent then
            return
        end

        if success and rankData then
            local rank = tonumber(rankData.rank) or 0
            local entry = normalizeEntry(rankData)
            rankValue.Text = rank > 0 and ("#" .. rank) or "–"
            winsValue.Text = tostring(entry.totalWins)
            matchesValue.Text = tostring(entry.totalMatches)
            rateValue.Text = formatWinRate(entry.totalMatches, entry.winRatio)
            myRankInfo.Text = LocalPlayer.DisplayName
        else
            warn("LeaderboardClient: Failed to load player rank:", rankData)
            myRankInfo.Text = "Failed to load rank data"
            myRankInfo.TextColor3 = Colors.TextError
        end
    end

    -- 关闭按钮
    UI.createButton({
        name = "CloseButton",
        text = "Close",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 1),
        position = UDim2.new(0.5, 0, 1, -24),
        size = UDim2.new(0, 260, 0, 66),
        backgroundColor = Colors.Paper,
        onClick = function()
            screenGui:Destroy()
            SignalManager.GetBindable("LeaderboardClosed"):Fire()
        end,
    })

    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    task.spawn(loadMyRank)
    task.spawn(loadLeaderboard)
end

return LeaderboardClient
