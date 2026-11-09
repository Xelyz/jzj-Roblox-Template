local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local SignalManager = require(script.Parent.Parent.SignalManager)
local Config = require(script.Parent.Parent.Config)
local UI = require(script.Parent.ClientUIUtils)
local ClientMatchState = require(script.Parent.MatchStateClient)

local GameGuiCreated = SignalManager.GetBindable("GameGuiCreated")
local localPlayer = Players.LocalPlayer

-- 查找 Roblox 授权的本地发送者。
local function getLocalSource(channel)
    for _, source in ipairs(channel:GetChildren()) do
        if source:IsA("TextSource") and source.UserId == localPlayer.UserId then
            return source
        end
    end
    return nil
end

-- 把原生频道窗口和输入框挂到对局界面。
GameGuiCreated:Connect(function(gameGui)
    local matchId = ClientMatchState.GetMatchId()
    local contentFrame = gameGui:FindFirstChild("ContentFrame", true)
    if not matchId or not contentFrame then
        return
    end

    local channel = TextChatService:WaitForChild(matchId, 10)
    if not gameGui.Parent or ClientMatchState.GetMatchId() ~= matchId then
        return
    end
    if not channel or not channel:IsA("TextChannel") then
        warn("Match chat channel unavailable:", matchId)
        return
    end

    -- 宿主界面可提供 ChatSlot 指定聊天位置，否则放在内容区右侧。
    local slot = gameGui:FindFirstChild("ChatSlot", true)
    local frame = UI.createFrame({
        name = "ChatFrame",
        size = slot and UDim2.new(1, 0, 1, 0) or UDim2.new(0.25, -10, 1, -20),
        position = slot and UDim2.new(0, 0, 0, 0) or UDim2.new(0.75, 5, 0, 10),
        backgroundColor = UI.Colors.Ink,
        corner = true,
        cornerRadius = UDim.new(0, 14),
        stroke = true,
        strokeThickness = 3,
        parent = slot or contentFrame
    })

    UI.createLabel({
        name = "ChatTitle",
        parent = frame,
        text = "Table Talk",
        size = UDim2.new(1, -24, 0, 30),
        position = UDim2.new(0, 12, 0, 6),
        textSize = 20,
        font = UI.Fonts.Display,
        textColor = UI.Colors.Honey,
        textXAlignment = Enum.TextXAlignment.Left,
    })

    local window = Instance.new("TextChannelWindow")
    window.Name = "MatchChatWindow"
    window.Size = UDim2.new(1, -12, 1, -88)
    window.Position = UDim2.new(0, 6, 0, 38)
    window.BackgroundTransparency = 1
    window.Target = channel
    window.Parent = frame

    local input = Instance.new("TextBox")
    input.Name = "ChatInput"
    input.AnchorPoint = Vector2.new(0, 1)
    input.Size = UDim2.new(1, -20, 0, 38)
    input.Position = UDim2.new(0, 10, 1, -10)
    input.PlaceholderText = "Type a message and press Enter"
    input.PlaceholderColor3 = UI.Colors.InkSoft
    input.Text = ""
    input.TextSize = 17
    input.Font = UI.Fonts.Medium
    input.TextColor3 = UI.Colors.Ink
    input.BackgroundColor3 = UI.Colors.Paper
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.ClearTextOnFocus = false
    input.Visible = false
    UI.addCorner(input, UDim.new(0, 10))
    UI.addPadding(input, 0, 10)
    input.Parent = frame

    local sourceConnection
    local function refreshInput()
        if sourceConnection then
            sourceConnection:Disconnect()
            sourceConnection = nil
        end
        local source = getLocalSource(channel)
        input.Visible = source ~= nil and source.CanSend
        if source then
            sourceConnection = source:GetPropertyChangedSignal("CanSend"):Connect(refreshInput)
        end
    end

    local addedConnection = channel.ChildAdded:Connect(refreshInput)
    local removedConnection = channel.ChildRemoved:Connect(refreshInput)
    frame.Destroying:Connect(function()
        addedConnection:Disconnect()
        removedConnection:Disconnect()
        if sourceConnection then
            sourceConnection:Disconnect()
        end
    end)
    refreshInput()

    local nextSendAt = 0
    input.FocusLost:Connect(function(enterPressed)
        local message = input.Text
        local length = utf8.len(message)
        if not enterPressed or not input.Visible or not channel.Parent
            or not message:find("%S") or not length or length > Config.chat.maxMessageLength
            or os.clock() < nextSendAt
        then
            return
        end

        nextSendAt = os.clock() + Config.chat.cooldownTime
        input.Text = ""
        local ok, result = pcall(channel.SendAsync, channel, message)
        if not ok then
            warn("Match chat send failed:", matchId, "SendAsync failed")
        elseif result.Status ~= Enum.TextChatMessageStatus.Sending
            and result.Status ~= Enum.TextChatMessageStatus.Success
        then
            warn("Match chat send failed:", matchId, tostring(result.Status))
        end
    end)
end)

return {}
