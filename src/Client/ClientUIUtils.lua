-- UIUtils - 简化的UI工具模块

local UI = {}

-- 简化的颜色配置
UI.Colors = {
    Background = Color3.fromRGB(25, 25, 35),
    Panel = Color3.fromRGB(40, 40, 50),
    
    ButtonGreen = Color3.fromRGB(60, 120, 60),
    ButtonRed = Color3.fromRGB(120, 60, 60),
    ButtonBlue = Color3.fromRGB(60, 60, 120),
    ButtonGray = Color3.fromRGB(80, 80, 100),
    ButtonDisabled = Color3.fromRGB(100, 100, 100),
    
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextGray = Color3.fromRGB(200, 200, 200),
    TextGreen = Color3.fromRGB(100, 255, 100),
    TextYellow = Color3.fromRGB(255, 255, 100),
    TextRed = Color3.fromRGB(255, 100, 100),
    
    Border = Color3.fromRGB(100, 100, 120),
    BorderAccent = Color3.fromRGB(120, 120, 140)
}

-- 创建ScreenGui
function UI.createScreen(name)
    local screen = Instance.new("ScreenGui")
    screen.Name = name
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    return screen
end

-- 创建背景Frame
function UI.createBackground(parent, useGradient)
    local bg = Instance.new("Frame")
    bg.Name = "BackgroundFrame"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Position = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3 = UI.Colors.Background
    bg.BorderSizePixel = 0
    bg.Parent = parent
    
    if useGradient then
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, UI.Colors.Background),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
        }
        gradient.Rotation = 45
        gradient.Parent = bg
    end
    
    return bg
end

-- 创建Frame
function UI.createFrame(config)
    local frame = Instance.new("Frame")
    frame.Name = config.name or "Frame"
    frame.Size = config.size or UDim2.new(1, 0, 1, 0)
    frame.Position = config.position or UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    frame.BackgroundTransparency = config.backgroundTransparency or 0
    frame.BorderSizePixel = config.borderSize or 0
    frame.BorderColor3 = config.borderColor or UI.Colors.Border
    frame.Parent = config.parent
    frame.ZIndex = config.zIndex or 0

    if config.corner then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = config.cornerRadius or UDim.new(0, 10)
        corner.Parent = frame
    end
    return frame
end

-- 创建Label
function UI.createLabel(config)
    local label = Instance.new("TextLabel")
    label.Name = config.name or "Label"
    label.Size = config.size or UDim2.new(1, 0, 1, 0)
    label.Position = config.position or UDim2.new(0, 0, 0, 0)
    label.Text = config.text or ""
    label.TextSize = config.textSize or 18
    label.TextColor3 = config.textColor or UI.Colors.TextWhite
    label.Font = config.font or Enum.Font.SourceSans
    label.TextXAlignment = config.textXAlignment or Enum.TextXAlignment.Center
    label.TextYAlignment = config.textYAlignment or Enum.TextYAlignment.Center
    label.TextWrapped = config.textWrapped or true
    label.TextScaled = config.textScaled or true
    label.BackgroundTransparency = config.transparent and 1 or 0
    label.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    label.BorderSizePixel = config.borderSize or 0
    label.BorderColor3 = config.borderColor or UI.Colors.Border
    label.Parent = config.parent
    label.ZIndex = config.zIndex or 0

    if config.corner and not config.transparent then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = config.cornerRadius or UDim.new(0, 5)
        corner.Parent = label
    end
    return label
end

-- 创建Button
function UI.createButton(config)
    local button = Instance.new("TextButton")
    button.Name = config.name or "Button"
    button.Size = config.size or UDim2.new(0.2, 0, 0.08, 0)
    button.Position = config.position or UDim2.new(0, 0, 0, 0)
    button.Text = ""

    UI.createLabel(
        {
            name = "ButtonLabel",
            text = config.text or "Button",
            parent = button,
            size = UDim2.new(0.8, 0, 0.8, 0),
            position = UDim2.new(0.1, 0, 0.1, 0),
            textSize = config.textSize or 18,
            textColor = config.textColor or UI.Colors.TextWhite,
            textScaled = config.textScaled or true,
            textWrapped = config.textWrapped or true,
            font = config.font or Enum.Font.SourceSansBold,
            transparent = true,
            zIndex = config.zIndex or 0
        }
    )

    button.BackgroundColor3 = config.backgroundColor or UI.Colors.ButtonGray
    button.BorderSizePixel = config.borderSize or 0
    button.BorderColor3 = config.borderColor or UI.Colors.Border
    button.Parent = config.parent
    button.ZIndex = config.zIndex or 0
    button:SetAttribute("originalColor", button.BackgroundColor3)

    if config.corner then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = config.cornerRadius or UDim.new(0, 8)
        corner.Parent = button
    end
    if config.onClick then
        button.MouseButton1Click:Connect(config.onClick)
    end
    return button
end

-- 创建ScrollingFrame
function UI.createScrollingFrame(config)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = config.name or "ScrollFrame"
    scrollFrame.Size = config.size or UDim2.new(1, 0, 1, 0)
    scrollFrame.Position = config.position or UDim2.new(0, 0, 0, 0)
    scrollFrame.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    scrollFrame.BorderSizePixel = config.borderSize or 2
    scrollFrame.BorderColor3 = config.borderColor or UI.Colors.Border
    scrollFrame.ScrollBarThickness = config.scrollBarThickness or 10
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = config.parent
    scrollFrame.ZIndex = config.zIndex or 0

    if config.corner then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = config.cornerRadius or UDim.new(0, 10)
        corner.Parent = scrollFrame
    end
    if config.listLayout then
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = config.listPadding or UDim.new(0, 5)
        layout.Parent = scrollFrame
    end
    return scrollFrame
end

-- 创建标题
function UI.createTitle(text, parent, size, position)
    return UI.createLabel({
        name = "TitleLabel",
        text = text,
        parent = parent,
        size = size or UDim2.new(1, 0, 0.1, 0),
        position = position or UDim2.new(0, 0, 0.05, 0),
        textSize = 36,
        font = Enum.Font.SourceSansBold,
        transparent = true
    })
end

-- 添加圆角
function UI.addCorner(element, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = radius or UDim.new(0, 8)
    corner.Parent = element
    return corner
end

-- 设置按钮启用/禁用
function UI.setButtonEnabled(button, enabled)
    if enabled then
        button.BackgroundColor3 = button:GetAttribute("originalColor") or UI.Colors.ButtonGreen
        button:FindFirstChild("ButtonLabel").TextColor3 = UI.Colors.TextWhite
    else
        button.BackgroundColor3 = UI.Colors.ButtonDisabled
        button:FindFirstChild("ButtonLabel").TextColor3 = UI.Colors.TextGray
    end
end

-- 按钮样式
function UI.styleButton(button, style)
    if style == "success" then
        button.BackgroundColor3 = UI.Colors.ButtonGreen
    elseif style == "danger" then
        button.BackgroundColor3 = UI.Colors.ButtonRed
    elseif style == "primary" then
        button.BackgroundColor3 = UI.Colors.ButtonBlue
    else
        button.BackgroundColor3 = UI.Colors.ButtonGray
    end
end

function UI.createAvatarImage(config)
    local container = UI.createFrame({
        name = config.name or "AvatarContainer",
        parent = config.parent,
        size = config.size or UDim2.new(0, 60, 0, 60),
        position = config.position or UDim2.new(0, 0, 0, 0),
        backgroundTransparency = 1,
        zIndex = config.zIndex or 0
    })

    local background = UI.createFrame({
        name = "AvatarBackground",
        parent = container,
        size = UDim2.new(1, 0, 1, 0),
        position = UDim2.new(0, 0, 0, 0),
        backgroundColor = config.backgroundColor or Color3.fromRGB(255, 255, 255),
        borderSize = config.borderSize or 0,
        borderColor = config.borderColor or UI.Colors.Border,
        corner = true,
        cornerRadius = config.cornerRadius or UDim.new(0.5, 0),
        zIndex = config.zIndex or 0
    })

    -- 如果指定了保持圆形，添加宽高比约束
    if config.keepSquare ~= false then
        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.AspectType = Enum.AspectType.FitWithinMaxSize
        aspect.Parent = background
    end

    local image = Instance.new("ImageLabel")
    image.Name = "AvatarImage"
    local imagePadding = config.imagePadding or 2
    image.Size = UDim2.new(1, -imagePadding * 2, 1, -imagePadding * 2)
    image.Position = UDim2.new(0, imagePadding, 0, imagePadding)
    image.Image = "rbxthumb://type=AvatarHeadShot&id=" .. config.userId .. "&w=150&h=150"
    image.BackgroundTransparency = 1
    image.ZIndex = config.zIndex or 0
    image.Parent = background
    
    UI.addCorner(image, config.cornerRadius or UDim.new(0.5, 0))
    
    return container
end

return UI 