-- StarterPlayer/StarterPlayerScripts/Minimap_client  (LocalScript)
-- Maža žemėlapio kortelė apačioje dešinėje: žaidėjai, priešai, bosai.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Config"))
local SIZE, MAX_ENEMY_DOTS = 170, 100

local gui = Instance.new("ScreenGui")
gui.Name = "SurvivorsMinimap"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local map = Instance.new("Frame")
map.AnchorPoint = Vector2.new(1, 1)
map.Position = UDim2.new(1, -12, 1, -12)
map.Size = UDim2.fromOffset(SIZE, SIZE)
map.BackgroundColor3 = Color3.fromRGB(14, 16, 28)
map.BackgroundTransparency = 0.2
map.BorderSizePixel = 0
map.ClipsDescendants = true
map.Parent = gui
Instance.new("UICorner", map).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", map)
stroke.Color = Color3.fromRGB(90, 170, 255)
stroke.Transparency = 0.5

local function dot(size, color)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	d.Visible = false
	d.Parent = map
	Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
	return d
end

local enemyDots, playerDots, bossDots = {}, {}, {}
for i = 1, MAX_ENEMY_DOTS do
	enemyDots[i] = dot(3, Color3.fromRGB(255, 90, 90))
end
for i = 1, 12 do
	playerDots[i] = dot(5, Color3.fromRGB(235, 240, 255))
end
for i = 1, 3 do
	bossDots[i] = dot(9, Color3.fromRGB(255, 210, 70))
end

local function place(d, x, z)
	local a = Config.ArenaSize
	d.Position = UDim2.fromOffset(math.clamp((x / a + 0.5) * SIZE, 0, SIZE), math.clamp((z / a + 0.5) * SIZE, 0, SIZE))
	d.Visible = true
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0

	local used, bosses, shown = 0, 0, 0
	local folder = workspace:FindFirstChild("Enemies")
	if folder then
		local kids = folder:GetChildren()
		local step = math.max(1, math.ceil(#kids / MAX_ENEMY_DOTS))
		for i, part in kids do
			if part.Name == "Titan" then
				bosses += 1
				if bossDots[bosses] then
					place(bossDots[bosses], part.Position.X, part.Position.Z)
				end
			elseif i % step == 0 and used < MAX_ENEMY_DOTS then
				used += 1
				place(enemyDots[used], part.Position.X, part.Position.Z)
			end
		end
	end
	for i = used + 1, MAX_ENEMY_DOTS do
		enemyDots[i].Visible = false
	end
	for i = bosses + 1, #bossDots do
		bossDots[i].Visible = false
	end

	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and p:GetAttribute("Alive") ~= false and shown < #playerDots then
			shown += 1
			local d = playerDots[shown]
			d.BackgroundColor3 = p == player and Color3.fromRGB(90, 220, 255) or Color3.fromRGB(235, 240, 255)
			d.Size = p == player and UDim2.fromOffset(7, 7) or UDim2.fromOffset(5, 5)
			place(d, root.Position.X, root.Position.Z)
		end
	end
	for i = shown + 1, #playerDots do
		playerDots[i].Visible = false
	end
end)
