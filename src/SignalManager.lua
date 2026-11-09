--[[
	一个健壮的信号管理器，用于处理同环境(BindableEvent)和跨环境(RemoteEvent/RemoteFunction)的通信。

	功能:
	- 提供统一的 API 来获取和使用信号。
	- 自动管理 RemoteEvent 和 RemoteFunction 实例在 ReplicatedStorage 中的生命周期。
	- 懒加载：仅在首次请求时创建事件实例。
	- 上下文感知：自动区分服务器和客户端环境，并提供相应的触发方法。

	使用方法:
	内部:
	local SignalManager = require(script.Parent.SignalManager)
	外部:
	local SignalManager = require(path.to.SignalManager)

	-- 获取 Bindable 信号 (Server-Server 或 Client-Client)
	local onQuestCompleted = SignalManager.GetBindable("OnQuestCompleted")
	onQuestCompleted:Connect(function(player, questId) ... end)
	onQuestCompleted:Fire(player, questId)

	-- 获取 Remote 信号 (Server-Client)
	local onShowUI = SignalManager.GetRemote("OnShowUI")
	-- [服务器上] onShowUI:FireClient(player, "Shop")
	-- [客户端上] onShowUI:Connect(function(uiName) ... end)

	-- 获取 Remote 函数 (Server-Client)
	local getPlayerData = SignalManager.GetRemoteFunction("GetPlayerData")
	-- [服务器上] getPlayerData:OnInvoke(function(player) return playerData end)
	-- [客户端上] local data = getPlayerData:Invoke()
]]

-- 服务
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 常量
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()
local REMOTES_FOLDER_NAME = "SignalRemotes_DO_NOT_EDIT" -- RemoteEvent实例的存放文件夹

-- 缓存
local bindableSignals = {}
local remoteSignals = {}
local remoteFunctions = {}

-- 模块主表
local SignalManager = {}

-- 远程实例由服务端创建，客户端等待实际的复制实例。
local function getRemoteInstance(name, className)
    local folder
    local remote
    if IS_SERVER then
        folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = REMOTES_FOLDER_NAME
            folder.Parent = ReplicatedStorage
        end
        remote = folder:FindFirstChild(name)
        if not remote then
            remote = Instance.new(className)
            remote.Name = name
            remote.Parent = folder
        end
    else
        folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, 15)
        assert(folder, "Signal remotes folder did not replicate")
        remote = folder:WaitForChild(name, 15)
    end
    assert(remote and remote:IsA(className), "Missing or invalid " .. className .. ": " .. name)
    return remote
end

--================---- Bindable Signals ----================--

--[[
	获取一个用于同环境通信的 Bindable 信号。
	@param signalName string 信号的唯一名称
	@return table 信号对象
]]
function SignalManager.GetBindable(signalName)
	if bindableSignals[signalName] then
		return bindableSignals[signalName]
	end

	local bindableEvent = Instance.new("BindableEvent")
	local signal = {}

	function signal:Connect(callback)
		return bindableEvent.Event:Connect(callback)
	end

	function signal:Fire(...)
		bindableEvent:Fire(...)
	end

	function signal:Destroy()
		bindableEvent:Destroy()
		bindableSignals[signalName] = nil
	end

	bindableSignals[signalName] = signal
	return signal
end


--================---- Remote Signals ----================--

--[[
	获取一个用于跨环境通信的 Remote 信号。
	@param signalName string 信号的唯一名称
	@return table 信号对象
]]
function SignalManager.GetRemote(signalName)
	if remoteSignals[signalName] then
		return remoteSignals[signalName]
	end

	local remoteEvent = getRemoteInstance(signalName, "RemoteEvent")
	if remoteSignals[signalName] then
		return remoteSignals[signalName]
	end

	local signal = {}

	if IS_SERVER then
		-- 服务器端的 API
		function signal:Connect(callback)
			return remoteEvent.OnServerEvent:Connect(callback)
		end

		function signal:Fire(player, ...)
			remoteEvent:FireClient(player, ...)
		end
		
		function signal:FireClient(player, ...)
			remoteEvent:FireClient(player, ...)
		end

		function signal:FireAll(...)
			remoteEvent:FireAllClients(...)
		end

		function signal:FireAllClients(...)
			remoteEvent:FireAllClients(...)
		end

		function signal:FireAllExcept(player, ...)
			for _, recipient in ipairs(Players:GetPlayers()) do
				if recipient ~= player then
					remoteEvent:FireClient(recipient, ...)
				end
			end
		end

		function signal:FireAllClientsExcept(player, ...)
			self:FireAllExcept(player, ...)
		end
		
	elseif IS_CLIENT then
		-- 客户端的 API
		function signal:Connect(callback)
			return remoteEvent.OnClientEvent:Connect(callback)
		end

		function signal:FireServer(...)
			remoteEvent:FireServer(...)
		end

		-- 在客户端，:Fire() 是 :FireServer() 的一个便捷别名
		function signal:Fire(...)
			remoteEvent:FireServer(...)
		end
	end

	function signal:Destroy()
		-- 只有服务器有权销毁实例
		if IS_SERVER then
			remoteEvent:Destroy()
		end
		remoteSignals[signalName] = nil
	end

	remoteSignals[signalName] = signal
	return signal
end

--================---- Remote Functions ----================--

--[[
	获取一个用于跨环境同步调用的 Remote 函数。
	@param functionName string 函数的唯一名称
	@return table 函数对象
]]
function SignalManager.GetRemoteFunction(functionName)
	if remoteFunctions[functionName] then
		return remoteFunctions[functionName]
	end

	local remoteFunc = getRemoteInstance(functionName, "RemoteFunction")
	if remoteFunctions[functionName] then
		return remoteFunctions[functionName]
	end

	local funcObj = {}

	if IS_SERVER then
		-- 服务器端的 API
		function funcObj:OnInvoke(callback)
			remoteFunc.OnServerInvoke = callback
		end
		
		function funcObj:InvokeClient(player, ...)
			return remoteFunc:InvokeClient(player, ...)
		end
		
	elseif IS_CLIENT then
		-- 客户端的 API
		function funcObj:OnInvoke(callback)
			remoteFunc.OnClientInvoke = callback
		end

		function funcObj:Invoke(...)
			return remoteFunc:InvokeServer(...)
		end
	end

	function funcObj:Destroy()
		-- 只有服务器有权销毁实例
		if IS_SERVER then
			remoteFunc:Destroy()
		end
		remoteFunctions[functionName] = nil
	end

	remoteFunctions[functionName] = funcObj
	return funcObj
end

return SignalManager