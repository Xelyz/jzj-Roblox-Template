-- BackgroundManager.lua
-- 永久存在的全屏桌面背景，位于所有界面之下。

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIUtils = require(script.Parent.Parent.Client.ClientUIUtils)

local BackgroundManager = {}

-- 创建永久背景
function BackgroundManager.createBackground()
    local backgroundScreen = UIUtils.createScreen("DefaultBackground", { DisplayOrder = -1000 })

    local backgroundFrame = UIUtils.createBackground(backgroundScreen, true)
    backgroundFrame.Name = "MainBackground"

    -- 四周暗角，让中间的桌面更亮。
    local vignette = UIUtils.createFrame({
        name = "Vignette",
        parent = backgroundFrame,
        backgroundColor = UIUtils.Colors.Shadow,
        backgroundTransparency = 0,
    })
    local gradient = Instance.new("UIGradient")
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(0.3, 1),
        NumberSequenceKeypoint.new(0.7, 1),
        NumberSequenceKeypoint.new(1, 0.55),
    })
    gradient.Parent = vignette

    backgroundScreen.Parent = playerGui
    return backgroundScreen
end

-- 初始化背景系统
function BackgroundManager.init()
    BackgroundManager.createBackground()

    -- 重生后背景丢失时重新创建
    player.CharacterAdded:Connect(function()
        if not playerGui:FindFirstChild("DefaultBackground") then
            BackgroundManager.createBackground()
        end
    end)
end

BackgroundManager.init()

return BackgroundManager
