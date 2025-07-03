-- ChatManager (Server) - 专门处理游戏内聊天消息

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchMessage = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchMessage")

local MatchService = require(game.ServerScriptService:WaitForChild("MatchService"))

-- 处理游戏内聊天消息中继
MatchMessage.OnServerEvent:Connect(function(sender, data)
    -- data = {matchId = ..., message = ...}
    if not data or not data.matchId or not data.message then
        print("Invalid match message data from:", sender.Name)
        return
    end
    
    print("Relaying message in match:", data.matchId, "from:", sender.Name, "message:", data.message)
    
    local match = MatchService.GetMatch(data.matchId)
    if match then
        -- 转发消息给同一比赛中的其他玩家
        for i, p in ipairs(match.players) do
            if p ~= sender then
                MatchMessage:FireClient(p, {
                    from = sender.Name, 
                    message = data.message, 
                    matchId = data.matchId
                })
                print("Message relayed to:", p.Name)
            end
        end
    else
        print("Match not found for message relay:", data.matchId)
    end
end) 