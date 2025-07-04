-- ServerUtils - 简化的服务器端工具模块

local Utils = {}

local Players = game:GetService("Players")

-- 验证函数
function Utils.isValidPlayer(player)
    return player and player:IsA("Player") and player.Parent == Players
end

function Utils.isValidUserId(userId)
    return type(userId) == "number" and userId > 0
end

function Utils.isValidId(id)
    return type(id) == "string" and #id > 0
end

-- 日志函数
function Utils.log(module, message, data)
    local text = string.format("[%s] %s", module, message)
    if data then
        print(text, data)
    else
        print(text)
    end
end

function Utils.warn(module, message, data)
    local text = string.format("[%s] WARNING: %s", module, message)
    if data then
        warn(text, data)
    else
        warn(text)
    end
end

-- 数据转换
function Utils.playersToUserIds(players)
    local userIds = {}
    for _, player in ipairs(players) do
        if Utils.isValidPlayer(player) then
            table.insert(userIds, player.UserId)
        end
    end
    return userIds
end

function Utils.userIdsToPlayers(userIds)
    local players = {}
    for _, userId in ipairs(userIds) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            table.insert(players, player)
        end
    end
    return players
end

-- 数组操作
function Utils.removeFromArray(array, value)
    for i = #array, 1, -1 do
        if array[i] == value then
            table.remove(array, i)
            return true
        end
    end
    return false
end

function Utils.contains(array, value)
    for _, item in ipairs(array) do
        if item == value then
            return true
        end
    end
    return false
end

-- ID生成
function Utils.generateId(prefix)
    return prefix .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- 配置
Utils.config = {
    maxPlayers = 4,
    minPlayers = 2,
}

function Utils.validateRoomName(name)
    if type(name) ~= "string" then
        return false, "Room name must be a string"
    end
    if #name == 0 then
        return false, "Room name length invalid"
    end

    return true
end

-- 游戏逻辑
function Utils.shouldAbortGame(remainingPlayerCount, minRequired)
    return remainingPlayerCount < (minRequired or Utils.config.minPlayers)
end

function Utils.canStartGame(room)
    if not room or not room.players then
        return false, "Invalid room"
    end
    
    if #room.players < Utils.config.minPlayers then
        return false, "Not enough players"
    end
    
    for _, playerData in ipairs(room.players) do
        if not playerData.isReady then
            return false, "Not all players ready"
        end
    end
    
    return true
end

return Utils 