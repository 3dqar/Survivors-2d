-- ServerScriptService/Survivors/Meta_server  (Script)
-- RemoteFunction "Meta": meniu (lentelė, skrynios, patobulinimai) kalba su serveriu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Persistence = require(script.Parent:WaitForChild("Persistence"))

local remotes = ReplicatedStorage:WaitForChild("SurvivorsRemotes")
local rf = Instance.new("RemoteFunction")
rf.Name = "Meta"
rf.Parent = remotes

local actions = {
	open = Persistence.open, keep = Persistence.keep, sell = Persistence.sell, buy = Persistence.buy,
}
local last = {}

rf.OnServerInvoke = function(player, action)
	local now = os.clock()
	if last[player] and now - last[player] < 0.15 then
		return nil
	end
	last[player] = now
	local fn = type(action) == "string" and actions[action]
	if fn then
		return fn(player)
	end
	return Persistence.state(player, true)
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
