-- GameClientTemplate (Client) - 通用游戏客户端模板
-- 此文件为游戏UI和客户端逻辑的基础模板，可根据具体游戏需求进行修改

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 远程事件
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerInput = Remotes:WaitForChild("PlayerInput")
local GameStateUpdate = Remotes:WaitForChild("GameStateUpdate")
local GameAborted = Remotes:WaitForChild("GameAborted")
local MatchMessage = Remotes:WaitForChild("MatchMessage")

-- 客户端事件
local Events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Client")
local GameGuiCreated = Events:WaitForChild("GameGuiCreated")

local ClientMatchState = require(game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("ClientMatchState"))
local UI = require(game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("UIUtils"))

-- 全局变量
local gameGui = nil

-- 发送玩家输入的辅助函数
local function sendPlayerInput(inputType, inputData)
    local matchId = ClientMatchState.GetMatchId()
    if not matchId then
        print("Error: No active match to send input to")
        return
    end
    
    print("Sending player input:", inputType, inputData)
    PlayerInput:FireServer({
        matchId = matchId,
        input = {
            type = inputType,
            data = inputData
        }
    })
end

-- 创建游戏界面
local function createGameGui()
    -- 清理已存在的GUI
    if gameGui then
        gameGui:Destroy()
        gameGui = nil
    end
    
    print("Creating GameGui Template")
    
    local screenGui = UI.createScreen("GameGui")
    
    -- 主背景框架
    local mainFrame = UI.createFrame({
        name = "MainFrame",
        parent = screenGui,
        backgroundColor = UI.Colors.Background
    })
    
    -- 顶部标题栏
    local titleBar = UI.createFrame({
        name = "TitleBar",
        parent = mainFrame,
        size = UDim2.new(1, 0, 0.1, 0),
        backgroundColor = UI.Colors.Panel,
        cornerRadius = false
    })
    
    -- 游戏标题
    UI.createLabel({
        name = "TitleLabel",
        text = "Game Template", -- TODO: 替换为具体游戏名称
        parent = titleBar,
        textSize = 32,
        font = Enum.Font.SourceSansBold,
        transparent = true
    })
    
    -- 主内容区域
    local contentFrame = UI.createFrame({
        name = "ContentFrame",
        parent = mainFrame,
        size = UDim2.new(1, 0, 0.9, 0),
        position = UDim2.new(0, 0, 0.1, 0),
        backgroundTransparency = 1
    })
    
    -- 左侧游戏状态面板
    local stateFrame = UI.createFrame({
        name = "StateFrame",
        parent = contentFrame,
        size = UDim2.new(0.75, -10, 1, -20),
        position = UDim2.new(0, 10, 0, 10),
        backgroundColor = Color3.fromRGB(40, 40, 40),
        borderSize = 2,
        borderColor = UI.Colors.Border
    })
    
    -- 游戏状态区域标题
    UI.createLabel({
        name = "StateTitle",
        text = "Game Status",
        parent = stateFrame,
        size = UDim2.new(1, 0, 0.08, 0),
        textSize = 24,
        backgroundColor = UI.Colors.Panel,
        borderSize = 1,
        borderColor = UI.Colors.Border,
        font = Enum.Font.SourceSansBold,
        cornerRadius = false
    })
    
    -- 游戏状态显示区域
    local gameStateFrame = UI.createFrame({
        name = "GameStateFrame",
        parent = stateFrame,
        size = UDim2.new(1, -20, 0.7, 0),
        position = UDim2.new(0, 10, 0.08, 15),
        backgroundColor = Color3.fromRGB(50, 50, 50),
        borderSize = 1,
        borderColor = UI.Colors.Border
    })
    
    -- 回合数显示
    UI.createLabel({
        name = "RoundLabel",
        text = "Round: 1",
        parent = gameStateFrame,
        size = UDim2.new(0.4, 0, 0.1, 0),
        position = UDim2.new(0.3, 0, 0.02, 0),
        textSize = 20,
        textColor = Color3.fromRGB(255, 255, 100),
        backgroundColor = Color3.fromRGB(40, 40, 40),
        borderSize = 1,
        borderColor = Color3.fromRGB(120, 120, 120),
        font = Enum.Font.SourceSansBold
    })
    
    -- 玩家信息显示区域
    local playersFrame = UI.createFrame({
        name = "PlayersFrame",
        parent = gameStateFrame,
        size = UDim2.new(1, -20, 0.6, 0),
        position = UDim2.new(0, 10, 0.2, 0),
        backgroundTransparency = 1
    })
    
    -- 创建当前玩家容器
    local myPlayerContainer = UI.createFrame({
        name = "MyPlayer",
        parent = playersFrame,
        size = UDim2.new(0.45, 0, 0.8, 0),
        position = UDim2.new(0, 0, 0.1, 0),
        backgroundColor = Color3.fromRGB(60, 120, 60), -- 绿色表示自己
        borderSize = 1,
        borderColor = Color3.fromRGB(100, 150, 100)
    })
    
    -- 我的玩家信息模板
    UI.createLabel({
        name = "NameLabel",
        text = "You",
        parent = myPlayerContainer,
        textSize = 18,
        backgroundColor = Color3.fromRGB(40, 80, 40),
        font = Enum.Font.SourceSansBold,
        cornerRadius = false
    })
    
    -- 创建对手列表容器
    local opponentsContainer = UI.createScrollingFrame({
        name = "OpponentsContainer",
        parent = playersFrame,
        size = UDim2.new(0.45, 0, 0.8, 0),
        position = UDim2.new(0.55, 0, 0.1, 0),
        backgroundColor = Color3.fromRGB(100, 60, 60), -- 红色表示对手
        borderSize = 1,
        borderColor = Color3.fromRGB(150, 100, 100),
        scrollBarThickness = 6
    })
    
    -- 游戏控制区域
    local controlFrame = UI.createFrame({
        name = "ControlFrame",
        parent = stateFrame,
        size = UDim2.new(1, -20, 0.15, 0),
        position = UDim2.new(0, 10, 0.83, 0),
        backgroundColor = Color3.fromRGB(40, 40, 40),
        borderSize = 1,
        borderColor = UI.Colors.Border
    })
    
    -- TODO: 在这里添加具体的游戏控制按钮和输入
    UI.createButton({
        name = "ActionButton",
        text = "Game Action", -- TODO: 替换为具体的游戏动作
        parent = controlFrame,
        size = UDim2.new(0.3, 0, 0.6, 0),
        position = UDim2.new(0.35, 0, 0.2, 0),
        backgroundColor = UI.Colors.ButtonGreen,
        onClick = function()
            -- 发送玩家输入
            sendPlayerInput("action", {
                -- TODO: 添加具体的输入数据
            })
        end
    })
    
    -- 右侧聊天面板
    local chatFrame = UI.createFrame({
        name = "ChatFrame",
        parent = contentFrame,
        size = UDim2.new(0.25, -10, 1, -20),
        position = UDim2.new(0.75, 10, 0, 10),
        backgroundColor = Color3.fromRGB(40, 40, 40),
        borderSize = 2,
        borderColor = UI.Colors.Border
    })
    
    -- 聊天标题
    UI.createLabel({
        name = "ChatTitle",
        text = "Match Chat",
        parent = chatFrame,
        size = UDim2.new(1, 0, 0.08, 0),
        textSize = 20,
        backgroundColor = UI.Colors.Panel,
        borderSize = 1,
        borderColor = UI.Colors.Border,
        font = Enum.Font.SourceSansBold,
        cornerRadius = false
    })
    
    gameGui = screenGui
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    print("GameGui Template created")
    
    -- 通知聊天客户端创建聊天功能
    GameGuiCreated:Fire()
end

-- 创建对手容器的辅助函数
local function createOpponentContainer(parentContainer, userId, yOffset)
    local opponentContainer = UI.createFrame({
        name = tostring(userId),
        parent = parentContainer,
        size = UDim2.new(1, -10, 0, 60),
        position = UDim2.new(0, 5, 0, yOffset),
        backgroundColor = Color3.fromRGB(80, 50, 50),
        borderSize = 1,
        borderColor = Color3.fromRGB(120, 80, 80)
    })
    
    UI.createLabel({
        name = "NameLabel",
        text = "Player",
        parent = opponentContainer,
        textSize = 14,
        font = Enum.Font.SourceSansBold,
        transparent = true
    })
    
    return opponentContainer
end

-- 更新游戏状态显示
local function updateGameState(gameState)
    if not gameGui then
        return
    end
    
    print("Updating game UI with state:", gameState)
    
    -- 查找UI元素
    local mainFrame = gameGui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    
    local contentFrame = mainFrame:FindFirstChild("ContentFrame")
    if not contentFrame then return end
    
    local stateFrame = contentFrame:FindFirstChild("StateFrame")
    if not stateFrame then return end
    
    local gameStateFrame = stateFrame:FindFirstChild("GameStateFrame")
    if not gameStateFrame then return end
    
    -- 更新回合数
    local roundLabel = gameStateFrame:FindFirstChild("RoundLabel")
    if roundLabel and gameState.round then
        roundLabel.Text = "Round: " .. tostring(gameState.round)
    end
    
    -- 更新玩家容器
    local playersFrame = gameStateFrame:FindFirstChild("PlayersFrame")
    if not playersFrame then return end
    
    local opponentsContainer = playersFrame:FindFirstChild("OpponentsContainer")
    if not opponentsContainer then return end
    
    -- 重建对手列表
    for _, child in ipairs(opponentsContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- 基于游戏状态添加对手信息
    if gameState.players then
        local yOffset = 0
        for userId, playerState in pairs(gameState.players) do
            if tonumber(userId) ~= LocalPlayer.UserId then
                local container = createOpponentContainer(opponentsContainer, userId, yOffset)
                yOffset = yOffset + 65
                
                -- 更新玩家名称和状态
                local nameLabel = container:FindFirstChild("NameLabel")
                if nameLabel and playerState.name then
                    nameLabel.Text = tostring(playerState.name)
                end
                
                -- TODO: 添加具体的游戏状态显示
            end
        end
        
        -- 更新滚动容器大小
        opponentsContainer.CanvasSize = UDim2.new(0, 0, 0, yOffset)
    end
end

-- 显示游戏结束界面
local function showGameEndUI()
    if not gameGui then return end
    
    print("Game finished! Showing end UI")
    
    -- TODO: 实现游戏结束界面
    -- 例如：显示胜负结果，返回房间按钮等
    
    -- 创建游戏结束覆盖层
    local endOverlay = UI.createFrame({
        name = "GameEndOverlay",
        parent = gameGui,
        backgroundColor = Color3.fromRGB(0, 0, 0),
        backgroundTransparency = 0.5,
        cornerRadius = false
    })
    endOverlay.ZIndex = 10
    
    -- 游戏结束标签
    UI.createLabel({
        name = "EndLabel",
        text = "Game Finished!", -- TODO: 根据游戏结果显示具体信息
        parent = endOverlay,
        size = UDim2.new(0.6, 0, 0.2, 0),
        position = UDim2.new(0.2, 0, 0.3, 0),
        textSize = 48,
        font = Enum.Font.SourceSansBold,
        transparent = true
    })
    endOverlay:FindFirstChild("EndLabel").ZIndex = 11
    
    -- 返回房间按钮
    local returnButton = UI.createButton({
        name = "ReturnButton",
        text = "Return to Room",
        parent = endOverlay,
        size = UDim2.new(0.3, 0, 0.08, 0),
        position = UDim2.new(0.35, 0, 0.55, 0),
        backgroundColor = UI.Colors.ButtonGreen,
        onClick = function()
            print("Returning to room from game")
            -- TODO: 实现返回房间的逻辑
        end
    })
    returnButton.ZIndex = 11
end

-- 监听比赛开始事件 - 在MatchStarted事件后自动创建GUI
local MatchStarted = Remotes:WaitForChild("MatchStarted")
MatchStarted.OnClientEvent:Connect(function(data)
    print("MatchStarted received in GameClient, creating game GUI")
    createGameGui()
end)

-- 监听游戏状态更新
GameStateUpdate.OnClientEvent:Connect(function(gameState)
    print("Game state update received:", gameState)
    updateGameState(gameState)
end)

-- 监听游戏中止事件
GameAborted.OnClientEvent:Connect(function(abortData)
    print("Game aborted:", abortData)
    
    if gameGui then
        gameGui:Destroy()
        gameGui = nil
    end
    
    print("Game GUI cleaned up due to abort")
end)

-- 监听匹配消息
MatchMessage.OnClientEvent:Connect(function(messageData)
    print("Match message received:", messageData)
    -- TODO: 实现消息显示功能
end)

print("GameClientTemplate loaded and ready")

-- TODO: 添加其他游戏特定的客户端逻辑 