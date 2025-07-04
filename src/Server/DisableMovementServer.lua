-- DisableMovementServer.server.lua - 服务器端配置StarterPlayer设置

local M = {}

local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

-- 配置StarterPlayer属性来禁用移动控制
local function configureStarterPlayer()
    print("Configuring StarterPlayer settings to disable movement...")
    
    -- 禁用移动控制 - 对所有平台
    StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
    StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
    
    -- 其他有用的设置
    StarterPlayer.EnableMouseLockOption = false -- 禁用鼠标锁定选项
    StarterPlayer.CameraMaxZoomDistance = 1 -- 限制相机缩放
    StarterPlayer.CameraMinZoomDistance = 1
    
    -- 设置角色相关属性（如果需要的话）
    StarterPlayer.CharacterWalkSpeed = 0 -- 设置移动速度为0
    StarterPlayer.CharacterJumpPower = 0 -- 禁用跳跃
    StarterPlayer.CharacterJumpHeight = 0 -- 禁用跳跃高度（新版本）
    
    print("StarterPlayer configured for pure GUI gameplay")
end

-- 当玩家加入时进一步配置
local function onPlayerAdded(player)
    print("Player joined:", player.Name, "- applying movement restrictions")
    
    -- 当玩家角色生成时的额外配置
    player.CharacterAdded:Connect(function(character)
        task.wait(1) -- 等待角色完全加载
        
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            -- 确保移动被禁用
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
            humanoid.PlatformStand = true
            
            print("Movement disabled for", player.Name, "'s character")
        end
        
        -- 禁用角色的碰撞（可选）
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

-- 主要配置函数
local function setupMovementDisabling()
    print("Setting up server-side movement disabling...")
    
    -- 配置StarterPlayer
    configureStarterPlayer()
    
    -- 为现有玩家设置
    for _, player in pairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    
    -- 为新加入的玩家设置
    Players.PlayerAdded:Connect(onPlayerAdded)
    
    print("Server-side movement disabling setup complete")
end

-- 启动配置
setupMovementDisabling()

return M 