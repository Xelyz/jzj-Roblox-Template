local M = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 导入SignalManager和工具模块
local SignalManager = require(script.Parent.Parent.SignalManager)
local UI = require(script.Parent.ClientUIUtils)

local MatchMessage = SignalManager.GetRemote("MatchMessage")
local ClientMatchState = require(script.Parent.MatchStateClient)

local GameGuiCreated = SignalManager.GetBindable("GameGuiCreated")

-- 消息缓存机制
local pendingMessages = {}

-- 添加消息到聊天显示区域
local function addMessageToChat(sender, message, container)
    local messageCount = #container:GetChildren()
    local messageHeight = 30
    
    local messageFrame = UI.createFrame({
        name = "MessageFrame",
        size = UDim2.new(1, -5, 0, messageHeight),
        position = UDim2.new(0, 0, 0, messageCount * messageHeight),
        backgroundTransparency = 1,
        parent = container
    })
    
    -- 发送者标签
    UI.createLabel({
        name = "SenderLabel",
        size = UDim2.new(1, 0, 0.5, 0),
        position = UDim2.new(0, 5, 0, 0),
        text = sender .. ":",
        textSize = 12,
        textColor = sender == "You" and UI.Colors.TextGreen or UI.Colors.TextYellow,
        textXAlignment = Enum.TextXAlignment.Left,
        font = Enum.Font.SourceSansBold,
        transparent = true,
        parent = messageFrame
    })
    
    -- 消息内容标签
    UI.createLabel({
        name = "MessageLabel",
        size = UDim2.new(1, -10, 0.5, 0),
        position = UDim2.new(0, 10, 0.5, 0),
        text = message,
        textSize = 11,
        textColor = UI.Colors.TextWhite,
        textXAlignment = Enum.TextXAlignment.Left,
        textWrapped = true,
        font = Enum.Font.SourceSans,
        transparent = true,
        parent = messageFrame
    })
    
    -- 更新容器大小
    container.Size = UDim2.new(1, 0, 0, (messageCount + 1) * messageHeight)
    
    -- 更新滚动框的画布大小并滚动到底部
    local scrollingFrame = container.Parent
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, container.Size.Y.Offset)
    scrollingFrame.CanvasPosition = Vector2.new(0, math.max(0, container.Size.Y.Offset - scrollingFrame.AbsoluteSize.Y))
end

-- 为GameGui添加聊天功能的辅助函数
local function addChatToGameGui(gameGui)
    if not gameGui then
        gameGui = LocalPlayer.PlayerGui:FindFirstChild("GameGui")
        if not gameGui then
            print("Error: GameGui not found when trying to add chat")
            return false
        end
    end
    
    -- 检查是否已经添加了聊天功能
    if gameGui:FindFirstChild("ChatFrame") then
        return true -- 已经存在
    end
    
    print("Adding chat to GameGui")
    
    -- 找到主内容框架
    local contentFrame = gameGui:FindFirstChild("ContentFrame", true)
    if not contentFrame then
        print("Error: ContentFrame not found")
        return false
    end
    
    -- 创建聊天框架
    local chatFrame = UI.createFrame({
        name = "ChatFrame",
        size = UDim2.new(0.25, -10, 1, -20),
        position = UDim2.new(0.75, 5, 0, 10),
        backgroundColor = UI.Colors.Panel,
        borderSize = 2,
        borderColor = UI.Colors.Border,
        parent = contentFrame
    })
    
    -- 聊天标题
    UI.createLabel({
        name = "ChatTitle",
        size = UDim2.new(1, 0, 0.1, 0),
        text = "Chat",
        textSize = 24,
        backgroundColor = UI.Colors.Background,
        borderSize = 1,
        borderColor = UI.Colors.Border,
        font = Enum.Font.SourceSansBold,
        parent = chatFrame
    })
    
    -- 聊天显示区域
    local chatDisplay = UI.createScrollingFrame({
        name = "ChatDisplay",
        size = UDim2.new(1, -10, 0.8, -10),
        position = UDim2.new(0, 5, 0.1, 5),
        backgroundColor = UI.Colors.Panel,
        borderSize = 1,
        borderColor = UI.Colors.Border,
        scrollBarThickness = 8,
        cornerRadius = UDim.new(0, 8),
        parent = chatFrame
    })
    
    -- 聊天消息容器
    local chatContainer = UI.createFrame({
        name = "ChatContainer",
        size = UDim2.new(1, -15, 1, 0),
        backgroundTransparency = 1,
        parent = chatDisplay
    })
    
    -- 聊天输入区域
    local inputFrame = UI.createFrame({
        name = "InputFrame",
        size = UDim2.new(1, -10, 0.1, -10),
        position = UDim2.new(0, 5, 0.9, 5),
        backgroundTransparency = 1,
        parent = chatFrame
    })
    
    -- 聊天输入框
    local chatInput = Instance.new("TextBox")
    chatInput.Name = "ChatInput"
    chatInput.Size = UDim2.new(0.7, -5, 1, 0)
    chatInput.Position = UDim2.new(0, 0, 0, 0)
    chatInput.PlaceholderText = "Type message..."
    chatInput.TextSize = 14
    chatInput.BackgroundColor3 = UI.Colors.TextWhite
    chatInput.TextColor3 = Color3.fromRGB(0, 0, 0)
    chatInput.BorderSizePixel = 1
    chatInput.BorderColor3 = UI.Colors.Border
    chatInput.Font = Enum.Font.SourceSans
    chatInput.TextXAlignment = Enum.TextXAlignment.Left
    chatInput.Parent = inputFrame
    
    -- 发送按钮
    local sendBtn = UI.createButton({
        name = "SendButton",
        size = UDim2.new(0.3, -5, 1, 0),
        position = UDim2.new(0.7, 5, 0, 0),
        text = "Send",
        textSize = 14,
        backgroundColor = UI.Colors.ButtonGreen,
        cornerRadius = UDim.new(0, 6),
        parent = inputFrame
    })
    
    -- 发送消息功能
    local function sendMessage()
        if chatInput.Text ~= "" and ClientMatchState.GetMatchId() then
            print("Sending message:", chatInput.Text)
            MatchMessage:FireServer({matchId = ClientMatchState.GetMatchId(), message = chatInput.Text})
            addMessageToChat("You", chatInput.Text, chatContainer)
            chatInput.Text = ""
        end
    end
    
    sendBtn.MouseButton1Click:Connect(sendMessage)
    chatInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            sendMessage()
        end
    end)
    
    -- 处理缓存的消息
    for _, messageData in ipairs(pendingMessages) do
        addMessageToChat(messageData.sender, messageData.message, chatContainer)
    end
    pendingMessages = {} -- 清空缓存
    
    return true -- 成功添加
end

-- 监听GameGui创建事件
GameGuiCreated:Connect(function(gameGui)
    print("ChatClient: Received GameGui created event")
    addChatToGameGui(gameGui)
end)

-- 监听聊天消息事件
MatchMessage:Connect(function(data)
    -- data = {matchId = ..., from = ..., message = ...}
    
    -- 只处理当前比赛的消息
    if data.matchId == ClientMatchState.GetMatchId() then
        -- 找到聊天容器并添加消息
        local gameGui = LocalPlayer.PlayerGui:FindFirstChild("GameGui")
        if gameGui then
            local chatContainer = gameGui:FindFirstChild("ChatContainer", true)
            if chatContainer then
                addMessageToChat(data.from, data.message, chatContainer)
            else
                -- 聊天容器还不存在，缓存消息
                print("Chat container not found, caching message from:", data.from)
                table.insert(pendingMessages, {sender = data.from, message = data.message})
            end
        else
            -- GameGui还不存在，缓存消息
            print("GameGui not found, caching message from:", data.from)
            table.insert(pendingMessages, {sender = data.from, message = data.message})
        end
    end
end) 

return M