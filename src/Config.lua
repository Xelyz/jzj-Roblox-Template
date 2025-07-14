-- Config - 模板配置代理
-- 从外部GameConfig读取配置，支持逐项fallback

local Config = {}

-- 默认配置
local DEFAULT_CONFIG = {
    game = {
        -- 通用游戏配置
        maxPlayers = 4,
        minPlayers = 2,
        -- 游戏特定配置不在默认配置中，允许外部配置自定义
    },
    room = {
        nameMaxLength = 20,
        nameMinLength = 1,
    },
    match = {
        readyTimeout = 30,
        gameTimeout = 300,
    },
    ui = {
        updateInterval = 1,
        messageHeight = 30,
    },
    chat = {
        maxMessageLength = 100,
        cooldownTime = 1,
    },
    leaderboard = {
        maxEntries = 10,
        updateInterval = 5,
    }
}

-- 尝试从外部GameConfig读取配置
local success, GameConfig = pcall(function()
    return require(game.ReplicatedStorage.GameConfig)
end)

-- 合并配置的辅助函数
local function mergeConfig(default, external)
    local result = {}
    
    -- 从外部配置开始，复制所有外部配置项
    if external then
        for key, value in pairs(external) do
            if type(value) == "table" then
                result[key] = {}
                for subKey, subValue in pairs(value) do
                    result[key][subKey] = subValue
                end
            else
                result[key] = value
            end
        end
    end
    
    -- 遍历默认配置，补充外部配置中缺失的项
    for key, defaultValue in pairs(default) do
        if type(defaultValue) == "table" then
            -- 确保结果中有这个键
            if not result[key] then
                result[key] = {}
            end
            
            -- 补充缺失的子项
            for subKey, subDefaultValue in pairs(defaultValue) do
                if result[key][subKey] == nil then
                    result[key][subKey] = subDefaultValue
                end
            end
        else
            -- 如果外部配置中没有这个键，使用默认值
            if result[key] == nil then
                result[key] = defaultValue
            end
        end
    end
    
    return result
end

if success then
    -- 使用外部配置，但对每个配置项进行fallback
    Config = mergeConfig(DEFAULT_CONFIG, GameConfig)
else
    -- 如果外部配置不存在，使用默认配置
    Config = DEFAULT_CONFIG
end

return Config 