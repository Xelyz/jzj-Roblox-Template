-- DisableMovement.client.lua - 禁用移动设备上的默认移动控制和交互

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- 禁用移动摇杆和跳跃按钮等移动控制
local function disableMobileControls()
    print("Disabling mobile movement controls...")
    
    -- 禁用移动摇杆
    UserInputService.ModalEnabled = false
    
    -- 禁用触摸移动
    if UserInputService.TouchEnabled then
        print("Touch device detected - disabling touch movement")
        
        -- 禁用默认的移动摇杆
        pcall(function()
            UserInputService:GetService("UserInputService").ModalEnabled = false
        end)
        
        -- 移除所有默认的移动相关按钮
        local function removeDefaultActions()
            -- 移除跳跃按钮
            ContextActionService:UnbindAction("jumpAction")
            
            -- 移除其他可能的默认操作
            local actionsToRemove = {
                "jumpAction",
                "moveAction", 
                "cameraAction",
                "toolAction"
            }
            
            for _, actionName in ipairs(actionsToRemove) do
                pcall(function()
                    ContextActionService:UnbindAction(actionName)
                end)
            end
        end
        
        -- 立即尝试移除，并在玩家加载后再次尝试
        removeDefaultActions()
        
        LocalPlayer.CharacterAdded:Connect(function(character)
            task.wait(1) -- 等待角色完全加载
            removeDefaultActions()
            
            -- 禁用角色移动
            local humanoid = character:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.PlatformStand = true -- 禁用物理移动
                print("Character movement disabled")
            end
        end)
    end
    
    -- 如果角色已经存在，立即禁用移动
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.PlatformStand = true
            print("Existing character movement disabled")
        end
    end
end

-- 禁用默认的GUI元素
local function disableDefaultGuis()
    print("Disabling default GUI elements...")
    
    -- 禁用聊天（如果不需要的话，你可以注释掉这行）
    -- StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    
    -- 禁用玩家列表
    -- StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    
    -- 禁用背包（工具栏）
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    
    -- 禁用健康条
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    
    -- 保留设置菜单，以防需要退出游戏
    -- StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) -- 这会禁用所有GUI
end

-- 禁用相机控制（可选）
local function disableCameraControls()
    print("Disabling camera controls...")
    
    local function setupCamera()
        local camera = workspace.CurrentCamera
        if camera then
            -- 设置相机为固定模式
            camera.CameraType = Enum.CameraType.Scriptable
            
            -- 设置一个固定的相机位置
            camera.CFrame = CFrame.new(0, 10, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
            
            print("Camera set to fixed position")
        end
    end
    
    -- 立即设置相机
    setupCamera()
    
    -- 当玩家重生时重新设置相机
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        setupCamera()
    end)
end

-- 主要禁用函数
local function disableAllControls()
    print("DisableMovement script started - disabling all mobile controls")
    
    -- 等待游戏完全加载
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- 禁用移动控制
    disableMobileControls()
    
    -- 禁用默认GUI
    disableDefaultGuis()
    
    -- 禁用相机控制
    disableCameraControls()
    
    print("All mobile controls have been disabled")
end

-- 启动禁用控制
disableAllControls()

-- 防止脚本重复运行的保护
if not _G.MovementDisabled then
    _G.MovementDisabled = true
    print("Movement controls successfully disabled for pure GUI game")
end 