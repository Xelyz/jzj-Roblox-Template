local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local ChatManager = {}

-- 为比赛创建独立频道，交由 Roblox 处理过滤和聊天权限。
function ChatManager.CreateChannel(matchId, players)
    local channel = Instance.new("TextChannel")
    channel.Name = matchId

    local members = {}
    for _, player in ipairs(players) do
        members[player.UserId] = player
    end

    channel.ShouldDeliverCallback = function(message, recipient)
        local sender = message.TextSource and members[message.TextSource.UserId]
        local receiver = members[recipient.UserId]
        return sender ~= nil and sender.Parent == Players
            and receiver ~= nil and receiver.Parent == Players
    end

    channel.Parent = TextChatService
    for _, player in ipairs(players) do
        task.defer(function()
            if channel.Parent and player.Parent == Players then
                local ok, err = pcall(channel.AddUserAsync, channel, player.UserId)
                if not ok and channel.Parent then
                    warn("Failed to add player to match chat:", matchId, player.UserId, err)
                end
            end
        end)
    end

    return channel
end

return ChatManager
