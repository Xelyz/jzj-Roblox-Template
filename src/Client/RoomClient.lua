-- RoomClient - 房间系统客户端模块（主菜单、房间列表、房间内界面）
local M = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SignalManager = require(script.Parent.Parent.SignalManager)

-- 远程事件
local RoomCreateRequest = SignalManager.GetRemote("RoomCreateRequest")
local RoomJoinRequest = SignalManager.GetRemote("RoomJoinRequest")
local RoomLeaveRequest = SignalManager.GetRemote("RoomLeaveRequest")
local RoomStartGame = SignalManager.GetRemote("RoomStartGame")
local RoomPlayerUpdate = SignalManager.GetRemote("RoomPlayerUpdate")
local RoomPlayerReady = SignalManager.GetRemote("RoomPlayerReady")
local GetRoomList = SignalManager.GetRemoteFunction("GetRoomList")
local MatchStarted = SignalManager.GetRemote("MatchStarted")
local ReturnToRoomRequest = SignalManager.GetRemote("ReturnToRoomRequest")

local ClientMatchState = require(script.Parent.MatchStateClient)
local LeaderboardClient = require(script.Parent.LeaderboardClient)
local UI = require(script.Parent.ClientUIUtils)
local Config = require(script.Parent.Parent.Config)

local Colors = UI.Colors
local Fonts = UI.Fonts

-- UI状态管理
local currentUI = nil
local currentRoomData = nil
local updateRoomDisplay = nil

local showRoomList
local showRoomInterface

-- 清理当前UI
local function cleanupCurrentUI()
    if currentUI then
        currentUI:Destroy()
        currentUI = nil
    end
    updateRoomDisplay = nil
end

-- 创建一个界面根节点：ScreenGui > Stage。背景由 BackgroundManager 提供。
local function createScreenRoot(name)
    local screenGui = UI.createScreen(name)
    local stage = UI.createStage(screenGui)
    stage.Name = "BackgroundFrame"
    return screenGui, stage
end

-- 界面顶部的大标题和副标题
local function createPageHeading(parent, title, subtitle)
    UI.createLabel({
        name = "TitleLabel",
        parent = parent,
        text = title,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 24),
        size = UDim2.new(1, -240, 0, 60),
        textSize = 50,
        font = Fonts.Display,
        textColor = Colors.Paper,
        textScaled = true,
    })
    if subtitle then
        return UI.createLabel({
            name = "SubtitleLabel",
            parent = parent,
            text = subtitle,
            anchorPoint = Vector2.new(0.5, 0),
            position = UDim2.new(0.5, 0, 0, 84),
            size = UDim2.new(1, -240, 0, 26),
            textSize = 20,
            font = Fonts.Medium,
            textColor = Colors.PaperDeep,
        })
    end
    return nil
end

-- 显示排行榜界面
local function showLeaderboard()
    cleanupCurrentUI()
    LeaderboardClient.ShowLeaderboard()
end

-- ===============================
-- 主菜单
-- ===============================

local function createMainMenu()
    cleanupCurrentUI()

    local screenGui, stage = createScreenRoot("RoomSystemGui")
    currentUI = screenGui

    local column = UI.createFrame({
        name = "MenuColumn",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 0.5),
        position = UDim2.new(0.5, 0, 0.5, 0),
        size = UDim2.new(0, 560, 0, 600),
        backgroundTransparency = 1,
    })

    -- 游戏盒盖式标题牌
    local lid = UI.createPanel({
        name = "TitlePlate",
        parent = column,
        size = UDim2.new(1, 0, 0, 200),
        backgroundColor = Colors.Honey,
        depth = 8,
        cornerRadius = UDim.new(0, 20),
    })
    local inner = UI.createFrame({
        name = "InnerBorder",
        parent = lid,
        anchorPoint = Vector2.new(0.5, 0.5),
        position = UDim2.new(0.5, 0, 0.5, 0),
        size = UDim2.new(1, -20, 1, -20),
        backgroundTransparency = 1,
        zIndex = 3,
    })
    UI.addCorner(inner, UDim.new(0, 14))
    UI.addStroke(inner, 2, Colors.HoneyDark)

    UI.createLabel({
        name = "TitleLabel",
        text = Config.game.name,
        parent = lid,
        position = UDim2.new(0, 30, 0, 26),
        size = UDim2.new(1, -60, 0, 100),
        textSize = 64,
        font = Fonts.Display,
        textColor = Colors.Ink,
        textScaled = true,
        zIndex = 3,
    })
    UI.createLabel({
        name = "SubtitleLabel",
        text = "Welcome, " .. LocalPlayer.DisplayName,
        parent = lid,
        position = UDim2.new(0, 30, 0, 130),
        size = UDim2.new(1, -60, 0, 36),
        textSize = 22,
        font = Fonts.Bold,
        textColor = Colors.Ink,
        textScaled = true,
        zIndex = 3,
    })

    -- 菜单按钮
    local buttonList = UI.createFrame({
        name = "CenterPanel",
        parent = column,
        position = UDim2.new(0.5, 0, 0, 240),
        anchorPoint = Vector2.new(0.5, 0),
        size = UDim2.new(0, 420, 0, 330),
        backgroundTransparency = 1,
    })
    UI.addList(buttonList, { padding = 18, horizontalAlignment = Enum.HorizontalAlignment.Center })

    local buttons = {
        {
            name = "CreateRoomButton",
            text = "Create Room",
            backgroundColor = Colors.Green,
            onClick = function()
                RoomCreateRequest:FireServer()
            end,
        },
        {
            name = "JoinRoomButton",
            text = "Join Room",
            backgroundColor = Colors.Blue,
            onClick = function()
                showRoomList()
            end,
        },
        {
            name = "LeaderboardButton",
            text = "Leaderboard",
            backgroundColor = Colors.Paper,
            onClick = function()
                showLeaderboard()
            end,
        },
    }

    for index, buttonConfig in ipairs(buttons) do
        buttonConfig.parent = buttonList
        buttonConfig.size = UDim2.new(1, 0, 0, 78)
        buttonConfig.textSize = 32
        buttonConfig.depth = 6
        buttonConfig.layoutOrder = index
        UI.createButton(buttonConfig)
    end

    -- 左下角玩家名牌
    local badge = UI.createPanel({
        name = "PlayerBadge",
        parent = stage,
        anchorPoint = Vector2.new(0, 1),
        position = UDim2.new(0, 24, 1, -20),
        size = UDim2.new(0, 280, 0, 70),
        depth = 4,
        cornerRadius = UDim.new(0, 35),
    })
    UI.createAvatarImage({
        parent = badge,
        userId = LocalPlayer.UserId,
        position = UDim2.new(0, 6, 0, 5),
        size = UDim2.new(0, 56, 0, 56),
        zIndex = 3,
    })
    UI.createLabel({
        name = "PlayerName",
        parent = badge,
        text = LocalPlayer.DisplayName,
        position = UDim2.new(0, 72, 0, 8),
        size = UDim2.new(1, -90, 0, 26),
        textSize = 20,
        font = Fonts.Bold,
        textXAlignment = Enum.TextXAlignment.Left,
        truncate = true,
        textWrapped = false,
        zIndex = 3,
    })
    UI.createLabel({
        name = "PlayerHandle",
        parent = badge,
        text = "@" .. LocalPlayer.Name,
        position = UDim2.new(0, 72, 0, 34),
        size = UDim2.new(1, -90, 0, 20),
        textSize = 15,
        textColor = Colors.InkSoft,
        textXAlignment = Enum.TextXAlignment.Left,
        truncate = true,
        textWrapped = false,
        zIndex = 3,
    })

    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ===============================
-- 房间列表
-- ===============================

local MAX_LIST_AVATARS = 5

-- 创建房间列表项
local function createRoomListItem(parent, roomData, index)
    local isFull = roomData.playerCount >= roomData.maxPlayers

    local roomItem = UI.createFrame({
        name = "RoomItem",
        parent = parent,
        size = UDim2.new(1, -8, 0, 88),
        backgroundColor = index % 2 == 0 and Colors.PaperDark or Colors.Paper,
        corner = true,
        cornerRadius = UDim.new(0, 12),
        stroke = true,
        layoutOrder = index,
    })

    -- 房间名称与房主
    local infoFrame = UI.createFrame({
        name = "InfoFrame",
        parent = roomItem,
        size = UDim2.new(0.38, 0, 1, 0),
        position = UDim2.new(0, 18, 0, 0),
        backgroundTransparency = 1,
    })
    UI.createLabel({
        name = "NameLabel",
        text = roomData.name,
        parent = infoFrame,
        size = UDim2.new(1, 0, 0, 30),
        position = UDim2.new(0, 0, 0, 14),
        textSize = 24,
        font = Fonts.Display,
        textXAlignment = Enum.TextXAlignment.Left,
        truncate = true,
        textWrapped = false,
    })
    local hostName = roomData.host and (roomData.host.displayName or roomData.host.name) or "—"
    UI.createLabel({
        name = "HostLabel",
        text = "Host: " .. hostName,
        parent = infoFrame,
        size = UDim2.new(1, 0, 0, 22),
        position = UDim2.new(0, 0, 0, 48),
        textSize = 17,
        textColor = Colors.InkSoft,
        textXAlignment = Enum.TextXAlignment.Left,
        truncate = true,
        textWrapped = false,
    })

    -- 玩家头像，房主头像用蜂蜜色描边
    local avatarFrame = UI.createFrame({
        name = "AvatarFrame",
        parent = roomItem,
        size = UDim2.new(0, 260, 0, 52),
        position = UDim2.new(0.42, 0, 0.5, -26),
        backgroundTransparency = 1,
    })
    UI.addList(avatarFrame, {
        direction = Enum.FillDirection.Horizontal,
        padding = -10,
        verticalAlignment = Enum.VerticalAlignment.Center,
    })
    for i, playerData in ipairs(roomData.players) do
        if i > MAX_LIST_AVATARS then
            UI.createPill({
                name = "MoreLabel",
                parent = avatarFrame,
                text = "+" .. (#roomData.players - MAX_LIST_AVATARS),
                size = UDim2.new(0, 52, 0, 30),
                layoutOrder = i,
            })
            break
        end
        local avatar = UI.createAvatarImage({
            parent = avatarFrame,
            userId = playerData.userId,
            size = UDim2.new(0, 50, 0, 50),
            layoutOrder = i,
            zIndex = MAX_LIST_AVATARS - i + 2,
        })
        if roomData.host and playerData.userId == roomData.host.userId then
            UI.setAvatarRing(avatar, Colors.HoneyDark, 3)
        end
    end

    -- 人数
    UI.createPill({
        name = "PlayerCountLabel",
        parent = roomItem,
        text = string.format("%d / %d", roomData.playerCount, roomData.maxPlayers),
        anchorPoint = Vector2.new(1, 0.5),
        position = UDim2.new(1, -170, 0.5, 0),
        size = UDim2.new(0, 84, 0, 32),
        textSize = 18,
        backgroundColor = isFull and Colors.PaperDeep or Colors.Honey,
    })

    -- 加入按钮
    local joinButton = UI.createButton({
        name = "JoinButton",
        parent = roomItem,
        anchorPoint = Vector2.new(1, 0.5),
        position = UDim2.new(1, -16, 0.5, 2),
        size = UDim2.new(0, 136, 0, 58),
        textSize = 24,
        text = isFull and "Full" or "Join",
        backgroundColor = Colors.Blue,
        onClick = function()
            RoomJoinRequest:FireServer(roomData.id)
        end,
    })
    if isFull then
        UI.setButtonEnabled(joinButton, false)
    end
end

function showRoomList()
    cleanupCurrentUI()

    local screenGui, stage = createScreenRoot("RoomListGui")
    currentUI = screenGui

    local subtitle = createPageHeading(stage, "Room List", "Loading rooms...")

    local listPanel = UI.createPanel({
        name = "ListPanel",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 128),
        size = UDim2.new(0, 900, 1, -250),
    })

    local listFrame = UI.createScrollingFrame({
        name = "RoomListFrame",
        parent = listPanel,
        size = UDim2.new(1, -24, 1, -24),
        position = UDim2.new(0, 12, 0, 12),
        backgroundTransparency = 1,
        listLayout = true,
        listPadding = UDim.new(0, 10),
        zIndex = 3,
    })
    UI.addPadding(listFrame, 4, 4)

    local function showListMessage(name, text, color)
        UI.createLabel({
            name = name,
            text = text,
            parent = listFrame,
            size = UDim2.new(1, 0, 0, 120),
            textSize = 24,
            font = Fonts.Bold,
            textColor = color,
        })
    end

    -- 刷新房间列表
    local function refreshRoomList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end

        local success, roomList = pcall(function()
            return GetRoomList:Invoke()
        end)
        if not listFrame.Parent then
            return
        end

        if success and roomList then
            if #roomList == 0 then
                subtitle.Text = "No open rooms"
                showListMessage("NoRoomsLabel", "No available rooms. Why not create one?", Colors.InkSoft)
            else
                subtitle.Text = string.format("%d room%s open", #roomList, #roomList == 1 and "" or "s")
                for i, roomData in ipairs(roomList) do
                    createRoomListItem(listFrame, roomData, i)
                end
            end
        else
            subtitle.Text = "Could not reach the server"
            showListMessage("ErrorLabel", "Error loading rooms.", Colors.TextError)
            warn("Failed to get room list:", roomList)
        end
    end

    -- 底部按钮
    local bottomFrame = UI.createFrame({
        name = "BottomFrame",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 1),
        position = UDim2.new(0.5, 0, 1, -28),
        size = UDim2.new(0, 900, 0, 70),
        backgroundTransparency = 1,
    })

    UI.createButton({
        name = "BackButton",
        text = "Back",
        parent = bottomFrame,
        size = UDim2.new(0, 220, 1, 0),
        backgroundColor = Colors.Paper,
        onClick = createMainMenu,
    })

    UI.createButton({
        name = "RefreshButton",
        text = "Refresh",
        parent = bottomFrame,
        anchorPoint = Vector2.new(1, 0),
        position = UDim2.new(1, 0, 0, 0),
        size = UDim2.new(0, 220, 1, 0),
        backgroundColor = Colors.Blue,
        onClick = refreshRoomList,
    })

    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    refreshRoomList()
end

-- ===============================
-- 房间内界面
-- ===============================

local function isRoomHost(roomData, userId)
    return roomData.host ~= nil and roomData.host.userId == userId
end

-- 玩家座位卡片
local function createPlayerCard(parent, playerData, index, isHost)
    local card = UI.createFrame({
        name = "PlayerCard",
        parent = parent,
        backgroundColor = Colors.Paper,
        corner = true,
        cornerRadius = UDim.new(0, 14),
        layoutOrder = index,
    })
    UI.addStroke(card, isHost and 4 or 2, isHost and Colors.HoneyDark or Colors.Outline)

    -- 房主标识
    if isHost then
        UI.createPill({
            name = "HostLabel",
            parent = card,
            text = "★ Host",
            anchorPoint = Vector2.new(0.5, 0.5),
            position = UDim2.new(0.5, 0, 0, 0),
            size = UDim2.new(0, 92, 0, 28),
            backgroundColor = Colors.Honey,
            zIndex = 3,
        })
    end

    -- 头像位于卡片正中，名字在上，准备状态在下
    local avatar = UI.createAvatarImage({
        parent = card,
        userId = playerData.userId,
        anchorPoint = Vector2.new(0.5, 0.5),
        position = UDim2.new(0.5, 0, 0.5, 0),
        size = UDim2.new(0.7, 0, 0.48, 0),
        strokeThickness = 3,
    })
    if playerData.userId == LocalPlayer.UserId then
        UI.setAvatarRing(avatar, Colors.Blue, 4)
    end

    UI.createLabel({
        name = "NameLabel",
        text = playerData.displayName .. (playerData.userId == LocalPlayer.UserId and " (You)" or ""),
        parent = card,
        anchorPoint = Vector2.new(0.5, 1),
        position = UDim2.new(0.5, 0, 0.25, -2),
        size = UDim2.new(1, -16, 0.14, 0),
        textSize = 20,
        font = Fonts.Bold,
        textScaled = true,
    })

    -- 准备状态；房主无需准备，视为已准备
    local readyText, readyColor
    if isHost or playerData.isReady then
        readyText, readyColor = "✓ Ready", Colors.Green
    else
        readyText, readyColor = "Not Ready", Colors.PaperDeep
    end
    UI.createPill({
        name = "ReadyLabel",
        parent = card,
        text = readyText,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0.75, 6),
        size = UDim2.new(0.7, 0, 0, 30),
        textSize = 17,
        backgroundColor = readyColor,
    })
end

-- 空座位
local function createEmptySeat(parent, index)
    local seat = UI.createFrame({
        name = "EmptySeat",
        parent = parent,
        backgroundColor = Colors.PaperDark,
        backgroundTransparency = 0.35,
        corner = true,
        cornerRadius = UDim.new(0, 14),
        layoutOrder = index,
    })
    UI.addStroke(seat, 2, Colors.InkSoft, 0.5)
    UI.createLabel({
        name = "SeatLabel",
        parent = seat,
        text = "Open Seat",
        textSize = 20,
        font = Fonts.Bold,
        textColor = Colors.InkSoft,
    })
end

function showRoomInterface(roomData)
    cleanupCurrentUI()
    currentRoomData = roomData

    local screenGui, stage = createScreenRoot("RoomInterfaceGui")
    currentUI = screenGui

    local subtitle = createPageHeading(stage, "Room: " .. roomData.name, "")

    -- 玩家座位面板
    local playersPanel = UI.createPanel({
        name = "PlayersFrame",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 130),
        size = UDim2.new(0, 1000, 1, -260),
    })

    local seatsFrame = UI.createFrame({
        name = "Seats",
        parent = playersPanel,
        size = UDim2.new(1, -40, 1, -44),
        position = UDim2.new(0, 20, 0, 26),
        backgroundTransparency = 1,
        zIndex = 3,
    })
    local maxSeats = math.max(roomData.maxPlayers or Config.game.maxPlayers, 1)
    local columns = math.min(maxSeats, 4)
    local rows = math.ceil(maxSeats / columns)
    local grid = Instance.new("UIGridLayout")
    grid.CellPadding = UDim2.new(0, 18, 0, 22)
    grid.CellSize = UDim2.new(1 / columns, -18, 1 / rows, -22)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.VerticalAlignment = Enum.VerticalAlignment.Center
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = seatsFrame

    -- 底部按钮
    local buttonFrame = UI.createFrame({
        name = "ButtonFrame",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 1),
        position = UDim2.new(0.5, 0, 1, -28),
        size = UDim2.new(0, 1000, 0, 74),
        backgroundTransparency = 1,
    })

    local leaveButton = UI.createButton({
        name = "LeaveButton",
        text = "Leave Room",
        parent = buttonFrame,
        size = UDim2.new(0, 230, 1, 0),
        backgroundColor = Colors.Red,
        onClick = function()
            RoomLeaveRequest:FireServer()
            createMainMenu()
        end,
    })
    leaveButton:SetAttribute("buttonType", "leave")

    local readyButton = UI.createButton({
        name = "ReadyButton",
        text = "Ready",
        parent = buttonFrame,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 0),
        size = UDim2.new(0, 300, 1, 0),
        backgroundColor = Colors.Green,
        onClick = function()
            RoomPlayerReady:FireServer()
        end,
    })
    readyButton:SetAttribute("buttonType", "ready")

    local startButton = UI.createButton({
        name = "StartButton",
        text = "Start Game",
        parent = buttonFrame,
        anchorPoint = Vector2.new(1, 0),
        position = UDim2.new(1, 0, 0, 0),
        size = UDim2.new(0, 330, 1, 0),
        backgroundColor = Colors.Green,
        textScaled = true,
        onClick = function()
            if currentRoomData and isRoomHost(currentRoomData, LocalPlayer.UserId) then
                RoomStartGame:FireServer(currentRoomData.id)
            end
        end,
    })
    startButton:SetAttribute("buttonType", "start")

    -- 更新玩家与按钮
    local function updatePlayerDisplay(data)
        for _, child in ipairs(seatsFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end

        for i, playerData in ipairs(data.players) do
            createPlayerCard(seatsFrame, playerData, i, isRoomHost(data, playerData.userId))
        end
        for i = #data.players + 1, maxSeats do
            createEmptySeat(seatsFrame, i)
        end

        subtitle.Text = string.format("%d / %d players", #data.players, data.maxPlayers or maxSeats)

        local isHost = isRoomHost(data, LocalPlayer.UserId)
        local hasEnoughPlayers = #data.players >= Config.game.minPlayers

        -- 统计未准备的非房主玩家
        local notReadyCount = 0
        for _, playerData in ipairs(data.players) do
            if not isRoomHost(data, playerData.userId) and not playerData.isReady then
                notReadyCount = notReadyCount + 1
            end
        end
        local allPlayersReady = notReadyCount == 0

        startButton.Visible = isHost
        UI.setButtonEnabled(startButton, isHost and hasEnoughPlayers and allPlayersReady)
        if isHost then
            if not hasEnoughPlayers then
                UI.setButtonText(startButton, string.format("Need %d players", Config.game.minPlayers))
            elseif not allPlayersReady then
                UI.setButtonText(startButton, string.format("Waiting for %d players to be ready", notReadyCount))
            else
                UI.setButtonText(startButton, "Start Game")
            end
        end

        readyButton.Visible = not isHost
        if not isHost then
            local localPlayerReady = false
            for _, playerData in ipairs(data.players) do
                if playerData.userId == LocalPlayer.UserId then
                    localPlayerReady = playerData.isReady or false
                    break
                end
            end
            UI.setButtonText(readyButton, localPlayerReady and "Cancel Ready" or "Ready")
            UI.styleButton(readyButton, localPlayerReady and "danger" or "success")
        end
    end

    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    updatePlayerDisplay(roomData)
    updateRoomDisplay = updatePlayerDisplay

    return updatePlayerDisplay
end

-- ===============================
-- 事件
-- ===============================

-- 房间玩家更新：已在房间界面时就地刷新，否则说明刚加入房间
RoomPlayerUpdate:Connect(function(roomData)
    if currentUI and currentUI.Name == "RoomInterfaceGui" and updateRoomDisplay then
        currentRoomData = roomData
        updateRoomDisplay(roomData)
    else
        showRoomInterface(roomData)
    end
end)

-- 比赛开始
MatchStarted:Connect(function(data)
    if not data then
        warn("MatchStarted received nil data")
        return
    end

    cleanupCurrentUI()
    currentRoomData = nil

    if not data.matchId or not data.playerUserId or not data.opponentUserIds then
        warn("Invalid match data received")
        return
    end

    ClientMatchState.SetMatchId(data.matchId)
    ClientMatchState.SetPlayerUserIds(data.playerUserId, data.opponentUserIds)
end)

-- 排行榜关闭后回到主菜单
local LeaderboardClosed = SignalManager.GetBindable("LeaderboardClosed")
LeaderboardClosed:Connect(function()
    createMainMenu()
end)

-- 返回房间响应
ReturnToRoomRequest:Connect(function(data)
    if data.type == "return_to_room" and data.roomData then
        currentRoomData = data.roomData
        showRoomInterface(data.roomData)
    elseif data.type == "return_to_main" then
        createMainMenu()
        if data.message then
            UI.showToast(data.message, "warning", 3)
        end
    else
        createMainMenu()
    end
end)

-- 初始化主菜单
createMainMenu()

return M
