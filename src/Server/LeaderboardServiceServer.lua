-- LeaderboardService: 管理玩家战绩和排行榜数据
--
-- 排行榜有两张：
--   wins  —— 胜场榜（只统计多人对局）
--   score —— 最高分榜（单人、多人对局都统计）
--
-- 存档：每局结果作为增量（+胜场、+场次、最高分取大）用 UpdateAsync 原子地合并到 DataStore，
-- 不写回整份缓存，因此玩家在多个服务器间切换也不会互相覆盖。写入失败的增量留在
-- pending 里，定期重试，服务器关闭时（BindToClose）再尽量写完。
--
-- 排行榜：每张榜按 Config.leaderboard.updateInterval 定期从 OrderedDataStore 拉一份排序快照
-- （最多 rankDepth 条），前 maxEntries 名的展示数据和所有玩家的排名都从这份快照计算。

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)

local LeaderboardService = {}

local leaderboardConfig = Config.leaderboard or {}
local MAX_ENTRIES = math.clamp(math.floor(tonumber(leaderboardConfig.maxEntries) or 10), 1, 100)
local RANK_DEPTH = math.max(math.floor(tonumber(leaderboardConfig.rankDepth) or 1000), MAX_ENTRIES)
local REFRESH_INTERVAL = math.max(tonumber(leaderboardConfig.updateInterval) or 60, 10)
local FAILED_REFRESH_INTERVAL = 10
local PAGE_SIZE = 100
local MAX_ATTEMPTS = 3
local RETRY_LOOP_INTERVAL = 30
local SHUTDOWN_TIMEOUT = 25

-- 排行榜定义：field 为 stats 中用于排序的字段
local BOARDS = {
    wins = { name = "wins", storeName = "WinsLeaderboard", field = "totalWins" },
    score = { name = "score", storeName = "HighScoreLeaderboard", field = "bestScore" },
}
LeaderboardService.Boards = { "wins", "score" }
LeaderboardService.DefaultBoard = "wins"

for _, board in pairs(BOARDS) do
    board.store = nil -- OrderedDataStore
    board.devValues = {} -- 内存存储：[userId string] = value
    board.pendingSync = {} -- 同步失败待重试：[userId string] = value
    board.snapshot = nil
    board.refreshing = false
    board.nextRefreshAt = 0
end

local function logWarn(...)
    warn("[Leaderboard]", ...)
end

-- 数据存储：Studio 中或 DataStore 不可用时使用内存存储
local playerStatsStore = nil
local useDataStore = false

if RunService:IsStudio() then
    print("[Leaderboard] Studio mode - using memory storage instead of DataStore")
else
    local ok, err = pcall(function()
        playerStatsStore = DataStoreService:GetDataStore("PlayerStats")
        for _, board in pairs(BOARDS) do
            board.store = DataStoreService:GetOrderedDataStore(board.storeName)
        end
    end)
    if ok then
        useDataStore = true
    else
        logWarn("DataStore unavailable, using memory storage:", err)
    end
end

if not useDataStore then
    -- 内存存储读取没有成本，快照每次都可以重新生成
    REFRESH_INTERVAL = 0
end

local devStats = {} -- 内存存储：[userId string] = stats

-- 在线玩家缓存：[userId string] = { base = 已确认存档的 stats, loaded = 是否已成功读档 }
local statsCache = {}
-- 尚未写入存档的增量：[userId string] = { wins = n, matches = n, bestScore = n }
local pendingDeltas = {}

local loading = {}
local flushing = {}
local nameCache = {}

local function toCount(value)
    return math.max(math.floor(tonumber(value) or 0), 0)
end

local function normalizeStats(data)
    data = type(data) == "table" and data or {}
    local wins = toCount(data.totalWins)
    local matches = math.max(toCount(data.totalMatches), wins)
    return {
        totalWins = wins,
        totalMatches = matches,
        winRatio = matches > 0 and wins / matches or 0,
        bestScore = toCount(data.bestScore),
        lastUpdated = tonumber(data.lastUpdated) or 0,
    }
end

local function mergeDelta(data, delta)
    local stats = normalizeStats(data)
    stats.totalWins += delta.wins
    stats.totalMatches += delta.matches
    stats.winRatio = stats.totalMatches > 0 and stats.totalWins / stats.totalMatches or 0
    stats.bestScore = math.max(stats.bestScore, delta.bestScore)
    return stats
end

local function isEmptyDelta(delta)
    return delta.wins == 0 and delta.matches == 0 and delta.bestScore == 0
end

-- 执行 DataStore 请求，失败时指数退避重试
local function withRetries(label, fn)
    local lastErr = nil
    for attempt = 1, MAX_ATTEMPTS do
        local ok, result = pcall(fn)
        if ok then
            return true, result
        end
        lastErr = result
        if attempt < MAX_ATTEMPTS then
            task.wait(2 ^ attempt)
        end
    end
    logWarn(label, "failed after", MAX_ATTEMPTS, "attempts:", lastErr)
    return false, lastErr
end

-- 当前展示用的数据 = 已确认存档 + 尚未写入的增量
local function getCurrentStats(userId)
    local entry = statsCache[userId]
    local base = entry and entry.base or nil
    local delta = pendingDeltas[userId]
    if not delta then
        return normalizeStats(base)
    end
    return mergeDelta(base, delta)
end

local function ensureValue(parent, className, name)
    local value = parent:FindFirstChild(name)
    if not value then
        value = Instance.new(className)
        value.Name = name
        value.Parent = parent
    end
    return value
end

-- 更新玩家的 Roblox leaderstats
local function updatePlayerLeaderstats(player)
    if not player or not player.Parent then
        return
    end
    local stats = getCurrentStats(tostring(player.UserId))

    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    ensureValue(leaderstats, "IntValue", "Wins").Value = stats.totalWins
    ensureValue(leaderstats, "StringValue", "WinRate").Value = string.format("%.1f%%", stats.winRatio * 100)
    ensureValue(leaderstats, "IntValue", "Best").Value = stats.bestScore
end

local function readStoredStats(userId)
    if useDataStore then
        return playerStatsStore:GetAsync(userId)
    end
    return devStats[userId]
end

-- 把增量原子地合并到存档上，返回合并后的完整数据
local function addToStoredStats(userId, delta)
    if useDataStore then
        return playerStatsStore:UpdateAsync(userId, function(old)
            local stats = mergeDelta(old, delta)
            stats.lastUpdated = os.time()
            return stats
        end)
    end
    local stats = mergeDelta(devStats[userId], delta)
    stats.lastUpdated = os.time()
    devStats[userId] = stats
    return stats
end

-- 同步 OrderedDataStore 中的排序值（只增不减，避免多服务器写入顺序颠倒）
local function syncBoardValue(board, userId, value)
    if not useDataStore then
        board.devValues[userId] = math.max(board.devValues[userId] or 0, value)
        board.pendingSync[userId] = nil
        return
    end
    local ok = withRetries("Updating " .. board.name .. " board for " .. userId, function()
        board.store:UpdateAsync(userId, function(old)
            return math.max(tonumber(old) or 0, value)
        end)
    end)
    if ok then
        if board.pendingSync[userId] == value then
            board.pendingSync[userId] = nil
        end
    else
        board.pendingSync[userId] = math.max(board.pendingSync[userId] or 0, value)
    end
end

-- 把某个玩家所有待写入的增量写入存档
local function flushPending(userId)
    if flushing[userId] then
        return
    end
    flushing[userId] = true

    while pendingDeltas[userId] do
        local delta = pendingDeltas[userId]
        local applying = { wins = delta.wins, matches = delta.matches, bestScore = delta.bestScore }

        local ok, newStats = withRetries("Saving stats for " .. userId, function()
            return addToStoredStats(userId, applying)
        end)
        if not ok or type(newStats) ~= "table" then
            break -- 留在 pending 中，由定期任务或 BindToClose 重试
        end
        newStats = normalizeStats(newStats)

        delta.wins -= applying.wins
        delta.matches -= applying.matches
        if delta.bestScore <= applying.bestScore then
            delta.bestScore = 0
        end
        if isEmptyDelta(delta) and pendingDeltas[userId] == delta then
            pendingDeltas[userId] = nil
        end

        local entry = statsCache[userId]
        if entry then
            entry.base = newStats
            entry.loaded = true
        end

        if applying.matches > 0 then
            syncBoardValue(BOARDS.wins, userId, newStats.totalWins)
        end
        if applying.bestScore > 0 then
            syncBoardValue(BOARDS.score, userId, newStats.bestScore)
        end
        updatePlayerLeaderstats(Players:GetPlayerByUserId(tonumber(userId)))
    end

    flushing[userId] = nil
end

-- 加载玩家数据（返回当前展示用的数据）
function LeaderboardService.LoadPlayerStats(player)
    if not player then
        return nil
    end
    local userId = tostring(player.UserId)

    local entry = statsCache[userId]
    if not entry then
        entry = { base = nil, loaded = false }
        statsCache[userId] = entry
    end

    if not entry.loaded then
        if loading[userId] then
            while loading[userId] do
                task.wait(0.1)
            end
        else
            loading[userId] = true
            local ok, data = withRetries("Loading stats for " .. userId, function()
                return readStoredStats(userId)
            end)
            -- 读档期间可能已经被 flush 更新过，或者玩家已离开
            if ok and statsCache[userId] == entry and not entry.loaded then
                entry.base = normalizeStats(data)
                entry.loaded = true
            end
            loading[userId] = nil
        end
    end

    updatePlayerLeaderstats(player)
    return getCurrentStats(userId)
end

-- 把一局的结果加入待写入增量；本地立即生效，存档在本帧结束后合并写入
local function addResult(player, wins, matches, score)
    if not player then
        return false
    end
    local userId = tostring(player.UserId)

    local delta = pendingDeltas[userId]
    if not delta then
        delta = { wins = 0, matches = 0, bestScore = 0 }
        pendingDeltas[userId] = delta
    end
    delta.wins += wins
    delta.matches += matches
    delta.bestScore = math.max(delta.bestScore, score)
    if isEmptyDelta(delta) then
        pendingDeltas[userId] = nil
        return true
    end

    if player.Parent then
        local entry = statsCache[userId]
        if not entry or not entry.loaded then
            task.spawn(LeaderboardService.LoadPlayerStats, player)
        end
        updatePlayerLeaderstats(player)
    end

    -- defer：同一帧内的胜负和分数合并成一次写入
    task.defer(flushPending, userId)
    return true
end

-- 记录多人对局的胜负
function LeaderboardService.RecordWin(player)
    return addResult(player, 1, 1, 0)
end

function LeaderboardService.RecordLoss(player)
    return addResult(player, 0, 1, 0)
end

-- 记录一局的最终得分（单人、多人都可调用），只保留历史最高分
function LeaderboardService.RecordScore(player, score)
    score = tonumber(score)
    if not score or score ~= score or score <= 0 or score == math.huge then
        return false
    end
    return addResult(player, 0, 0, math.floor(score))
end

-- ===== 排行榜快照 =====

-- 拉取按排序值降序的列表；complete 表示是否已拿到全部玩家
local function fetchSorted(board)
    local list = {}

    if not useDataStore then
        for userId, value in pairs(board.devValues) do
            table.insert(list, { userId = tonumber(userId), value = value })
        end
        table.sort(list, function(a, b)
            if a.value ~= b.value then
                return a.value > b.value
            end
            return a.userId < b.userId
        end)
        return list, true
    end

    local ok, pages = pcall(function()
        return board.store:GetSortedAsync(false, PAGE_SIZE)
    end)
    if not ok then
        logWarn("GetSortedAsync failed for", board.name, pages)
        return nil, false
    end

    while true do
        for _, item in ipairs(pages:GetCurrentPage()) do
            table.insert(list, { userId = tonumber(item.key), value = tonumber(item.value) or 0 })
        end
        if pages.IsFinished then
            return list, true
        end
        if #list >= RANK_DEPTH then
            return list, false
        end
        -- 预算不足时停止翻页，避免挤占其他 DataStore 请求
        local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync)
        if budget < 1 then
            return list, false
        end
        local advanced, err = pcall(function()
            pages:AdvanceToNextPageAsync()
        end)
        if not advanced then
            logWarn("AdvanceToNextPageAsync failed for", board.name, err)
            return list, false
        end
    end
end

local function getPlayerName(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        return player.Name
    end
    if nameCache[userId] then
        return nameCache[userId]
    end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if ok and name then
        nameCache[userId] = name
        return name
    end
    return "Player " .. tostring(userId)
end

local function getStatsForEntry(userId)
    local key = tostring(userId)
    local entry = statsCache[key]
    if entry and entry.loaded then
        return getCurrentStats(key)
    end
    local ok, data = pcall(readStoredStats, key)
    if ok and data then
        return normalizeStats(data)
    end
    return nil
end

local function makeEntry(board, rank, item, name, stats)
    if board.name == "score" then
        return {
            rank = rank,
            userId = item.userId,
            playerName = name,
            bestScore = item.value,
        }
    end
    local matches = stats and math.max(stats.totalMatches, item.value) or item.value
    return {
        rank = rank,
        userId = item.userId,
        playerName = name,
        totalWins = item.value,
        totalMatches = matches,
        winRatio = matches > 0 and item.value / matches or 0,
    }
end

-- 为前几名补全名字（胜场榜还需要场次），并行请求
local function buildTopEntries(board, list)
    local count = math.min(MAX_ENTRIES, #list)
    local top = table.create(count)
    local remaining = count

    for i = 1, count do
        task.spawn(function()
            local item = list[i]
            local ok, err = pcall(function()
                local name = getPlayerName(item.userId)
                local stats = board.name == "wins" and getStatsForEntry(item.userId) or nil
                top[i] = makeEntry(board, i, item, name, stats)
            end)
            if not ok then
                logWarn("Building leaderboard entry failed:", err)
                top[i] = makeEntry(board, i, item, "Player " .. tostring(item.userId), nil)
            end
            remaining -= 1
        end)
    end

    while remaining > 0 do
        task.wait()
    end
    return top
end

local function getSnapshot(board)
    while board.refreshing do
        task.wait(0.1)
    end
    if os.clock() < board.nextRefreshAt then
        return board.snapshot -- 未到刷新时间（上次失败时可能为 nil）
    end

    board.refreshing = true
    local ok, err = pcall(function()
        local list, complete = fetchSorted(board)
        if list then
            board.snapshot = {
                entries = list,
                complete = complete,
                top = buildTopEntries(board, list),
            }
            board.nextRefreshAt = os.clock() + REFRESH_INTERVAL
        else
            -- 拉取失败：继续使用旧快照（如有），稍后重试
            board.nextRefreshAt = os.clock() + FAILED_REFRESH_INTERVAL
        end
    end)
    board.refreshing = false
    if not ok then
        logWarn("Refreshing", board.name, "leaderboard failed:", err)
        board.nextRefreshAt = os.clock() + FAILED_REFRESH_INTERVAL
    end
    return board.snapshot
end

local function resolveBoard(boardName)
    return BOARDS[boardName] or BOARDS[LeaderboardService.DefaultBoard]
end

-- 获取某张排行榜的前几名；拉取失败且没有缓存时返回 nil
function LeaderboardService.GetLeaderboard(pageSize, boardName)
    local board = resolveBoard(boardName)
    local snap = getSnapshot(board)
    if not snap then
        return nil
    end
    local count = math.clamp(math.floor(tonumber(pageSize) or MAX_ENTRIES), 1, MAX_ENTRIES)
    local result = {}
    for i = 1, math.min(count, #snap.top) do
        table.insert(result, table.clone(snap.top[i]))
    end
    return result
end

-- 获取玩家在某张排行榜上的排名，并附带玩家的全部战绩。
-- rank：名次（排序值相同则名次相同）；排名超出快照范围时 rank 为 nil、
-- rankBeyond 为快照条数（界面显示为 "#1000+"）；未上榜（没打过多人局 / 没有得分）时 rank 为 nil。
function LeaderboardService.GetPlayerRank(player, boardName)
    if not player then
        return nil
    end
    local board = resolveBoard(boardName)
    local stats = LeaderboardService.LoadPlayerStats(player)
    if not stats then
        return nil
    end

    local result = {
        board = board.name,
        totalWins = stats.totalWins,
        totalMatches = stats.totalMatches,
        winRatio = stats.winRatio,
        bestScore = stats.bestScore,
    }
    local value = stats[board.field]
    local onBoard = if board.name == "wins" then stats.totalMatches > 0 else value > 0
    if not onBoard then
        return result
    end

    local snap = getSnapshot(board)
    if not snap then
        return result
    end

    local higher = 0
    local reachedEnd = true
    for _, item in ipairs(snap.entries) do
        if item.value <= value then
            reachedEnd = false
            break
        end
        if item.userId ~= player.UserId then
            higher += 1
        end
    end

    if reachedEnd and not snap.complete then
        result.rankBeyond = #snap.entries
    else
        result.rank = higher + 1
    end
    return result
end

-- ===== 生命周期 =====

local function retryPendingWrites()
    for userId in pairs(pendingDeltas) do
        if not flushing[userId] then
            task.spawn(flushPending, userId)
        end
    end
    for _, board in pairs(BOARDS) do
        for userId, value in pairs(board.pendingSync) do
            task.spawn(syncBoardValue, board, userId, value)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local userId = tostring(player.UserId)
        local entry = statsCache[userId]
        if entry and not entry.loaded and not loading[userId] then
            task.spawn(LeaderboardService.LoadPlayerStats, player)
        end
    end
end

function LeaderboardService.Initialize()
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(LeaderboardService.LoadPlayerStats, player)
    end

    Players.PlayerAdded:Connect(function(player)
        LeaderboardService.LoadPlayerStats(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        local userId = tostring(player.UserId)
        statsCache[userId] = nil
        if pendingDeltas[userId] then
            task.spawn(flushPending, userId)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(RETRY_LOOP_INTERVAL)
            retryPendingWrites()
        end
    end)

    game:BindToClose(function()
        retryPendingWrites()
        local deadline = os.clock() + SHUTDOWN_TIMEOUT
        while os.clock() < deadline and (next(pendingDeltas) ~= nil or next(flushing) ~= nil) do
            task.wait(0.5)
            if next(flushing) == nil and next(pendingDeltas) ~= nil then
                retryPendingWrites() -- 上一轮写入失败，关闭前再试
            end
        end
        if next(pendingDeltas) ~= nil then
            logWarn("Shutting down with unsaved match results")
        end
    end)
end

LeaderboardService.Initialize()

return LeaderboardService
