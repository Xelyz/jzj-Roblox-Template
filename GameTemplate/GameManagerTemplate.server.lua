-- GameManagerTemplate (Server) - 通用游戏管理器模板
-- 此文件为游戏逻辑的基础模板，可根据具体游戏需求进行修改

local Players = game:GetService("Players")

-- 导入SignalManager
local SignalManager = require(script.Parent.SignalManager)

local MatchService = require(script.Parent.MatchServiceServer)
local LeaderboardService = require(script.Parent.LeaderboardServiceServer)

-- 远程事件
local PlayerInput = SignalManager.GetRemote("PlayerInput")
local RoundResult = SignalManager.GetRemote("RoundResult")
local GameStateUpdate = SignalManager.GetRemote("GameStateUpdate")
local GameAborted = SignalManager.GetRemote("GameAborted")
local GameFinished = SignalManager.GetRemote("GameFinished")

-- 本地事件
local GameInitRequest = SignalManager.GetBindable("GameInitRequest")

-- 游戏配置 - 根据具体游戏调整
local GAME_CONFIG = {
    MAX_ROUNDS = 10,        -- 最大回合数
    WIN_CONDITION = 5,      -- 获胜条件
    STARTING_POINTS = 30,   -- 起始点数（如果游戏需要）
    ROUND_TIMEOUT = 30      -- 回合超时时间（秒）
}

-- 游戏状态初始化模板
local function initGameState(players)
    local gameState = {
        players = {},
        round = 1,
        active = true,
        startTime = tick(),
        -- 根据游戏需求添加其他状态
    }
    
    -- 为每个玩家初始化状态
    for i, player in ipairs(players) do
        gameState.players[player.UserId] = {
            player = player,
            score = 0,
            wins = 0,
            -- 根据游戏需求添加其他属性
        }
    end
    
    return gameState
end

-- 处理游戏结果模板
function _processRoundResult(matchId, match)
    local gameState = match.gameState
    
    print("Processing round result for match:", matchId, "with", #match.players, "players")
    
    -- TODO: 在这里实现具体的游戏逻辑
    -- 例如：比较玩家输入，计算得分，确定胜负等
    
    local winner = nil
    local playerUserIds = {}
    for i, player in ipairs(match.players) do
        table.insert(playerUserIds, player.UserId)
    end
    
    -- TODO: 实现胜负判断逻辑（多人支持）
    -- 例如：找出得分最高的玩家
    -- local highestScore = 0
    -- local winnerUserId = nil
    -- for _, userId in ipairs(playerUserIds) do
    --     if gameState.players[userId].score > highestScore then
    --         highestScore = gameState.players[userId].score
    --         winnerUserId = userId
    --     end
    -- end
    -- winner = winnerUserId
    -- if winner then
    --     gameState.players[winner].wins = gameState.players[winner].wins + 1
    -- end
    
    -- 发送结果给所有玩家
    local gameResult = {
        matchId = matchId,
        round = gameState.round,
        winner = winner,
        gameState = gameState
        -- 根据需要添加其他结果数据
    }
    
    -- 增加回合数
    gameState.round = gameState.round + 1
    
    -- 检查游戏结束条件（多人支持）
    local maxWins = 0
    for _, userId in ipairs(playerUserIds) do
        if gameState.players[userId].wins > maxWins then
            maxWins = gameState.players[userId].wins
        end
    end
    
    if maxWins >= GAME_CONFIG.WIN_CONDITION or gameState.round > GAME_CONFIG.MAX_ROUNDS then
        gameState.active = false
    end
    
    for i, player in ipairs(match.players) do
        RoundResult:FireClient(player, gameResult)
        print("Sent game result to:", player.Name)
    end
    
    -- 如果游戏结束，记录最终结果到排行榜并清理比赛
    if not gameState.active then
        print("Match", matchId, "finished with", #match.players, "players")
        
        -- 确定最终获胜者并记录到排行榜（多人支持）
        local finalWinnerUserId = nil
        local maxFinalWins = 0
        for _, userId in ipairs(playerUserIds) do
            if gameState.players[userId].wins > maxFinalWins then
                maxFinalWins = gameState.players[userId].wins
                finalWinnerUserId = userId
            end
        end
        
        -- 记录排行榜统计（多人支持）
        if finalWinnerUserId then
            -- 找到获胜玩家对象
            local winnerPlayer = nil
            for i, player in ipairs(match.players) do
                if player.UserId == finalWinnerUserId then
                    winnerPlayer = player
                    break
                end
            end
            
            if winnerPlayer then
                LeaderboardService.RecordWin(winnerPlayer)
                print("Recorded win for:", winnerPlayer.Name)
                
                -- 记录其他玩家的失败
                for i, player in ipairs(match.players) do
                    if player.UserId ~= finalWinnerUserId then
                        LeaderboardService.RecordLoss(player)
                        print("Recorded loss for:", player.Name)
                    end
                end
            end
        else
            -- 平局情况 - 所有玩家都记录失败
            for i, player in ipairs(match.players) do
                LeaderboardService.RecordLoss(player)
                print("Recorded tie game loss for:", player.Name)
            end
        end
        
        -- 等待后清理匹配
        task.wait(5)
        MatchService.RemoveMatch(matchId)
    end
end

-- 广播游戏状态更新
function broadcastGameState(match, matchId)
    local stateUpdate = {
        matchId = matchId,
        gameState = match.gameState,
        timestamp = tick()
    }
    
    for i, player in ipairs(match.players) do
        GameStateUpdate:FireClient(player, stateUpdate)
    end
end

-- 处理玩家输入
PlayerInput:Connect(function(player, data)
    -- data = {matchId = ..., input = {type = ..., data = ...}}
    if not data or not data.matchId or not data.input then
        print("Invalid player input data from:", player.Name)
        return
    end
    
    local matchId = data.matchId
    local inputData = data.input

    local match = MatchService.GetMatch(matchId)
    if not match then 
        print("Match not found for player input:", matchId)
        return 
    end

    if not match.gameState then
        print("Error: Game state not found for match:", matchId)
        return
    end

    local gameState = match.gameState
    print("Processing input from", player.Name, "in match:", matchId)

    -- 获取玩家UserId
    local playerUserId = player.UserId
    
    -- TODO: 在这里实现具体的输入处理逻辑
    if gameState.active and inputData.type then
        -- 根据输入类型处理不同的游戏动作
        -- 例如：
        -- if inputData.type == "move" then
        --     -- 处理移动输入，可以通过 gameState.players[playerUserId] 访问玩家数据
        -- elseif inputData.type == "action" then
        --     -- 处理动作输入，可以通过 gameState.players[playerUserId] 访问玩家数据
        -- end
        
        print(player.Name, "(UserId:", playerUserId, ") performed action:", inputData.type)
        
        -- 检查是否需要处理回合结果
        -- 例如：如果所有玩家都已输入，则处理结果
        -- if allPlayersReady(match) then
        --     _processRoundResult(matchId, match)
        -- end
    end
    
    -- 广播游戏状态更新给所有玩家
    broadcastGameState(match, matchId)
end)

-- 为比赛初始化游戏状态的函数
local function initializeMatchGameState(matchId)
    local match = MatchService.GetMatch(matchId)
    if not match then
        print("Error: Match not found when trying to initialize game state:", matchId)
        return
    end
    
    -- 初始化游戏状态
    match.gameState = initGameState(match.players)
    print("GameManagerTemplate: Initialized game state for match:", matchId)
    
    -- 发送初始游戏状态给双方玩家
    local initialStateUpdate = {
        matchId = matchId,
        gameState = match.gameState,
        timestamp = tick()
    }
    
    -- 延迟发送，确保客户端已经创建好UI
    task.spawn(function()
        task.wait(0.3)
        for i, player in ipairs(match.players) do
            GameStateUpdate:FireClient(player, initialStateUpdate)
        end
        print("GameManagerTemplate: Sent initial game state to both players for match:", matchId)
    end)
end

-- 监听游戏初始化请求事件
GameInitRequest:Connect(function(matchId)
    initializeMatchGameState(matchId)
end)

-- 处理玩家离开游戏
local function handlePlayerLeft(player, matchId)
    local match = MatchService.GetMatch(matchId)
    if not match or not match.gameState then return end
    
    print("Player left game:", player.Name, "Match:", matchId)
    
    -- 移除玩家状态
    match.gameState.players[player.UserId] = nil
    
    -- 检查剩余玩家数量
    local remainingCount = 0
    for _ in pairs(match.gameState.players) do
        remainingCount = remainingCount + 1
    end
    
    if remainingCount < 2 then
        -- 游戏人数不足，中止游戏
        print("Not enough players, aborting game:", matchId)
        
        for _, remainingPlayer in ipairs(match.players) do
            if remainingPlayer ~= player then
                GameAborted:FireClient(remainingPlayer, {
                    matchId = matchId,
                    reason = "Player left",
                    leftPlayer = player.Name
                })
            end
        end
        
        -- 清理匹配
        MatchService.RemoveMatch(matchId)
    else
        -- 继续游戏，广播更新状态
        broadcastGameState(match, matchId)
    end
end

-- 监听玩家离开
Players.PlayerRemoving:Connect(function(player)
    -- 查找玩家参与的匹配
    for matchId, match in pairs(MatchService.activeGames) do
        if match.gameState and match.gameState.players[player.UserId] then
            handlePlayerLeft(player, matchId)
            break
        end
    end
end)

print("GameManagerTemplate initialized")

-- TODO: 添加其他游戏特定的服务器端逻辑 