-- ServerScriptService/Survivors/Arena_server  (Script)
-- Sukuria areną (workspace.SurvivorsArena), apšvietimą ir atsiradimo aikštelę.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Config"))

local size = Config.ArenaSize

-- standartinis Baseplate trukdytų (z-fighting)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

local arena = Instance.new("Folder")
arena.Name = "SurvivorsArena"

local function block(name, sz, pos, color, material, transparency, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = sz
	p.Position = pos
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	p.CanCollide = collide
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = arena
	return p
end

-- grindys ir tinklelis (tinklelis padeda matyti judėjimą iš viršaus)
block("Floor", Vector3.new(size, 2, size), Vector3.new(0, -1, 0), Color3.fromRGB(24, 26, 42), Enum.Material.SmoothPlastic, 0, true)
local lineColor = Color3.fromRGB(48, 58, 108)
for i = -size / 2, size / 2, 40 do
	block("LineX", Vector3.new(0.3, 0.1, size), Vector3.new(i, 0.05, 0), lineColor, Enum.Material.Neon, 0, false)
	block("LineZ", Vector3.new(size, 0.1, 0.3), Vector3.new(0, 0.05, i), lineColor, Enum.Material.Neon, 0, false)
end

-- nematomos sienos + švytinti riba
local edge = Color3.fromRGB(210, 70, 115)
for _, s in { -1, 1 } do
	block("WallZ", Vector3.new(size + 8, 80, 4), Vector3.new(0, 40, s * (size / 2 + 2)), edge, Enum.Material.SmoothPlastic, 1, true)
	block("WallX", Vector3.new(4, 80, size + 8), Vector3.new(s * (size / 2 + 2), 40, 0), edge, Enum.Material.SmoothPlastic, 1, true)
	block("EdgeZ", Vector3.new(size, 0.4, 0.6), Vector3.new(0, 0.2, s * (size / 2 - 0.3)), edge, Enum.Material.Neon, 0, false)
	block("EdgeX", Vector3.new(0.6, 0.4, size), Vector3.new(s * (size / 2 - 0.3), 0.2, 0), edge, Enum.Material.Neon, 0, false)
end

-- atsiradimo aikštelė centre
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(10, 0.4, 10)
spawn.Position = Vector3.new(0, 0.2, 0)
spawn.Neutral = true
spawn.Duration = 0
spawn.Material = Enum.Material.Neon
spawn.Color = Color3.fromRGB(90, 200, 255)
spawn.Transparency = 0.5
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Parent = arena

-- apšvietimas
Lighting.ClockTime = 0
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(85, 90, 125)
Lighting.OutdoorAmbient = Color3.fromRGB(85, 90, 125)
Lighting.GlobalShadows = false
if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end

arena.Parent = workspace
