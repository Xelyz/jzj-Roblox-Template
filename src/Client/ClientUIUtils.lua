-- UIUtils - 桌游风格 UI 工具模块
-- 纸面面板、描边按钮和硬阴影组成统一主题。界面放在按屏幕缩放的设计画布上。

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

-- 主题色。旧键保留给现有调用方，新键用于桌游主题。
UI.Colors = {
    -- 桌面与纸面
    Table = Color3.fromRGB(58, 43, 34),
    TableDark = Color3.fromRGB(36, 27, 21),
    Paper = Color3.fromRGB(246, 236, 214),
    PaperDark = Color3.fromRGB(233, 218, 188),
    PaperDeep = Color3.fromRGB(216, 197, 160),
    Ink = Color3.fromRGB(51, 38, 28),
    InkSoft = Color3.fromRGB(122, 102, 80),
    Outline = Color3.fromRGB(51, 38, 28),
    Shadow = Color3.fromRGB(20, 14, 10),
    Honey = Color3.fromRGB(242, 179, 61),
    HoneyDark = Color3.fromRGB(196, 132, 26),

    -- 语义色
    Green = Color3.fromRGB(93, 174, 91),
    Blue = Color3.fromRGB(79, 139, 214),
    Red = Color3.fromRGB(216, 96, 74),
    Sand = Color3.fromRGB(196, 178, 146),

    -- 兼容旧键
    Background = Color3.fromRGB(58, 43, 34),
    Panel = Color3.fromRGB(246, 236, 214),

    ButtonGreen = Color3.fromRGB(93, 174, 91),
    ButtonRed = Color3.fromRGB(216, 96, 74),
    ButtonBlue = Color3.fromRGB(79, 139, 214),
    ButtonGray = Color3.fromRGB(196, 178, 146),
    ButtonDisabled = Color3.fromRGB(214, 204, 184),

    TextWhite = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(51, 38, 28),
    TextGray = Color3.fromRGB(122, 102, 80),
    TextGreen = Color3.fromRGB(56, 128, 56),
    TextYellow = Color3.fromRGB(196, 132, 26),
    TextRed = Color3.fromRGB(190, 70, 52),
    TextError = Color3.fromRGB(190, 70, 52),

    Border = Color3.fromRGB(51, 38, 28),
    BorderAccent = Color3.fromRGB(122, 102, 80),
}

UI.Fonts = {
    Display = Enum.Font.FredokaOne,
    Body = Enum.Font.BuilderSans,
    Medium = Enum.Font.BuilderSansMedium,
    Bold = Enum.Font.BuilderSansBold,
    Heavy = Enum.Font.BuilderSansExtraBold,
}

-- 设计画布尺寸。画布等比缩放，较长的一边会扩展填满屏幕。
UI.DesignSize = Vector2.new(1280, 720)

-- 深色底上用白字，浅色底上用墨色字。
local function textColorFor(background)
    local luminance = 0.299 * background.R + 0.587 * background.G + 0.114 * background.B
    return luminance > 0.6 and UI.Colors.Ink or UI.Colors.TextWhite
end
UI.textColorFor = textColorFor

local function darken(color, amount)
    local h, s, v = color:ToHSV()
    return Color3.fromHSV(h, s, math.max(0, v - amount))
end
UI.darken = darken

local function lighten(color, amount)
    local h, s, v = color:ToHSV()
    return Color3.fromHSV(h, math.max(0, s - amount * 0.5), math.min(1, v + amount))
end
UI.lighten = lighten

-- ===============================
-- 基础装饰
-- ===============================

function UI.addCorner(element, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = radius or UDim.new(0, 8)
    corner.Parent = element
    return corner
end

function UI.addStroke(element, thickness, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 2
    stroke.Color = color or UI.Colors.Outline
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = element
    return stroke
end

function UI.addPadding(element, all, horizontal)
    local padding = Instance.new("UIPadding")
    local v = UDim.new(0, all or 8)
    local h = UDim.new(0, horizontal or all or 8)
    padding.PaddingTop = v
    padding.PaddingBottom = v
    padding.PaddingLeft = h
    padding.PaddingRight = h
    padding.Parent = element
    return padding
end

function UI.addList(element, config)
    config = config or {}
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = config.direction or Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, config.padding or 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = config.horizontalAlignment or Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = config.verticalAlignment or Enum.VerticalAlignment.Top
    layout.Parent = element
    return layout
end

-- ScrollingFrame 按内容自动调整画布高度。
function UI.autoCanvas(scrollFrame, layout)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    return layout
end

-- ===============================
-- 屏幕与画布
-- ===============================

-- 创建 ScreenGui。props 可覆盖 ScreenGui 属性。
function UI.createScreen(name, props)
    local screen = Instance.new("ScreenGui")
    screen.Name = name
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if props then
        for key, value in pairs(props) do
            screen[key] = value
        end
    end
    return screen
end

-- 在 ScreenGui 中创建按设计尺寸缩放的画布。短边按设计尺寸适配，长边扩展。
function UI.createStage(screenGui, designSize)
    designSize = designSize or UI.DesignSize

    local stage = Instance.new("Frame")
    stage.Name = "Stage"
    stage.AnchorPoint = Vector2.new(0.5, 0.5)
    stage.Position = UDim2.new(0.5, 0, 0.5, 0)
    stage.Size = UDim2.new(0, designSize.X, 0, designSize.Y)
    stage.BackgroundTransparency = 1
    stage.Parent = screenGui

    local scale = Instance.new("UIScale")
    scale.Parent = stage

    local function refresh()
        local screenSize = screenGui.AbsoluteSize
        if screenSize.X <= 0 or screenSize.Y <= 0 then
            return
        end
        local factor = math.min(screenSize.X / designSize.X, screenSize.Y / designSize.Y)
        factor = math.max(factor, 0.35)
        scale.Scale = factor
        stage.Size = UDim2.new(0, math.floor(screenSize.X / factor), 0, math.floor(screenSize.Y / factor))
    end

    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
    screenGui.AncestryChanged:Connect(refresh)
    refresh()
    return stage
end

-- 桌面背景：深木色渐变和柔和暗角。
function UI.createBackground(parent, useGradient)
    local bg = Instance.new("Frame")
    bg.Name = "BackgroundFrame"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Position = UDim2.new(0, 0, 0, 0)
    -- UIGradient 颜色与底色相乘，底色用白色才能得到渐变原色。
    bg.BackgroundColor3 = Color3.new(1, 1, 1)
    bg.BorderSizePixel = 0
    bg.Parent = parent

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 80, 56)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(84, 60, 43)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 40, 30)),
    })
    gradient.Rotation = useGradient == false and 90 or 70
    gradient.Parent = bg

    -- 木纹般的细横条，透明度很高，只提供底色纹理。
    for i = 1, 6 do
        local grain = Instance.new("Frame")
        grain.Name = "Grain"
        grain.BorderSizePixel = 0
        grain.BackgroundColor3 = UI.Colors.Shadow
        grain.BackgroundTransparency = 0.9
        grain.Size = UDim2.new(1, 0, 0, 2)
        grain.Position = UDim2.new(0, 0, i / 7, (i % 2) * 9)
        grain.Parent = bg
    end

    return bg
end

-- ===============================
-- 基础元件（保持旧 config 字段兼容）
-- ===============================

function UI.createFrame(config)
    local frame = Instance.new("Frame")
    frame.Name = config.name or "Frame"
    frame.AnchorPoint = config.anchorPoint or Vector2.new(0, 0)
    frame.Size = config.size or UDim2.new(1, 0, 1, 0)
    frame.Position = config.position or UDim2.new(0, 0, 0, 0)
    frame.Rotation = config.rotation or 0
    frame.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    frame.BackgroundTransparency = config.backgroundTransparency or 0
    frame.BorderSizePixel = config.borderSize or 0
    frame.BorderColor3 = config.borderColor or UI.Colors.Border
    frame.ZIndex = config.zIndex or 1
    if config.layoutOrder then
        frame.LayoutOrder = config.layoutOrder
    end
    if config.corner then
        UI.addCorner(frame, config.cornerRadius or UDim.new(0, 10))
    end
    if config.stroke then
        UI.addStroke(frame, config.strokeThickness, config.strokeColor)
    end
    frame.Parent = config.parent
    return frame
end

function UI.createCanvas(config)
    local canvas = Instance.new("CanvasGroup")
    canvas.Name = config.name or "Canvas"
    canvas.AnchorPoint = config.anchorPoint or Vector2.new(0, 0)
    canvas.Size = config.size or UDim2.new(1, 0, 1, 0)
    canvas.Position = config.position or UDim2.new(0, 0, 0, 0)
    canvas.Rotation = config.rotation or 0
    canvas.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    canvas.BackgroundTransparency = config.backgroundTransparency or 0
    canvas.ZIndex = config.zIndex or 1
    canvas.Parent = config.parent
    return canvas
end

-- 文本默认使用固定字号；传 textScaled = true 时按框缩放，字号作为上限。
function UI.createLabel(config)
    local label = Instance.new("TextLabel")
    label.Name = config.name or "Label"
    label.AnchorPoint = config.anchorPoint or Vector2.new(0, 0)
    label.Size = config.size or UDim2.new(1, 0, 1, 0)
    label.Position = config.position or UDim2.new(0, 0, 0, 0)
    label.Rotation = config.rotation or 0
    label.Text = config.text or ""
    label.RichText = config.richText or false
    label.TextSize = config.textSize or 18
    label.TextColor3 = config.textColor or UI.Colors.Ink
    label.Font = config.font or UI.Fonts.Medium
    label.TextXAlignment = config.textXAlignment or Enum.TextXAlignment.Center
    label.TextYAlignment = config.textYAlignment or Enum.TextYAlignment.Center
    label.TextWrapped = config.textWrapped ~= false
    label.TextTruncate = config.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    label.TextScaled = config.textScaled == true
    if label.TextScaled then
        local constraint = Instance.new("UITextSizeConstraint")
        constraint.MaxTextSize = config.textSize or 18
        constraint.MinTextSize = config.minTextSize or 8
        constraint.Parent = label
    end
    label.BackgroundTransparency = (config.transparent or config.backgroundColor == nil) and 1
        or (config.backgroundTransparency or 0)
    label.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    label.BorderSizePixel = config.borderSize or 0
    label.BorderColor3 = config.borderColor or UI.Colors.Border
    label.ZIndex = config.zIndex or 1
    if config.layoutOrder then
        label.LayoutOrder = config.layoutOrder
    end
    if config.automaticSize then
        label.AutomaticSize = config.automaticSize
    end
    if config.corner and not config.transparent then
        UI.addCorner(label, config.cornerRadius or UDim.new(0, 6))
    end
    label.Parent = config.parent
    return label
end

-- 按钮：描边色块 + 底部硬阴影，按下时面板下沉。
-- 结构：Button(透明 TextButton) > Shadow / Face / ButtonLabel。
function UI.createButton(config)
    local depth = config.depth or 4
    local color = config.backgroundColor or UI.Colors.ButtonGray
    local radius = config.cornerRadius or UDim.new(0, 10)
    local zIndex = config.zIndex or 1

    local button = Instance.new("TextButton")
    button.Name = config.name or "Button"
    button.AnchorPoint = config.anchorPoint or Vector2.new(0, 0)
    button.Size = config.size or UDim2.new(0, 200, 0, 52)
    button.Position = config.position or UDim2.new(0, 0, 0, 0)
    button.Text = ""
    button.AutoButtonColor = false
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.ZIndex = zIndex
    if config.layoutOrder then
        button.LayoutOrder = config.layoutOrder
    end

    local plain = config.plain or (config.backgroundTransparency or 0) >= 1

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.BorderSizePixel = 0
    shadow.BackgroundColor3 = UI.Colors.Shadow
    shadow.BackgroundTransparency = plain and 1 or 0.55
    shadow.Size = UDim2.new(1, 0, 1, -depth)
    shadow.Position = UDim2.new(0, 0, 0, depth)
    shadow.ZIndex = zIndex
    UI.addCorner(shadow, radius)
    shadow.Parent = button

    local face = Instance.new("Frame")
    face.Name = "Face"
    face.BorderSizePixel = 0
    face.BackgroundColor3 = color
    face.BackgroundTransparency = plain and 1 or 0
    face.Size = UDim2.new(1, 0, 1, -depth)
    face.Position = UDim2.new(0, 0, 0, 0)
    face.ZIndex = zIndex + 1
    UI.addCorner(face, radius)
    if not plain then
        UI.addStroke(face, config.strokeThickness or 2, UI.Colors.Outline)
    end
    face.Parent = button

    local label = UI.createLabel({
        name = "ButtonLabel",
        text = config.text or "Button",
        parent = button,
        size = UDim2.new(1, -16, 1, -depth - 4),
        position = UDim2.new(0, 8, 0, 2),
        textSize = config.textSize or 22,
        textScaled = config.textScaled,
        textColor = config.textColor or textColorFor(color),
        font = config.font or UI.Fonts.Display,
        transparent = true,
        zIndex = zIndex + 2,
    })

    button:SetAttribute("originalColor", color)
    button:SetAttribute("textColor", label.TextColor3)
    button:SetAttribute("enabled", true)

    local pressed = false
    local hovered = false
    local function refreshVisual()
        if button:GetAttribute("enabled") == false then
            face.Position = UDim2.new(0, 0, 0, 0)
            label.Position = UDim2.new(0, 8, 0, 2)
            return
        end
        local base = button:GetAttribute("originalColor") or color
        if plain then
            face.BackgroundTransparency = hovered and 0.85 or 1
            face.BackgroundColor3 = UI.Colors.Ink
        else
            face.BackgroundColor3 = hovered and lighten(base, 0.08) or base
        end
        local offset = pressed and math.floor(depth * 0.75) or 0
        face.Position = UDim2.new(0, 0, 0, offset)
        label.Position = UDim2.new(0, 8, 0, 2 + offset)
    end

    button.MouseEnter:Connect(function()
        hovered = true
        refreshVisual()
    end)
    button.MouseLeave:Connect(function()
        hovered = false
        pressed = false
        refreshVisual()
    end)
    button.MouseButton1Down:Connect(function()
        pressed = true
        refreshVisual()
    end)
    button.MouseButton1Up:Connect(function()
        pressed = false
        refreshVisual()
    end)
    button:GetAttributeChangedSignal("originalColor"):Connect(refreshVisual)

    if config.onClick then
        button.MouseButton1Click:Connect(function()
            if button:GetAttribute("enabled") ~= false then
                config.onClick()
            end
        end)
    end

    button.Parent = config.parent
    return button
end

function UI.createScrollingFrame(config)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = config.name or "ScrollFrame"
    scrollFrame.AnchorPoint = config.anchorPoint or Vector2.new(0, 0)
    scrollFrame.Size = config.size or UDim2.new(1, 0, 1, 0)
    scrollFrame.Position = config.position or UDim2.new(0, 0, 0, 0)
    scrollFrame.BackgroundColor3 = config.backgroundColor or UI.Colors.Panel
    scrollFrame.BackgroundTransparency = config.backgroundTransparency or 0
    scrollFrame.BorderSizePixel = config.borderSize or 0
    scrollFrame.BorderColor3 = config.borderColor or UI.Colors.Border
    scrollFrame.ScrollBarThickness = config.scrollBarThickness or 6
    scrollFrame.ScrollBarImageColor3 = UI.Colors.InkSoft
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.ZIndex = config.zIndex or 1

    if config.corner then
        UI.addCorner(scrollFrame, config.cornerRadius or UDim.new(0, 10))
    end
    if config.listLayout then
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = config.listPadding or UDim.new(0, 8)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Parent = scrollFrame
    end
    scrollFrame.Parent = config.parent
    return scrollFrame
end

function UI.createTitle(text, parent, size, position)
    return UI.createLabel({
        name = "TitleLabel",
        text = text,
        parent = parent,
        size = size or UDim2.new(1, 0, 0, 64),
        position = position or UDim2.new(0, 0, 0, 24),
        textSize = 48,
        font = UI.Fonts.Display,
        textColor = UI.Colors.Paper,
        transparent = true,
    })
end

-- 按钮启用/禁用。禁用时不响应 onClick。
function UI.setButtonEnabled(button, enabled)
    button:SetAttribute("enabled", enabled)
    local face = button:FindFirstChild("Face")
    local label = button:FindFirstChild("ButtonLabel")
    local shadow = button:FindFirstChild("Shadow")
    if enabled then
        if face then
            face.BackgroundColor3 = button:GetAttribute("originalColor") or UI.Colors.ButtonGreen
        end
        if label then
            label.TextColor3 = button:GetAttribute("textColor") or UI.Colors.TextWhite
        end
        if shadow then
            shadow.BackgroundTransparency = 0.55
        end
    else
        if face then
            face.BackgroundColor3 = UI.Colors.ButtonDisabled
        end
        if label then
            label.TextColor3 = UI.Colors.InkSoft
        end
        if shadow then
            shadow.BackgroundTransparency = 0.8
        end
    end
end

function UI.setButtonColor(button, color)
    button:SetAttribute("originalColor", color)
    local textColor = textColorFor(color)
    button:SetAttribute("textColor", textColor)
    if button:GetAttribute("enabled") ~= false then
        local face = button:FindFirstChild("Face")
        local label = button:FindFirstChild("ButtonLabel")
        if face then
            face.BackgroundColor3 = color
        end
        if label then
            label.TextColor3 = textColor
        end
    end
end

function UI.styleButton(button, style)
    if style == "success" then
        UI.setButtonColor(button, UI.Colors.ButtonGreen)
    elseif style == "danger" then
        UI.setButtonColor(button, UI.Colors.ButtonRed)
    elseif style == "primary" then
        UI.setButtonColor(button, UI.Colors.ButtonBlue)
    else
        UI.setButtonColor(button, UI.Colors.ButtonGray)
    end
end

function UI.setButtonText(button, text)
    local label = button:FindFirstChild("ButtonLabel")
    if label then
        label.Text = text
    end
end

-- ===============================
-- 桌游组件
-- ===============================

-- 纸面面板：容器 > Shadow + Body。返回 Body（放内容）和容器（定位用）。
function UI.createPanel(config)
    local depth = config.depth or 6
    local radius = config.cornerRadius or UDim.new(0, 14)

    local container = Instance.new("Frame")
    container.Name = config.name or "Panel"
    container.AnchorPoint = config.anchorPoint or Vector2.new(0, 0)
    container.Size = config.size or UDim2.new(1, 0, 1, 0)
    container.Position = config.position or UDim2.new(0, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.ZIndex = config.zIndex or 1
    if config.layoutOrder then
        container.LayoutOrder = config.layoutOrder
    end

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.BorderSizePixel = 0
    shadow.BackgroundColor3 = UI.Colors.Shadow
    shadow.BackgroundTransparency = config.shadowTransparency or 0.5
    shadow.Size = UDim2.new(1, 0, 1, -depth)
    shadow.Position = UDim2.new(0, 0, 0, depth)
    UI.addCorner(shadow, radius)
    shadow.Parent = container

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BorderSizePixel = 0
    body.BackgroundColor3 = config.backgroundColor or UI.Colors.Paper
    body.Size = UDim2.new(1, 0, 1, -depth)
    body.ZIndex = 2
    UI.addCorner(body, radius)
    UI.addStroke(body, config.strokeThickness or 3, config.strokeColor or UI.Colors.Outline)
    body.Parent = container

    container.Parent = config.parent
    return body, container
end

-- 面板标题条：左侧色块小标签风格。
function UI.createHeader(config)
    local header = UI.createLabel({
        name = config.name or "Header",
        parent = config.parent,
        text = config.text,
        size = config.size or UDim2.new(1, 0, 0, 30),
        position = config.position or UDim2.new(0, 0, 0, 0),
        textSize = config.textSize or 22,
        font = UI.Fonts.Display,
        textColor = config.textColor or UI.Colors.Ink,
        textXAlignment = config.textXAlignment or Enum.TextXAlignment.Left,
        transparent = true,
        layoutOrder = config.layoutOrder,
    })
    return header
end

-- 圆角小标签（状态、人数等）。
function UI.createPill(config)
    local color = config.backgroundColor or UI.Colors.PaperDark
    local pill = UI.createLabel({
        name = config.name or "Pill",
        parent = config.parent,
        text = config.text or "",
        size = config.size or UDim2.new(0, 90, 0, 26),
        position = config.position,
        anchorPoint = config.anchorPoint,
        textSize = config.textSize or 15,
        font = config.font or UI.Fonts.Bold,
        textColor = config.textColor or textColorFor(color),
        backgroundColor = color,
        zIndex = config.zIndex,
        layoutOrder = config.layoutOrder,
        textWrapped = false,
    })
    UI.addCorner(pill, UDim.new(1, 0))
    UI.addStroke(pill, config.strokeThickness or 2, config.strokeColor or UI.Colors.Outline)
    if config.autoWidth then
        pill.AutomaticSize = Enum.AutomaticSize.X
        pill.Size = UDim2.new(0, 0, pill.Size.Y.Scale, pill.Size.Y.Offset)
        UI.addPadding(pill, 0, config.paddingX or 12)
    end
    return pill
end

function UI.setPill(pill, text, color)
    pill.Text = text
    if color then
        pill.BackgroundColor3 = color
        pill.TextColor3 = textColorFor(color)
    end
end

function UI.createAvatarImage(config)
    local container = UI.createFrame({
        name = config.name or "AvatarContainer",
        parent = config.parent,
        size = config.size or UDim2.new(0, 60, 0, 60),
        position = config.position or UDim2.new(0, 0, 0, 0),
        anchorPoint = config.anchorPoint,
        backgroundTransparency = 1,
        zIndex = config.zIndex,
        layoutOrder = config.layoutOrder,
    })

    local background = UI.createFrame({
        name = "AvatarBackground",
        parent = container,
        -- 正方形约束下保持在容器中央
        anchorPoint = Vector2.new(0.5, 0.5),
        size = UDim2.new(1, 0, 1, 0),
        position = UDim2.new(0.5, 0, 0.5, 0),
        backgroundColor = config.backgroundColor or UI.Colors.PaperDeep,
        corner = true,
        cornerRadius = config.cornerRadius or UDim.new(0.5, 0),
        zIndex = config.zIndex,
    })
    local stroke = UI.addStroke(background, config.strokeThickness or 2, config.strokeColor or UI.Colors.Outline)
    stroke.Name = "AvatarStroke"

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
    image.ZIndex = config.zIndex or 1
    image.Parent = background

    UI.addCorner(image, config.cornerRadius or UDim.new(0.5, 0))

    return container
end

-- 设置头像描边颜色（用于房主、准备、当前查看等状态）。
function UI.setAvatarRing(avatarContainer, color, thickness)
    local background = avatarContainer:FindFirstChild("AvatarBackground")
    local stroke = background and background:FindFirstChild("AvatarStroke")
    if stroke then
        stroke.Color = color
        if thickness then
            stroke.Thickness = thickness
        end
    end
end

-- ===============================
-- 提示消息
-- ===============================

local toastScreen = nil
local toastList = nil

local TOAST_COLORS = {
    info = UI.Colors.Paper,
    success = Color3.fromRGB(214, 238, 200),
    warning = Color3.fromRGB(252, 232, 180),
    error = Color3.fromRGB(246, 210, 198),
}

local function ensureToastScreen()
    if toastScreen and toastScreen.Parent then
        return
    end
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    toastScreen = UI.createScreen("ToastGui", { DisplayOrder = 1000 })
    local stage = UI.createStage(toastScreen)
    toastList = UI.createFrame({
        name = "ToastList",
        parent = stage,
        anchorPoint = Vector2.new(0.5, 0),
        position = UDim2.new(0.5, 0, 0, 70),
        size = UDim2.new(0, 520, 1, -80),
        backgroundTransparency = 1,
    })
    UI.addList(toastList, { padding = 10, horizontalAlignment = Enum.HorizontalAlignment.Center })
    toastScreen.Parent = playerGui
end

-- 在屏幕上方显示一条提示，duration 秒后淡出。kind: info / success / warning / error。
function UI.showToast(text, kind, duration)
    ensureToastScreen()
    local body, container = UI.createPanel({
        name = "Toast",
        parent = toastList,
        size = UDim2.new(1, 0, 0, 60),
        backgroundColor = TOAST_COLORS[kind or "info"] or TOAST_COLORS.info,
        depth = 4,
        cornerRadius = UDim.new(0, 12),
    })
    UI.createLabel({
        name = "ToastText",
        parent = body,
        text = text,
        size = UDim2.new(1, -24, 1, 0),
        position = UDim2.new(0, 12, 0, 0),
        textSize = 20,
        font = UI.Fonts.Bold,
        textScaled = true,
        transparent = true,
        zIndex = 3,
    })

    task.delay(duration or 3, function()
        if not container.Parent then
            return
        end
        local info = TweenInfo.new(0.25)
        for _, item in ipairs(container:GetDescendants()) do
            if item:IsA("Frame") then
                TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
            elseif item:IsA("TextLabel") then
                TweenService:Create(item, info, { TextTransparency = 1 }):Play()
            elseif item:IsA("UIStroke") then
                TweenService:Create(item, info, { Transparency = 1 }):Play()
            end
        end
        task.wait(0.3)
        container:Destroy()
    end)
    return container
end

return UI
