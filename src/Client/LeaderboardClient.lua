-- LeaderboardClient (ModuleScript) - 排行榜界面（胜场榜 / 最高分榜）

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
        bestScore = tonumber(data.bestScore) or 0,
    }
end

-- 每张榜的显示方式：页签名、表格列、"我的排名"中的四个数值块
local BOARD_ORDER = { "wins", "score" }
local BOARD_VIEWS = {
    wins = {
        tab = "Wins",
        empty = "No multiplayer wins recorded yet",
        columns = {
            { title = "Rank", width = 0.13 },
            { title = "Player", width = 0.39, align = Enum.TextXAlignment.Left },
            { title = "Wins", width = 0.15 },
            { title = "Matches", width = 0.15 },
            { title = "Win Rate", width = 0.18 },
        },
        values = function(entry)
            return {
                { "Wins", tostring(entry.totalWins) },
                { "Matches", tostring(entry.totalMatches) },
                { "WinRate", formatWinRate(entry.totalMatches, entry.winRatio) },
            }
        end,
        stats = { "Rank", "Wins", "Matches", "Win Rate" },
    },
    score = {
        tab = "High Score",
        empty = "No scores recorded yet",
        columns = {
            { title = "Rank", width = 0.13 },
            { title = "Player", width = 0.57, align = Enum.TextXAlignment.Left },
            { title = "Best Score", width = 0.30 },
        },
        values = function(entry)
            return {
                { "BestScore", tostring(entry.bestScore) },
            }
        end,
        stats = { "Rank", "Best Score", "Wins", "Win Rate" },
    },
}

local function formatStat(statName, rankData, entry)
    if statName == "Rank" then
        local rank = tonumber(rankData.rank) or 0
        local rankBeyond = tonumber(rankData.rankBeyond) or 0
        if rank > 0 then
            return "#" .. rank
        elseif rankBeyond > 0 then
            return "#" .. rankBeyond .. "+"
        end
        return "–"
    elseif statName == "Wins" then
        return tostring(entry.totalWins)
    elseif statName == "Matches" then
        return tostring(entry.totalMatches)
    elseif statName == "Win Rate" then
        return formatWinRate(entry.totalMatches, entry.winRatio)
    elseif statName == "Best Score" then
        return tostring(entry.bestScore)
    end
    return "–"
end

-- 我的排名中的单个数值块，返回 (标题, 数值) 两个标签
local function createStat(parent, name, order)
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
    local title = UI.createLabel({
        name = "Title",
        parent = tile,
        text = "",
        position = UDim2.new(0, 0, 0, 8),
        size = UDim2.new(1, 0, 0, 20),
        textSize = 16,
        font = Fonts.Bold,
        textColor = Colors.InkSoft,
    })
    local value = UI.createLabel({
        name = "Value",
        parent = tile,
        text = "–",
        position = UDim2.new(0, 0, 0, 28),
        size = UDim2.new(1, 0, 1, -34),
        textSize = 32,
        font = Fonts.Display,
        textScaled = true,
    })
    return title, value
end

-- 显示排行榜界面
function LeaderboardClient.ShowLeaderboard(initialBoard)
    local existingGui = LocalPlayer.PlayerGui:FindFirstChild("LeaderboardGui")
    if existingGui then
        existingGui:Destroy()
    end

    local currentBoard = BOARD_VIEWS[initialBoard] and initialBoard or BOARD_ORDER[1]
    local requestToken = 0
    -- 界面打开期间缓存每张榜的数据，切换页签不重复请求
    local cache = {}

    local screenGui = UI.createScreen("LeaderboardGui")
    local stage = UI.createStage(screenGui)
    stage.Name = "BackgroundFrame"

    UI.createLabel({
        name = "TitleLabel",
        parent = stage,
        text = "Leaderboard",
        position = UDim2.new(0.5, -450, 0, 20),
        size = UDim2.new(0, 420, 0, 60),
        textSize = 50,
        font = Fonts.Display,
        textColor = Colors.Paper,
        textXAlignment = Enum.TextXAlignment.Left,
    })

    -- 页签
    local tabBar = UI.createFrame({
        name = "Tabs",
        parent = stage,
        anchorPoint = Vector2.new(1, 0),
        position = UDim2.new(0.5, 450, 0, 24),
        size = UDim2.new(0, 400, 0, 56),
        backgroundTransparency = 1,
    })
    UI.addList(tabBar, {
        direction = Enum.FillDirection.Horizontal,
        padding = 12,
        horizontalAlignment = Enum.HorizontalAlignment.Right,
    })
    local tabButtons = {}

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
    -- 玩家名；加载失败时显示错误
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
    local statTiles = {}
    for i = 1, 4 do
        local title, value = createStat(statsRow, "Stat" .. i, i)
        statTiles[i] = { title = title, value = value }
    end

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
    local headerColumns = UI.createFrame({
        name = "Columns",
        parent = headerFrame,
        size = UDim2.new(1, 0, 1, 0),
        backgroundTransparency = 1,
    })

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

    local function clearList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
    end

    local function buildHeader(view)
        headerColumns:ClearAllChildren()
        local x = 0
        for i, column in ipairs(view.columns) do
            UI.createLabel({
                name = "Header" .. i,
                parent = headerColumns,
                text = column.title,
                position = UDim2.new(x, column.align and 12 or 0, 0, 0),
                size = UDim2.new(column.width, 0, 1, 0),
                textSize = 18,
                font = Fonts.Heavy,
                textXAlignment = column.align or Enum.TextXAlignment.Center,
            })
            x = x + column.width
        end
    end

    local function createLeaderboardEntry(view, data, index)
        local columns = view.columns
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
            size = UDim2.new(columns[1].width, 0, 1, 0),
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
        pos = pos + columns[1].width

        local nameCell = UI.createFrame({
            name = "NameCell",
            parent = entryFrame,
            position = UDim2.new(pos, 0, 0, 0),
            size = UDim2.new(columns[2].width, 0, 1, 0),
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
        pos = pos + columns[2].width

        for i, value in ipairs(view.values(entry)) do
            local column = columns[i + 2]
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

    local function renderList(view, data)
        clearList()
        if data.ok then
            if #data.list == 0 then
                showListMessage("EmptyState", view.empty, Colors.InkSoft)
                return
            end
            for i, playerData in ipairs(data.list) do
                createLeaderboardEntry(view, playerData, i)
            end
        else
            showListMessage("ErrorState", "Failed to load leaderboard data", Colors.TextError)
        end
    end

    local function renderMyRank(view, data)
        if data.ok then
            local entry = normalizeEntry(data.rank)
            for i, statName in ipairs(view.stats) do
                statTiles[i].value.Text = formatStat(statName, data.rank, entry)
            end
            myRankInfo.Text = LocalPlayer.DisplayName
            myRankInfo.TextColor3 = Colors.Ink
        else
            for _, tile in ipairs(statTiles) do
                tile.value.Text = "–"
            end
            myRankInfo.Text = "Failed to load rank data"
            myRankInfo.TextColor3 = Colors.TextError
        end
    end

    local function fetchBoard(boardName)
        local entry = cache[boardName]
        if entry then
            return entry
        end
        entry = { listDone = false, rankDone = false }
        cache[boardName] = entry

        task.spawn(function()
            local ok, result = pcall(function()
                return GetLeaderboard:Invoke(nil, boardName)
            end)
            if not ok or type(result) ~= "table" then
                warn("LeaderboardClient: Failed to load leaderboard:", result)
            end
            entry.list = { ok = ok and type(result) == "table", list = type(result) == "table" and result or {} }
            entry.listDone = true
            if entry.onUpdate then
                entry.onUpdate()
            end
        end)
        task.spawn(function()
            local ok, result = pcall(function()
                return GetPlayerRank:Invoke(boardName)
            end)
            if not ok or type(result) ~= "table" then
                warn("LeaderboardClient: Failed to load player rank:", result)
            end
            entry.rank = { ok = ok and type(result) == "table", rank = type(result) == "table" and result or nil }
            entry.rankDone = true
            if entry.onUpdate then
                entry.onUpdate()
            end
        end)
        return entry
    end

    local function selectBoard(boardName)
        currentBoard = boardName
        requestToken += 1
        local token = requestToken
        local view = BOARD_VIEWS[boardName]

        for name, button in pairs(tabButtons) do
            UI.setButtonColor(button, name == boardName and Colors.Honey or Colors.Paper)
        end
        for i, statName in ipairs(view.stats) do
            statTiles[i].title.Text = statName
            statTiles[i].value.Text = "–"
        end
        buildHeader(view)
        clearList()
        showListMessage("LoadingState", "Loading...", Colors.InkSoft)

        local entry = fetchBoard(boardName)
        local function update()
            if token ~= requestToken or not screenGui.Parent then
                return
            end
            if entry.listDone then
                renderList(view, entry.list)
            end
            if entry.rankDone then
                renderMyRank(view, entry.rank)
            end
        end
        entry.onUpdate = update
        update()
    end

    for i, boardName in ipairs(BOARD_ORDER) do
        tabButtons[boardName] = UI.createButton({
            name = "Tab_" .. boardName,
            text = BOARD_VIEWS[boardName].tab,
            parent = tabBar,
            size = UDim2.new(0, 170, 0, 52),
            textSize = 22,
            backgroundColor = Colors.Paper,
            layoutOrder = i,
            onClick = function()
                if currentBoard ~= boardName then
                    selectBoard(boardName)
                end
            end,
        })
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
    selectBoard(currentBoard)
end

return LeaderboardClient
