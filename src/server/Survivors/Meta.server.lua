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
	-- Server-side permission check: menu actions are for dead players only.
	if type(action) == "string" and action ~= "state" then
		if player:GetAttribute("Alive") ~= false or player:GetAttribute("HasDied") ~= true then
			return Persistence.state(player, false, "Menu available only after death.")
		end
	end
	local fn = type(action) == "string" and actions[action]
	if fn then
		return fn(player)
	end
	return Persistence.state(player, true)
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
