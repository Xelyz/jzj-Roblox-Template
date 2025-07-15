-- BackgroundManager.lua
-- 永久存在的全屏默认背景管理器
-- 使用ClientUIUtils创建美观的渐变背景

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 获取ClientUIUtils
local UIUtils = require(script.Parent.Parent.Client.ClientUIUtils)

local BackgroundManager = {}

-- 创建永久背景
function BackgroundManager.createBackground()
    -- 创建主背景ScreenGui
    local backgroundScreen = UIUtils.createScreen("DefaultBackground")
    backgroundScreen.DisplayOrder = -1000 -- 确保在最底层
    backgroundScreen.Parent = playerGui
    
    -- 创建带渐变的背景Frame
    local backgroundFrame = UIUtils.createBackground(backgroundScreen, true)
    backgroundFrame.Name = "MainBackground"
    
    -- 添加一些装饰性元素
    local decorFrame = UIUtils.createFrame({
        name = "DecorationFrame",
        parent = backgroundFrame,
        size = UDim2.new(1, 0, 1, 0),
        position = UDim2.new(0, 0, 0, 0),
        backgroundColor = Color3.fromRGB(0, 0, 0),
        backgroundTransparency = 0.8,
        borderSize = 0
    })
    
    -- 添加细微的纹理效果
    local textureGradient = Instance.new("UIGradient")
    textureGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
    }
    textureGradient.Rotation = 90
    textureGradient.Parent = decorFrame
    
    print("永久全屏背景已创建")
    
    return backgroundScreen
end

-- 初始化背景系统
function BackgroundManager.init()
    -- 等待PlayerGui加载完成
    if not playerGui then
        playerGui = player:WaitForChild("PlayerGui")
    end
    
    -- 创建背景
    local backgroundScreen = BackgroundManager.createBackground()
    
    -- 确保背景在重生时保持存在
    backgroundScreen.ResetOnSpawn = false
    
    -- 监听玩家重生，确保背景始终存在
    player.CharacterAdded:Connect(function()
        -- 检查背景是否仍然存在，如果不存在就重新创建
        if not playerGui:FindFirstChild("DefaultBackground") then
            BackgroundManager.createBackground()
        end
    end)
    
    print("背景管理器初始化完成")
end

-- 自动初始化
BackgroundManager.init()

return BackgroundManager 