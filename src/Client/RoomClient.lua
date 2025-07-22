-- RoomClient - 房间系统客户端模块
local M = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 导入SignalManager
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
-- GameFinished功能已合并到ReturnToRoomRequest中
-- GetLeaderboard 和 GetPlayerRank 已移到 LeaderboardClient 模块中

local ClientMatchState = require(script.Parent.MatchStateClient)
local LeaderboardClient = require(script.Parent.LeaderboardClient)
local UI = require(script.Parent.ClientUIUtils)
local Config = require(script.Parent.Parent.Config)

-- UI状态管理
local currentUI = nil
local currentRoomData = nil

-- Helper to clean up match state and GUIs
local function _cleanupMatchState()
    ClientMatchState.Clear()
end

-- 清理当前UI
local function cleanupCurrentUI()
    if currentUI then
        currentUI:Destroy()
        currentUI = nil
    end
end

-- 显示排行榜界面
local function showLeaderboard()
    cleanupCurrentUI()
    LeaderboardClient.ShowLeaderboard()
end

-- 创建主菜单界面
local function createMainMenu()
    cleanupCurrentUI()
    
    local screenGui = UI.createScreen("RoomSystemGui")
    currentUI = screenGui
    
    local backgroundFrame = UI.createBackground(screenGui, true)
    
    -- 主标题
    UI.createLabel({
        name = "TitleLabel",
        text = Config.game.name,
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.15, 0),
        position = UDim2.new(0.1, 0, 0.15, 0),
        textSize = 48,
        font = Enum.Font.SourceSansBold,
        transparent = true
    })
    
    -- -- 副标题
    -- UI.createLabel({
    --     name = "SubtitleLabel",
    --     text = "Simplest? Game Ever",
    --     parent = backgroundFrame,
    --     size = UDim2.new(0.6, 0, 0.08, 0),
    --     position = UDim2.new(0.2, 0, 0.3, 0),
    --     textSize = 20,
    --     textColor = UI.Colors.TextGray,
    --     transparent = true,
    --     textWrapped = true,
    --     textScaled = true
    -- })
    
    -- 中央面板
    local centerPanel = UI.createFrame({
        name = "CenterPanel",
        parent = backgroundFrame,
        size = UDim2.new(0.5, 0, 0.5, 0),
        position = UDim2.new(0.25, 0, 0.35, 0),
        borderSize = 2,
        borderColor = UI.Colors.Border,
        corner = true
    })
    
    -- 创建按钮
    local buttons = {
        {
            name = "CreateRoomButton",
            text = "Create Room",
            position = UDim2.new(0.1, 0, 0.15, 0),
            size = UDim2.new(0.8, 0, 0.2, 0),
            backgroundColor = UI.Colors.ButtonGreen,
            corner = true,
            cornerRadius = UDim.new(0, 8),
            onClick = function()
                local roomName = LocalPlayer.DisplayName .. "'s room"
                print("Creating room with name:", roomName)
                RoomCreateRequest:FireServer(roomName)
            end
        },
        {
            name = "JoinRoomButton", 
            text = "Join Room",
            position = UDim2.new(0.1, 0, 0.4, 0),
            size = UDim2.new(0.8, 0, 0.2, 0),
            backgroundColor = UI.Colors.ButtonBlue,
            corner = true,
            cornerRadius = UDim.new(0, 8),
            onClick = function()
                showRoomList()
            end
        },
        {
            name = "LeaderboardButton",
            text = "Leaderboard",
            position = UDim2.new(0.1, 0, 0.65, 0),
            size = UDim2.new(0.8, 0, 0.2, 0),
            backgroundColor = UI.Colors.ButtonGray,
            corner = true,
            cornerRadius = UDim.new(0, 8),
            onClick = function()
                showLeaderboard()
            end
        }
    }
    
    for _, buttonConfig in ipairs(buttons) do
        buttonConfig.parent = centerPanel
        buttonConfig.textSize = 24
        UI.createButton(buttonConfig)
    end

    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    print("Main menu created")
end

-- 显示房间列表
function showRoomList()
    cleanupCurrentUI()
    
    local screenGui = UI.createScreen("RoomListGui")
    currentUI = screenGui
    
    local backgroundFrame = UI.createBackground(screenGui)
    UI.createTitle("Room List", backgroundFrame)
    
    -- 房间列表容器
    local listFrame = UI.createScrollingFrame({
        name = "RoomListFrame",
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.6, 0),
        position = UDim2.new(0.1, 0, 0.2, 0),
        listLayout = true,
        corner = true,
        cornerRadius = UDim.new(0, 8)
    })
    
    -- 创建房间列表项
    local function createRoomListItem(parent, roomData, index)
        local roomItem = UI.createFrame({
            name = "RoomItem",
            parent = parent,
            size = UDim2.new(1, 0, 0, 80),
            backgroundColor = Color3.fromRGB(50, 50, 60),
            borderSize = 1,
            borderColor = UI.Colors.BorderAccent,
            corner = true
        })
        roomItem.LayoutOrder = index
        
        -- 房间信息区域
        local infoFrame = UI.createFrame({
            name = "InfoFrame",
            parent = roomItem,
            size = UDim2.new(0.35, 0, 1, 0),
            position = UDim2.new(0.02, 0, 0, 0),
            backgroundTransparency = 1,
            corner = true
        })
        
        -- 房间名称
        UI.createLabel({
            name = "NameLabel",
            text = roomData.name,
            parent = infoFrame,
            size = UDim2.new(1, 0, 0.5, 0),
            position = UDim2.new(0, 0, 0.1, 0),
            textSize = 16,
            textXAlignment = Enum.TextXAlignment.Left,
            textYAlignment = Enum.TextYAlignment.Center,
            transparent = true,
        })
        
        -- 玩家数量
        UI.createLabel({
            name = "PlayerCountLabel",
            text = string.format("Players: %d/%d", roomData.playerCount, roomData.maxPlayers),
            parent = infoFrame,
            size = UDim2.new(1, 0, 0.4, 0),
            position = UDim2.new(0, 0, 0.5, 0),
            textSize = 12,
            textColor = UI.Colors.TextGray,
            textXAlignment = Enum.TextXAlignment.Left,
            textYAlignment = Enum.TextYAlignment.Center,
            transparent = true
        })
        
        -- 玩家头像区域
        local avatarFrame = UI.createFrame({
            name = "AvatarFrame",
            parent = roomItem,
            size = UDim2.new(0.4, 0, 1, 0),
            position = UDim2.new(0.37, 0, 0, 0),
            backgroundTransparency = 1
        })
        
        -- 显示房间内玩家头像（最多显示2个）
        for i, playerData in ipairs(roomData.players) do
            if i <= 2 then
                local avatarContainer = UI.createAvatarImage({
                    parent = avatarFrame,
                    userId = playerData.userId,
                })
                avatarContainer.Size = UDim2.new(0, 40, 0, 40)
                avatarContainer.Position = UDim2.new((i-1) * 0.5, 5, 0.5, -20)
                
                -- 如果是房主,添加特殊边框颜色
                if roomData.host and playerData.userId == roomData.host.userId then
                    local background = avatarContainer:FindFirstChild("AvatarBackground")
                    if background then
                        background.BorderColor3 = UI.Colors.TextYellow
                    end
                end
            end
        end
        
        -- 加入按钮
        local joinButtonConfig = {
            name = "JoinButton",
            parent = roomItem,
            size = UDim2.new(0.18, 0, 0.6, 0),
            position = UDim2.new(0.8, 0, 0.2, 0),
            textSize = 16,
            corner = true,
            cornerRadius = UDim.new(0, 6)
        }
        
        if roomData.playerCount >= roomData.maxPlayers then
            joinButtonConfig.text = "Full"
            joinButtonConfig.backgroundColor = UI.Colors.ButtonDisabled
        else
            joinButtonConfig.text = "Join"
            joinButtonConfig.backgroundColor = UI.Colors.ButtonBlue
            joinButtonConfig.onClick = function()
                RoomJoinRequest:FireServer(roomData.id)
            end
        end
        
        UI.createButton(joinButtonConfig)
    end

    -- 刷新房间列表
    local function refreshRoomList()
        -- 清空现有列表
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("Frame") or child.Name == "NoRoomsLabel" or child.Name == "ErrorLabel" then
                child:Destroy()
            end
        end
        
        -- 获取并显示新列表
        local success, roomList = pcall(function()
            return GetRoomList:Invoke()
        end)
        
        if success and roomList then
            if #roomList == 0 then
                UI.createLabel({
                    name = "NoRoomsLabel",
                    text = "No available rooms. Why not create one?",
                    parent = listFrame,
                    size = UDim2.new(1, 0, 0, 50),
                    textSize = 18,
                    textColor = UI.Colors.TextGray,
                    transparent = true
                })
            else
                for i, roomData in ipairs(roomList) do
                    createRoomListItem(listFrame, roomData, i)
                end
            end
        else
            UI.createLabel({
                name = "ErrorLabel",
                text = "Error loading rooms.",
                parent = listFrame,
                size = UDim2.new(1, 0, 0, 50),
                textSize = 18,
                textColor = UI.Colors.TextError,
                transparent = true
            })
            warn("Failed to get room list:", roomList)
        end
        
        -- 更新滚动区域大小
        listFrame.CanvasSize = UDim2.new(0, 0, 0, listFrame.UIListLayout.AbsoluteContentSize.Y)
    end
    
    -- 返回和刷新按钮
    local bottomFrame = UI.createFrame({
        name = "BottomFrame",
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.1, 0),
        position = UDim2.new(0.1, 0, 0.82, 0),
        backgroundTransparency = 1
    })
    
    UI.createButton({
        name = "BackButton",
        text = "Back",
        parent = bottomFrame,
        size = UDim2.new(0.4, 0, 0.8, 0),
        position = UDim2.new(0.05, 0, 0.1, 0),
        backgroundColor = UI.Colors.ButtonGray,
        cornerRadius = UDim.new(0, 6),
        onClick = createMainMenu
    })
    
    UI.createButton({
        name = "RefreshButton",
        text = "Refresh",
        parent = bottomFrame,
        size = UDim2.new(0.4, 0, 0.8, 0),
        position = UDim2.new(0.55, 0, 0.1, 0),
        backgroundColor = UI.Colors.ButtonBlue,
        cornerRadius = UDim.new(0, 6),
        onClick = refreshRoomList
    })
    
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- 首次加载
    refreshRoomList()
end

-- 创建通用的玩家卡片函数
local function createPlayerCard(parent, playerData, index, isHost)
    local playerCard = UI.createFrame({
        name = "PlayerCard",
        parent = parent,
        size = UDim2.new(0, 220, 1, -20),
        position = UDim2.new(0, 30 + (index - 1) * 250, 0, 10),
        backgroundColor = Color3.fromRGB(50, 50, 60),
        borderSize = 2,
        borderColor = isHost and UI.Colors.TextYellow or UI.Colors.BorderAccent,
        corner = true
    })
    
    -- 房主标识
    if isHost then
        UI.createLabel({
            name = "HostLabel",
            text = "Host",
            parent = playerCard,
            size = UDim2.new(1, -10, 0, 25),
            position = UDim2.new(0, 5, 0, 5),
            textSize = 14,
            textColor = UI.Colors.TextYellow,
            transparent = true
        })
    end
    
    -- 头像容器
    local avatarContainer = UI.createAvatarImage({
        parent = playerCard,
        userId = playerData.userId,
    })
    avatarContainer.Position = UDim2.new(0.5, -60, 0, 35)
    avatarContainer.Size = UDim2.new(0, 120, 0, 120)
    
    -- 玩家名称
    UI.createLabel({
        name = "NameLabel",
        text = playerData.displayName,
        parent = playerCard,
        size = UDim2.new(1, -10, 0, 25),
        position = UDim2.new(0, 5, 1, -70),
        textSize = 16,
        textWrapped = true,
        transparent = true
    })
    
    -- 准备状态（非房主）
    if not isHost then
        UI.createLabel({
            name = "ReadyLabel",
            text = playerData.isReady and "✓ Ready" or "⏸ Not Ready",
            parent = playerCard,
            size = UDim2.new(1, -10, 0, 25),
            position = UDim2.new(0, 5, 1, -30),
            textSize = 16,
            textColor = playerData.isReady and UI.Colors.TextGreen or UI.Colors.TextYellow,
            transparent = true
        })
    end
end

-- 显示房间内界面
function showRoomInterface(roomData)
    cleanupCurrentUI()
    currentRoomData = roomData
    
    local screenGui = UI.createScreen("RoomInterfaceGui")
    currentUI = screenGui
    
    local backgroundFrame = UI.createBackground(screenGui)
    UI.createTitle("Room: " .. roomData.name, backgroundFrame, nil, UDim2.new(0, 0, 0.05, 0))
    
    -- 玩家列表容器
    local playersFrame = UI.createFrame({
        name = "PlayersFrame",
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.5, 0),
        position = UDim2.new(0.1, 0, 0.2, 0),
        borderSize = 2,
        borderColor = UI.Colors.Border,
        corner = true
    })
    
    -- 按钮容器
    local buttonFrame = UI.createFrame({
        name = "ButtonFrame",
        parent = backgroundFrame,
        size = UDim2.new(0.8, 0, 0.15, 0),
        position = UDim2.new(0.1, 0, 0.75, 0),
        backgroundTransparency = 1
    })
    
    -- 按钮配置
    local buttons = {
        leave = {
            name = "LeaveButton",
            text = "Leave Room",
            size = UDim2.new(0.25, 0, 0.8, 0),
            position = UDim2.new(0, 0, 0.1, 0),
            backgroundColor = UI.Colors.ButtonRed,
            corner = true,
            cornerRadius = UDim.new(0, 6),
            onClick = function()
                print("Leaving room")
                RoomLeaveRequest:FireServer()
                createMainMenu()
            end
        },
        start = {
            name = "StartButton",
            text = "Start Game",
            size = UDim2.new(0.3, 0, 0.8, 0),
            position = UDim2.new(0.7, 0, 0.1, 0),
            backgroundColor = UI.Colors.ButtonGreen,
            corner = true,
            cornerRadius = UDim.new(0, 6),
            onClick = function()
                if currentRoomData and currentRoomData.host and currentRoomData.host.userId == LocalPlayer.UserId then
                    print("Starting game")
                    RoomStartGame:FireServer(currentRoomData.id)
                end
            end
        },
        ready = {
            name = "ReadyButton",
            text = "Ready",
            size = UDim2.new(0.3, 0, 0.8, 0),
            position = UDim2.new(0.35, 0, 0.1, 0),
            backgroundColor = UI.Colors.ButtonGreen,
            corner = true,
            cornerRadius = UDim.new(0, 6),
            onClick = function()
                print("Toggling ready status from room interface")
                RoomPlayerReady:FireServer()
            end
        }
    }
    
    -- 创建按钮
    for key, config in pairs(buttons) do
        config.parent = buttonFrame
        local button = UI.createButton(config)
        button:SetAttribute("buttonType", key)
    end
    
    -- 更新玩家显示
    local function updatePlayerDisplay(roomData)
        -- 清空现有玩家显示
        for _, child in ipairs(playersFrame:GetChildren()) do
            if child:IsA("Frame") and child.Name == "PlayerCard" then
                child:Destroy()
            end
        end
        
        -- 创建玩家卡片
        for i, playerData in ipairs(roomData.players) do
            createPlayerCard(playersFrame, playerData, i, roomData.host and playerData.userId == roomData.host.userId)
        end
        
        -- 更新按钮状态
        local startButton = buttonFrame:FindFirstChild("StartButton")
        local readyButton = buttonFrame:FindFirstChild("ReadyButton")
        
        if startButton then
            local isHost = roomData.host and roomData.host.userId == LocalPlayer.UserId
            local hasEnoughPlayers = #roomData.players >= Config.game.minPlayers
            
            -- 检查所有非房主玩家是否都已准备
            local allPlayersReady = true
            local notReadyCount = 0
            if hasEnoughPlayers then
                for _, playerData in ipairs(roomData.players) do
                    if roomData.host and playerData.userId ~= roomData.host.userId then
                        if not playerData.isReady then
                            allPlayersReady = false
                            notReadyCount = notReadyCount + 1
                        end
                    end
                end
            end
            
            local canStart = isHost and hasEnoughPlayers and allPlayersReady
            
            startButton.Visible = isHost
            UI.setButtonEnabled(startButton, canStart)
            
            if isHost then
                if not hasEnoughPlayers then
                    startButton.Text = string.format("Need %d players", Config.game.minPlayers)
                elseif not allPlayersReady then
                    startButton.Text = string.format("Waiting for %d players to be ready", notReadyCount)
                else
                    startButton.Text = "Start Game"
                end
            end
        end
        
        if readyButton then
            local isLocalPlayerHost = roomData.host and roomData.host.userId == LocalPlayer.UserId
            readyButton.Visible = not isLocalPlayerHost
            
            if not isLocalPlayerHost then
                local localPlayerReady = false
                for _, playerData in ipairs(roomData.players) do
                    if playerData.userId == LocalPlayer.UserId then
                        localPlayerReady = playerData.isReady or false
                        break
                    end
                end
                
                readyButton.Text = localPlayerReady and "Cancel Ready" or "Ready"
                UI.styleButton(readyButton, localPlayerReady and "danger" or "success")
            end
        end
    end
    
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    updatePlayerDisplay(roomData)
    
    print("Room interface created for room:", roomData.name)
    return updatePlayerDisplay
end

-- 监听房间玩家更新事件
RoomPlayerUpdate:Connect(function(roomData)
    print("Room player update received:", roomData)
    
    if currentUI and currentUI.Name == "RoomInterfaceGui" then
        currentRoomData = roomData
        -- 查找并调用更新函数
        local playersFrame = currentUI.BackgroundFrame:FindFirstChild("PlayersFrame")
        local buttonFrame = currentUI.BackgroundFrame:FindFirstChild("ButtonFrame")
        local startButton = buttonFrame and buttonFrame:FindFirstChild("StartButton")
        local readyButton = buttonFrame and buttonFrame:FindFirstChild("ReadyButton")
        
        if playersFrame then
            -- 清空现有玩家显示
            for _, child in ipairs(playersFrame:GetChildren()) do
                if child:IsA("Frame") and child.Name == "PlayerCard" then
                    child:Destroy()
                end
            end
            
            -- 使用通用的createPlayerCard函数创建玩家卡片
            for i, playerData in ipairs(roomData.players) do
                local isHost = roomData.host and playerData.userId == roomData.host.userId
                createPlayerCard(playersFrame, playerData, i, isHost)
            end
            
            -- 更新开始游戏按钮状态
            if startButton then
                local isHost = roomData.host and roomData.host.userId == LocalPlayer.UserId
                local hasEnoughPlayers = #roomData.players >= 2
                
                -- 检查所有非房主玩家是否都已准备
                local allPlayersReady = true
                local notReadyCount = 0
                if hasEnoughPlayers then
                    for _, playerData in ipairs(roomData.players) do
                        if roomData.host and playerData.userId ~= roomData.host.userId then
                            if not playerData.isReady then
                                allPlayersReady = false
                                notReadyCount = notReadyCount + 1
                            end
                        end
                    end
                end
                
                local canStart = isHost and hasEnoughPlayers and allPlayersReady
                
                startButton.Visible = isHost
                UI.setButtonEnabled(startButton, canStart)
                
                if isHost then
                    if not hasEnoughPlayers then
                        startButton.Text = string.format("Need %d players", 2)
                    elseif not allPlayersReady then
                        startButton.Text = string.format("Waiting for %d players to be ready", notReadyCount)
                    else
                        startButton.Text = "Start Game"
                    end
                end
            end
            
            -- 更新准备按钮状态
            if readyButton then
                local isLocalPlayerHost = roomData.host and roomData.host.userId == LocalPlayer.UserId
                readyButton.Visible = not isLocalPlayerHost
                
                if not isLocalPlayerHost then
                    -- 查找本地玩家的准备状态
                    local localPlayerReady = false
                    for _, playerData in ipairs(roomData.players) do
                        if playerData.userId == LocalPlayer.UserId then
                            localPlayerReady = playerData.isReady or false
                            break
                        end
                    end
                    
                    readyButton.Text = localPlayerReady and "Cancel Ready" or "Ready"
                    UI.styleButton(readyButton, localPlayerReady and "danger" or "success")
                end
            end
        end
    else
        -- 如果不在房间界面，但收到房间更新，说明成功加入了房间
        showRoomInterface(roomData)
    end
end)

-- 监听比赛开始事件
MatchStarted:Connect(function(data)
    print("MatchStarted event received:", data)
    
    if not data then
        print("Error: MatchStarted received nil data")
        return
    end
    
    -- Hide room GUI if present
    cleanupCurrentUI()
    currentRoomData = nil
    
    if not data.matchId or not data.playerUserId or not data.opponentUserIds then
        print("Error: Invalid match data received")
        return
    end
    
    print("Setting up match:", data.matchId, "Player:", data.playerUserId, "vs Opponents:", table.concat(data.opponentUserIds, ", "))
    ClientMatchState.SetMatchId(data.matchId)
    ClientMatchState.SetPlayerUserIds(data.playerUserId, data.opponentUserIds)
end)

-- 监听排行榜关闭事件
local LeaderboardClosed = SignalManager.GetBindable("LeaderboardClosed")
-- 直接连接事件监听器
LeaderboardClosed:Connect(function()
    print("Leaderboard closed, returning to main menu")
    createMainMenu()
end)

-- 监听返回房间响应事件
ReturnToRoomRequest:Connect(function(data)
    print("Return to room response received:", data)
    
    if data.type == "return_to_room" and data.roomData then
        print("Returning to room after game:", data.roomData.name)
        currentRoomData = data.roomData
        showRoomInterface(data.roomData)
    elseif data.type == "return_to_main" then
        print("Returning to main menu:", data.message or "Game finished")
        -- 立即创建主菜单，避免GUI空档期
        createMainMenu()
        
        -- 如果有错误消息，异步显示并清理
        if data.message then
            local msg = Instance.new("Message")
            msg.Text = data.message
            msg.Parent = LocalPlayer.PlayerGui
            
            -- 异步清理消息，不阻塞主线程
            task.spawn(function()
                task.wait(2)
                if msg and msg.Parent then
                    msg:Destroy()
                end
            end)
        end
    else
        print("Game finished, returning to main menu")
        createMainMenu()
    end
end)

-- 初始化主菜单
createMainMenu()

return M