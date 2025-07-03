local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MatchMessage = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchMessage")
local ClientMatchState = require(game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("ClientMatchState"))

local GameGuiCreated = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Client"):WaitForChild("GameGuiCreated")

-- 消息缓存机制
local pendingMessages = {}

-- 添加消息到聊天显示区域
local function addMessageToChat(sender, message, container)
    local messageCount = #container:GetChildren()
    local messageHeight = 30 -- 增加消息高度以适应更大的字体
    
    local messageFrame = Instance.new("Frame")
    messageFrame.Size = UDim2.new(1, -5, 0, messageHeight)
    messageFrame.Position = UDim2.new(0, 0, 0, messageCount * messageHeight)
    messageFrame.BackgroundTransparency = 1
    messageFrame.Parent = container
    
    -- 发送者标签
    local senderLabel = Instance.new("TextLabel")
    senderLabel.Size = UDim2.new(1, 0, 0.5, 0)
    senderLabel.Position = UDim2.new(0, 5, 0, 0)
    senderLabel.Text = sender .. ":"
    senderLabel.TextSize = 12
    senderLabel.TextColor3 = sender == "You" and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 200, 100)
    senderLabel.BackgroundTransparency = 1
    senderLabel.TextXAlignment = Enum.TextXAlignment.Left
    senderLabel.Font = Enum.Font.SourceSansBold
    senderLabel.Parent = messageFrame
    
    -- 消息内容标签
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -10, 0.5, 0)
    messageLabel.Position = UDim2.new(0, 10, 0.5, 0)
    messageLabel.Text = message
    messageLabel.TextSize = 11
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.BackgroundTransparency = 1
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextWrapped = true
    messageLabel.Font = Enum.Font.SourceSans
    messageLabel.Parent = messageFrame
    
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
    
    -- 创建聊天框架，占据右侧25%的空间
    local chatFrame = Instance.new("Frame")
    chatFrame.Name = "ChatFrame"
    chatFrame.Size = UDim2.new(0.25, -10, 1, -20) -- 从35%减少到25%宽度
    chatFrame.Position = UDim2.new(0.75, 5, 0, 10) -- 从75%位置开始
    chatFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    chatFrame.BorderSizePixel = 2
    chatFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    chatFrame.Parent = contentFrame
    
    -- 聊天标题
    local chatTitle = Instance.new("TextLabel")
    chatTitle.Size = UDim2.new(1, 0, 0.1, 0)
    chatTitle.Position = UDim2.new(0, 0, 0, 0)
    chatTitle.Text = "Chat"
    chatTitle.TextSize = 24
    chatTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    chatTitle.BorderSizePixel = 1  -- 添加边框
    chatTitle.BorderColor3 = Color3.fromRGB(100, 100, 100)  -- 边框颜色
    chatTitle.Font = Enum.Font.SourceSansBold
    chatTitle.Parent = chatFrame
    
    -- 聊天显示区域
    local chatDisplay = Instance.new("ScrollingFrame")
    chatDisplay.Name = "ChatDisplay"
    chatDisplay.Size = UDim2.new(1, -10, 0.8, -10) -- 占80%高度减去标题和输入框
    chatDisplay.Position = UDim2.new(0, 5, 0.1, 5)
    chatDisplay.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    chatDisplay.BorderSizePixel = 1
    chatDisplay.BorderColor3 = Color3.fromRGB(80, 80, 80)
    chatDisplay.ScrollBarThickness = 8
    chatDisplay.CanvasSize = UDim2.new(0, 0, 1, 0)
    chatDisplay.Parent = chatFrame
    
    -- 聊天消息容器
    local chatContainer = Instance.new("Frame")
    chatContainer.Name = "ChatContainer"
    chatContainer.Size = UDim2.new(1, -15, 1, 0) -- 为滚动条留空间
    chatContainer.Position = UDim2.new(0, 0, 0, 0)
    chatContainer.BackgroundTransparency = 1
    chatContainer.Parent = chatDisplay
    
    -- 聊天输入区域
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, -10, 0.1, -10)
    inputFrame.Position = UDim2.new(0, 5, 0.9, 5)
    inputFrame.BackgroundTransparency = 1
    inputFrame.Parent = chatFrame
    
    -- 聊天输入框
    local chatInput = Instance.new("TextBox")
    chatInput.Name = "ChatInput"
    chatInput.Size = UDim2.new(0.7, -5, 1, 0)
    chatInput.Position = UDim2.new(0, 0, 0, 0)
    chatInput.PlaceholderText = "Type message..."
    chatInput.TextSize = 14
    chatInput.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    chatInput.TextColor3 = Color3.fromRGB(0, 0, 0)
    chatInput.BorderSizePixel = 1
    chatInput.BorderColor3 = Color3.fromRGB(100, 100, 100)
    chatInput.Font = Enum.Font.SourceSans
    chatInput.TextXAlignment = Enum.TextXAlignment.Left
    chatInput.Parent = inputFrame
    
    -- 发送按钮
    local sendBtn = Instance.new("TextButton")
    sendBtn.Name = "SendButton"
    sendBtn.Size = UDim2.new(0.3, -5, 1, 0)
    sendBtn.Position = UDim2.new(0.7, 5, 0, 0)
    sendBtn.Text = "Send"
    sendBtn.TextSize = 14
    sendBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.Font = Enum.Font.SourceSansBold
    sendBtn.Parent = inputFrame
    
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
GameGuiCreated.Event:Connect(function(gameGui)
    print("ChatClient: Received GameGui created event")
    addChatToGameGui(gameGui)
end)

-- 监听聊天消息事件
MatchMessage.OnClientEvent:Connect(function(data)
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

-- ChatClient作为LocalScript运行，不需要return 