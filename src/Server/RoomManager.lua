-- RoomManager - 房间管理器
local M = {}

local Players = game:GetService("Players")

-- 导入SignalManager
local SignalManager = require(script.Parent.Parent.SignalManager)

-- 远程事件
local RoomCreateRequest = SignalManager.GetRemote("RoomCreateRequest")
local RoomJoinRequest = SignalManager.GetRemote("RoomJoinRequest")
local RoomLeaveRequest = SignalManager.GetRemote("RoomLeaveRequest")
local RoomStartGame = SignalManager.GetRemote("RoomStartGame")
local RoomPlayerUpdate = SignalManager.GetRemote("RoomPlayerUpdate")
local GetRoomList = SignalManager.GetRemoteFunction("GetRoomList")
local MatchStarted = SignalManager.GetRemote("MatchStarted")
local GameAborted = SignalManager.GetRemote("GameAborted")
local ReturnToRoomRequest = SignalManager.GetRemote("ReturnToRoomRequest")
local RoomPlayerReady = SignalManager.GetRemote("RoomPlayerReady")

-- 本地事件
local GameInitRequest = SignalManager.GetBindable("GameInitRequest")
local GameFinishedNotification = SignalManager.GetBindable("GameFinishedNotification")

local Utils = require(script.Parent.ServerUtils)
local MatchService = require(script.Parent.MatchService)
local Config = require(script.Parent.Parent.Config)

-- 数据
local rooms = {}
local playerToRoom = {}

-- 工具函数
local function generateRoomId()
    return Utils.generateId("room")
end

local function createRoom(name, host)
    return {
        id = generateRoomId(),
        name = name,
        players = {host},
        host = host,
        isGameStarted = false,
        createdTime = os.time(),
        playerReadyStatus = {}
    }
end

local function getPlayerAvatarUrl(player)
    return "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
end

local function getRoomData(room)
    local playerData = {}
    for _, player in ipairs(room.players) do
        if Utils.isValidPlayer(player) then
            table.insert(playerData, {
                name = player.Name,
                displayName = player.DisplayName,
                userId = player.UserId,
                avatarUrl = getPlayerAvatarUrl(player),
                isReady = room.playerReadyStatus[player] or false
            })
        end
    end
    
    return {
        id = room.id,
        name = room.name,
        playerCount = #playerData,
        maxPlayers = Config.game.maxPlayers,
        players = playerData,
        host = room.host and {
            name = room.host.Name,
            displayName = room.host.DisplayName,
            userId = room.host.UserId
        } or nil,
        isGameStarted = room.isGameStarted,
        createdTime = room.createdTime
    }
end

local function broadcastRoomUpdate(roomId)
    local room = rooms[roomId]
    if not room then return end
    
    local roomData = getRoomData(room)
    for _, player in ipairs(room.players) do
        if Utils.isValidPlayer(player) then
            RoomPlayerUpdate:FireClient(player, roomData)
        end
    end
    
    Utils.log("RoomManager", "Room update sent", roomId)
end

local function removePlayerFromRoom(player)
    local roomId = playerToRoom[player]
    if not roomId then return false end
    
    local room = rooms[roomId]
    if not room then
        playerToRoom[player] = nil
        return false
    end
    
    Utils.removeFromArray(room.players, player)
    room.playerReadyStatus[player] = nil
    playerToRoom[player] = nil
    
    Utils.log("RoomManager", "Player removed", player.Name)
    
    -- 选择新房主
    if room.host == player and #room.players > 0 then
        room.host = room.players[1]
        Utils.log("RoomManager", "New host", room.host.Name)
    end
    
    -- 删除空房间
    if #room.players == 0 then
        rooms[roomId] = nil
        Utils.log("RoomManager", "Room deleted", roomId)
        return true
    end
    
    broadcastRoomUpdate(roomId)
    return true
end

local function findRoomByMatchId(matchId)
    for roomId, room in pairs(rooms) do
        if room.matchId == matchId then
            return roomId, room
        end
    end
    return nil, nil
end

-- 恢复房间状态，但不立即推送界面更新
local function restoreRoomAfterGame(matchId)
    local roomId, room = findRoomByMatchId(matchId)
    if not roomId or not room then
        Utils.warn("RoomManager", "Room not found for match", matchId)
        return false
    end
    
    room.isGameStarted = false
    room.matchId = nil
    room.playerReadyStatus = {}
    
    Utils.log("RoomManager", "Room restored for all players (state only)", roomId)
    
    -- 不立即推送界面更新，等待玩家主动请求
    -- 玩家在服务器端已经回到房间，但界面还在游戏结束页面
    
    return true
end

local function isRoomRestored(player)
    local roomId = playerToRoom[player]
    if not roomId then return false end
    local room = rooms[roomId]
    return room and not room.isGameStarted
end

-- 事件处理
RoomCreateRequest:Connect(function(player, roomName)
    if not Utils.isValidPlayer(player) then return end
    
    local isValid, error = Utils.validateRoomName(roomName)
    if not isValid then
        Utils.warn("RoomManager", "Invalid room name", error)
        return
    end
    
    if playerToRoom[player] then
        Utils.warn("RoomManager", "Player already in room", player.Name)
        return
    end
    
    local room = createRoom(roomName, player)
    rooms[room.id] = room
    playerToRoom[player] = room.id
    
    Utils.log("RoomManager", "Room created", roomName)
    broadcastRoomUpdate(room.id)
end)

RoomJoinRequest:Connect(function(player, roomId)
    if not Utils.isValidPlayer(player) or not Utils.isValidId(roomId) then return end
    
    local room = rooms[roomId]
    if not room then
        Utils.warn("RoomManager", "Room not found", roomId)
        return
    end
    
    if #room.players >= Config.game.maxPlayers then
        Utils.warn("RoomManager", "Room full", roomId)
        return
    end
    
    if room.isGameStarted then
        Utils.warn("RoomManager", "Game started", roomId)
        return
    end
    
    if Utils.contains(room.players, player) then
        Utils.warn("RoomManager", "Player already in room", player.Name)
        return
    end
    
    if playerToRoom[player] then
        Utils.warn("RoomManager", "Player in another room", player.Name)
        return
    end
    
    table.insert(room.players, player)
    playerToRoom[player] = roomId
    
    Utils.log("RoomManager", "Player joined", player.Name)
    broadcastRoomUpdate(roomId)
end)

RoomLeaveRequest:Connect(function(player)
    if not Utils.isValidPlayer(player) then return end
    
    local roomId = playerToRoom[player]
    if not roomId then
        Utils.log("RoomManager", player.Name .. " tried to leave a room but was not in one.")
        return
    end
    
    local room = rooms[roomId]
    if room.isGameStarted then
        Utils.log("RoomManager", "Player ".. player.Name .." cannot leave room during an active match.")
        return
    end
    
    removePlayerFromRoom(player)
end)

RoomPlayerReady:Connect(function(player)
    if not Utils.isValidPlayer(player) then return end
    
    local roomId = playerToRoom[player]
    if not roomId then
        Utils.warn("RoomManager", "Player not in room", player.Name)
        return
    end
    
    local room = rooms[roomId]
    if not room or room.isGameStarted then
        Utils.warn("RoomManager", "Invalid room state", roomId)
        return
    end
    
    if room.host == player then
        Utils.log("RoomManager", "Host doesn't need ready", player.Name)
        return
    end
    
    local currentStatus = room.playerReadyStatus[player] or false
    room.playerReadyStatus[player] = not currentStatus
    
    Utils.log("RoomManager", "Ready status changed", player.Name)
    broadcastRoomUpdate(roomId)
end)

RoomStartGame:Connect(function(player, roomId)
    if not Utils.isValidPlayer(player) or not Utils.isValidId(roomId) then return end
    
    local room = rooms[roomId]
    if not room then
        Utils.warn("RoomManager", "Room not found", roomId)
        return
    end
    
    if room.host ~= player then
        Utils.warn("RoomManager", "Only host can start", player.Name)
        return
    end
    
    if room.isGameStarted then
        Utils.warn("RoomManager", "Game already started", roomId)
        return
    end
    
    if #room.players < Config.game.minPlayers then
        Utils.warn("RoomManager", "Not enough players", #room.players)
        return
    end
    
    -- 检查准备状态
    for _, p in ipairs(room.players) do
        if p ~= room.host and not room.playerReadyStatus[p] then
            Utils.warn("RoomManager", "Not all ready", roomId)
            return
        end
    end
    
    -- 过滤有效玩家
    local validPlayers = {}
    for _, p in ipairs(room.players) do
        if Utils.isValidPlayer(p) then
            table.insert(validPlayers, p)
        end
    end
    
    if #validPlayers < Config.game.minPlayers then
        Utils.warn("RoomManager", "Not enough valid players", #validPlayers)
        return
    end
    
    room.isGameStarted = true
    local matchId = MatchService.AddMatch(validPlayers)
    
    if not matchId then
        room.isGameStarted = false
        Utils.warn("RoomManager", "Failed to create match", roomId)
        return
    end
    
    room.matchId = matchId
    
    -- 通知玩家
    for _, p in ipairs(validPlayers) do
        local opponentUserIds = {}
        for _, opponent in ipairs(validPlayers) do
            if opponent ~= p then
                table.insert(opponentUserIds, opponent.UserId)
            end
        end
        
        MatchStarted:FireClient(p, {
            matchId = matchId,
            playerUserId = p.UserId,
            opponentUserIds = opponentUserIds,
            allPlayers = validPlayers,
            roomId = roomId
        })
    end
    
    GameInitRequest:Fire(matchId)
    Utils.log("RoomManager", "Game started", matchId)
end)

GetRoomList:OnInvoke(function(player)
	if not Utils.isValidPlayer(player) then return {} end
	
	local roomList = {}
	for _, room in pairs(rooms) do
		if not room.isGameStarted then
			table.insert(roomList, getRoomData(room))
		end
	end
	
	Utils.log("RoomManager", "Room list sent")
	return roomList
end)

ReturnToRoomRequest:Connect(function(player)
    if not Utils.isValidPlayer(player) then return end
    
    Utils.log("RoomManager", "ReturnToRoomRequest received", player.Name)
    
    -- 检查玩家是否在已恢复的房间中
    if isRoomRestored(player) then
        local roomId = playerToRoom[player]
        local room = rooms[roomId]
        
        if room then
            Utils.log("RoomManager", "Player found in restored room", player.Name)
            ReturnToRoomRequest:FireClient(player, {
                type = "return_to_room",
                roomData = getRoomData(room)
            })
        else
            Utils.warn("RoomManager", "Player room not found", player.Name)
            ReturnToRoomRequest:FireClient(player, {
                type = "return_to_main",
                message = "room does not exist"
            })
        end
        return
    end
    
    -- 检查玩家是否仍在房间中（备用方案）
    local roomId = playerToRoom[player]
    if roomId then
        local room = rooms[roomId]
        if room and not room.isGameStarted then
            Utils.log("RoomManager", "Player found in room via backup method", player.Name)
            ReturnToRoomRequest:FireClient(player, {
                type = "return_to_room",
                roomData = getRoomData(room)
            })
            return
        end
    end
    
    -- 如果到这里，说明房间恢复机制可能有问题
    Utils.warn("RoomManager", "Room recovery failed for player", player.Name)
    ReturnToRoomRequest:FireClient(player, {
        type = "return_to_main",
        message = "failed to find room"
    })
end)

-- 监听游戏结束通知
GameFinishedNotification:Connect(function(data)
    if not data or not data.matchId then
        Utils.warn("RoomManager", "Invalid game finished notification")
        return
    end
    
    local matchId = data.matchId
    Utils.log("RoomManager", "Game finished notification received", matchId)
    
    -- 立即恢复房间状态
    if restoreRoomAfterGame(matchId) then
        Utils.log("RoomManager", "Room restored successfully after game", matchId)
    else
        Utils.warn("RoomManager", "Failed to restore room after game", matchId)
    end
end)

-- 玩家离开处理
Players.PlayerRemoving:Connect(function(player)
    Utils.log("RoomManager", "Player disconnecting", player.Name)
    removePlayerFromRoom(player)
    
    -- 处理进行中的匹配
    for matchId, match in pairs(MatchService.activeGames) do
        if Utils.contains(match.players, player) then
            local remainingPlayers = {}
            for _, p in ipairs(match.players) do
                if p ~= player and Utils.isValidPlayer(p) then
                    table.insert(remainingPlayers, p)
                end
            end
            
            Utils.log("RoomManager", "Player left match", matchId)
            
            if Utils.shouldAbortGame(#remainingPlayers) then
                Utils.log("RoomManager", "Aborting game", matchId)
                
                for _, other in ipairs(remainingPlayers) do
                    GameAborted:FireClient(other, {
                        matchId = matchId,
                        message = "Game aborted: " .. player.Name .. " left the game",
                        leftPlayer = player.Name,
                        remainingPlayers = #remainingPlayers
                    })
                end
                
                MatchService.RemoveMatch(matchId)
                local roomId, room = findRoomByMatchId(matchId)
                if roomId and room then
                    room.isGameStarted = false
                    room.matchId = nil
                    room.playerReadyStatus = {}
                    Utils.log("RoomManager", "Room reset after abort", roomId)
                end
            end
            
            break
        end
    end
end)

Utils.log("RoomManager", "RoomManager initialized") 

return M