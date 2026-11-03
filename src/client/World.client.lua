-- StarterPlayer/StarterPlayerScripts/World_client  (LocalScript)
-- Kamera iš viršaus, peiliai, aura, kibirkštys, XP rutuliai, kameros drebėjimas ir kiti efektai.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Defs = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Weapons"))
local fxRemote = ReplicatedStorage:WaitForChild("SurvivorsRemotes"):WaitForChild("Fx")
local Config = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Config"))
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

-- garso efektai (ID keičiami Config.Sounds)
local lastPlay = {}
local function sfx(name, vol, pitch, minGap)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local now = os.clock()
	if now - (lastPlay[name] or 0) < (minGap or 0.05) then
		return
	end
	lastPlay[name] = now
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	s.PlaybackSpeed = pitch or (0.9 + math.random() * 0.2)
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end
local camera = workspace.CurrentCamera

local Block, Ball, Cyl = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

local function plainPart(shape, size, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Shape = shape
	p.Material = material
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	p.Parent = fxFolder
	return p
end

---------------------------------------------------------------------
-- Aplinkos kibirkštys (juda kartu su kamera)
---------------------------------------------------------------------
local embers = plainPart(Block, V(120, 1, 90), WHITE, Enum.Material.SmoothPlastic, 1)
embers.Name = "Embers"
local pe = Instance.new("ParticleEmitter")
pe.Rate = 30
pe.Lifetime = NumberRange.new(4, 7)
pe.Speed = NumberRange.new(1, 3)
pe.EmissionDirection = Enum.NormalId.Top
pe.SpreadAngle = Vector2.new(30, 30)
pe.Size = NumberSequence.new(0.35)
pe.LightEmission = 1
pe.Color = ColorSequence.new(Color3.fromRGB(120, 170, 255), Color3.fromRGB(255, 140, 200))
pe.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1),
})
pe.Parent = embers

---------------------------------------------------------------------
-- Kamera iš viršaus + drebėjimas
---------------------------------------------------------------------
local HEIGHT, BACK, FOV = 56, 24, 70
local focus = Vector3.zero
local shake = 0

local function addShake(a)
	shake = math.max(shake, a)
end
player:GetAttributeChangedSignal("HurtCount"):Connect(function()
	addShake(0.6)
	sfx("hurt", 0.5, 1, 0.25)
end)

RunService:BindToRenderStep("SurvivorsCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	local root = getRoot()
	if root then
		local p = root.Position
		focus = focus:Lerp(V(p.X, 0, p.Z), math.min(1, dt * 10))
	end
	shake = math.max(0, shake - dt * 2.5)
	local off = Vector3.zero
	if shake > 0 then
		off = V((math.random() - 0.5) * shake * 3, 0, (math.random() - 0.5) * shake * 3)
	end
	camera.CFrame = CFrame.lookAt(focus + off + V(0, HEIGHT, BACK), focus + off)
	embers.Position = V(focus.X, 2, focus.Z)
end)

---------------------------------------------------------------------
-- Besisukantys peiliai (ta pati formulė kaip serveryje)
---------------------------------------------------------------------
local blades = {}
local function newBlade()
	return plainPart(Block, V(0.6, 0.6, 3.4), Defs.Weapons.Blades.color, Enum.Material.Neon)
end

---------------------------------------------------------------------
-- Aura po žaidėju
---------------------------------------------------------------------
local aura = plainPart(Cyl, V(0.15, 5, 5), Color3.fromRGB(90, 200, 255), Enum.Material.Neon, 1)
local inferno = plainPart(Cyl, V(0.1, 18, 18), Color3.fromRGB(255, 100, 40), Enum.Material.Neon, 1)

RunService.RenderStepped:Connect(function()
	local root = getRoot()
	local alive = root and player:GetAttribute("Alive") ~= false

	-- peiliai
	local count = alive and (player:GetAttribute("BladeCount") or 0) or 0
	while #blades < count do
		blades[#blades + 1] = newBlade()
	end
	while #blades > count do
		blades[#blades]:Destroy()
		blades[#blades] = nil
	end
	if count > 0 then
		local radius = player:GetAttribute("BladeRadius") or 7
		local speed = player:GetAttribute("BladeSpeed") or 3
		local now = workspace:GetServerTimeNow()
		local o = root.Position
		for i, p in blades do
			local a = now * speed + (i - 1) * (2 * math.pi / count)
			local pos = V(o.X + math.cos(a) * radius, 3, o.Z + math.sin(a) * radius)
			p.CFrame = CFrame.lookAt(pos, pos + V(-math.sin(a), 0, math.cos(a)))
		end
	end

	-- Inferno aura
	local ar = alive and (player:GetAttribute("AuraRadius") or 0) or 0
	if ar > 0 then
		local d = ar * 2 + math.sin(os.clock() * 6) * 0.6
		inferno.Size = V(0.1, d, d)
		inferno.CFrame = CFrame.new(root.Position.X, 0.2, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		inferno.Transparency = 0.8
	else
		inferno.Transparency = 1
	end

	-- aura
	if alive then
		local d = 5 + math.sin(os.clock() * 4) * 0.4
		aura.Size = V(0.15, d, d)
		aura.CFrame = CFrame.new(root.Position.X, 0.12, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		aura.Transparency = 0.75
	else
		aura.Transparency = 1
	end
end)

---------------------------------------------------------------------
-- Efektų pagalbinės funkcijos
---------------------------------------------------------------------
local MAX_LIVE = 220
local live = 0

local function fxPart(shape, size, cf, color, transparency)
	if live >= MAX_LIVE then
		return nil
	end
	live += 1
	local p = plainPart(shape, size, color, Enum.Material.Neon, transparency)
	p.CFrame = cf
	return p
end

local function fade(p, life, goal)
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(life, function()
		live -= 1
		p:Destroy()
	end)
end

---------------------------------------------------------------------
-- XP rutuliai: iššoka iš priešo ir skrenda pas žaidėją
---------------------------------------------------------------------
local orbs = {}

local function spawnOrb(x, y, z)
	if #orbs >= 40 then
		return
	end
	local p = fxPart(Ball, V(0.6, 0.6, 0.6), CFrame.new(x, y, z), Color3.fromRGB(90, 170, 255))
	if p then
		local a = math.random() * math.pi * 2
		orbs[#orbs + 1] = { p = p, pos = V(x, y, z), vel = V(math.cos(a) * 6, 8, math.sin(a) * 6), t = 0 }
	end
end

RunService.RenderStepped:Connect(function(dt)
	local root = getRoot()
	local target = root and (root.Position + V(0, 1, 0))
	local i = 1
	while i <= #orbs do
		local o = orbs[i]
		o.t += dt
		if o.t < 0.3 then
			o.vel += V(0, -30, 0) * dt
			o.pos += o.vel * dt
			if o.pos.Y < 0.5 then
				o.pos = V(o.pos.X, 0.5, o.pos.Z)
			end
		elseif target then
			o.pos = o.pos:Lerp(target, math.min(1, dt * (5 + (o.t - 0.3) * 25)))
		end
		o.p.Position = o.pos
		if o.t > 1.5 or (target and o.t > 0.3 and (o.pos - target).Magnitude < 1.5) then
			o.p:Destroy()
			live -= 1
			orbs[i] = orbs[#orbs]
			orbs[#orbs] = nil
		else
			i += 1
		end
	end
end)

---------------------------------------------------------------------
-- Efektai
---------------------------------------------------------------------
local function killBurst(x, y, z, color, r)
	local n = math.clamp(3 + math.floor(r * 1.5), 3, 14)
	for _ = 1, n do
		local p = fxPart(Block, V(0.6, 0.6, 0.6), CFrame.new(x, y, z) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), color)
		if p then
			local a = math.random() * math.pi * 2
			local d = r + 2 + math.random() * 3
			fade(p, 0.45, {
				Position = V(x + math.cos(a) * d, y + 1 + math.random() * 3, z + math.sin(a) * d),
				Size = V(0.1, 0.1, 0.1),
			})
		end
	end
	local flash = fxPart(Ball, V(r, r, r), CFrame.new(x, y, z), WHITE, 0.3)
	if flash then
		fade(flash, 0.2, { Size = V(r * 3, r * 3, r * 3) })
	end
	spawnOrb(x, y, z)
end

local function damageNumber(x, y, z, amount, crit)
	if live > 150 then
		return
	end
	local p = fxPart(Block, V(0.2, 0.2, 0.2), CFrame.new(x + (math.random() - 0.5) * 2, y, z), WHITE, 1)
	if not p then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 34)
	gui.AlwaysOnTop = true
	gui.Adornee = p
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextSize = crit == 1 and 28 or 18
	t.TextColor3 = crit == 1 and Color3.fromRGB(255, 220, 70) or WHITE
	t.TextStrokeTransparency = 0.3
	t.Text = tostring(amount)
	t.Parent = gui
	fade(p, 0.7, { Position = p.Position + V(0, 4, 0) })
	TweenService:Create(t, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function sparks(x, y, z, crit)
	if live > 110 then
		return
	end
	for _ = 1, crit == 1 and 4 or 2 do
		local origin = V(x, y, z)
		local a = math.random() * math.pi * 2
		local d = 2 + math.random() * 2
		local goal = V(x + math.cos(a) * d, y + math.random() * 2, z + math.sin(a) * d)
		local p = fxPart(Block, V(0.15, 0.15, 0.6), CFrame.lookAt(origin, goal), crit == 1 and Color3.fromRGB(255, 225, 90) or WHITE)
		if p then
			fade(p, 0.2, { Position = goal, Size = V(0.05, 0.05, 0.1) })
		end
	end
end

local function novaRing(x, y, z, radius, color)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
	local p = fxPart(Cyl, V(0.3, 2, 2), cf, color, 0.3)
	if p then
		fade(p, 0.4, { Size = V(0.3, radius * 2, radius * 2) })
	end
	local p2 = fxPart(Cyl, V(0.2, 2, 2), cf, WHITE, 0.2)
	if p2 then
		fade(p2, 0.25, { Size = V(0.2, radius * 1.4, radius * 1.4) })
	end
	local f = fxPart(Ball, V(3, 3, 3), CFrame.new(x, y + 1, z), WHITE, 0.4)
	if f then
		fade(f, 0.2, { Size = V(7, 7, 7) })
	end
	addShake(0.25)
end

local function levelUp(x, y, z)
	local gold = Color3.fromRGB(255, 214, 90)
	local ring = fxPart(Cyl, V(0.3, 3, 3), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), gold, 0.2)
	if ring then
		fade(ring, 0.7, { Size = V(0.3, 30, 30) })
	end
	local ring2 = fxPart(Cyl, V(0.2, 3, 3), CFrame.new(x, y + 0.2, z) * CFrame.Angles(0, 0, math.pi / 2), WHITE, 0.2)
	if ring2 then
		fade(ring2, 0.45, { Size = V(0.2, 16, 16) })
	end
	local beam = fxPart(Block, V(3, 40, 3), CFrame.new(x, 20, z), gold, 0.3)
	if beam then
		fade(beam, 0.6, { Size = V(0.3, 40, 0.3) })
	end
	for _ = 1, 10 do
		local a = math.random() * math.pi * 2
		local d = 2 + math.random() * 4
		local s = fxPart(Block, V(0.4, 0.4, 0.4), CFrame.new(x + math.cos(a) * d, y + 0.5, z + math.sin(a) * d), gold)
		if s then
			fade(s, 0.8, { Position = s.Position + V(0, 8 + math.random() * 6, 0), Size = V(0.1, 0.1, 0.1) })
		end
	end
end

local chainColor = Defs.Weapons.Chain.color
local function chainBolt(pts)
	for i = 1, #pts - 3, 2 do
		local a = V(pts[i], 3, pts[i + 1])
		local b = V(pts[i + 2], 3, pts[i + 3])
		local len = (b - a).Magnitude
		if len > 0.05 then
			local p = fxPart(Block, V(0.5, 0.5, len), CFrame.lookAt((a + b) / 2, b), chainColor)
			if p then
				fade(p, 0.25, {})
			end
		end
		local f = fxPart(Ball, V(1.2, 1.2, 1.2), CFrame.new(b), WHITE, 0.3)
		if f then
			fade(f, 0.2, { Size = V(3, 3, 3) })
		end
	end
end

local function warnRing(x, z, r, delay)
	local cf = CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.pi / 2)
	local outer = fxPart(Cyl, V(0.2, r * 2, r * 2), cf, Color3.fromRGB(255, 70, 50), 0.75)
	if outer then
		fade(outer, delay + 0.1, {})
	end
	local inner = fxPart(Cyl, V(0.25, 1, 1), cf, Color3.fromRGB(255, 110, 60), 0.45)
	if inner then
		fade(inner, delay, { Size = V(0.25, r * 2, r * 2) })
	end
end

fxRemote.OnClientEvent:Connect(function(batch)
	for _, f in batch do
		local t = f[1]
		if t == "k" then
			killBurst(f[2], f[3], f[4], Color3.fromRGB(f[5], f[6], f[7]), f[8])
			sfx("kill", 0.22, nil, 0.07)
		elseif t == "d" then
			damageNumber(f[2], f[3], f[4], f[5], f[6])
			sparks(f[2], f[3], f[4], f[6])
			if f[6] == 1 then
				sfx("crit", 0.25, 1.3, 0.1)
			end
		elseif t == "p" then
			novaRing(f[2], f[3], f[4], f[5], Color3.fromRGB(f[6], f[7], f[8]))
			sfx("nova", 0.45, nil, 0.15)
		elseif t == "c" then
			chainBolt(f[2])
			sfx("chain", 0.3, nil, 0.12)
		elseif t == "u" then
			levelUp(f[2], f[3], f[4])
			sfx("levelup", 0.5, 1, 0.5)
		elseif t == "w" then
			warnRing(f[2], f[3], f[4], f[5])
			sfx("warn", 0.35, 1, 0.3)
		elseif t == "s" then
			-- vietinis garsas (šūviai, peiliai, krentanti skrynia): groja tik netoli žaidėjo
			local root = getRoot()
			if root then
				local dx, dz = root.Position.X - f[3], root.Position.Z - f[4]
				if dx * dx + dz * dz < 110 * 110 then
					if f[2] == "drop" then
						sfx("drop", 0.6, 1, 0.3)
					else
						sfx(f[2], 0.18, nil, 0.1)
					end
				end
			end
		elseif t == "m" then
			sfx("alert", 0.6, 1, 0.5)
			if string.find(f[2], "TITAN") or string.find(f[2], "SWARM") then
				addShake(1.2)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Žemėlapio įvykiai: spalvos tonas + užrašas
---------------------------------------------------------------------
local cc = Instance.new("ColorCorrectionEffect")
cc.Parent = Lighting
local tints = {
	["Blood Moon"] = Color3.fromRGB(255, 150, 150),
	["Meteor Shower"] = Color3.fromRGB(255, 205, 160),
	["XP Frenzy"] = Color3.fromRGB(255, 240, 160),
	["Elite Hunt"] = Color3.fromRGB(235, 205, 255),
}
workspace:GetAttributeChangedSignal("Event"):Connect(function()
	TweenService:Create(cc, TweenInfo.new(1), { TintColor = tints[workspace:GetAttribute("Event") or ""] or WHITE }):Play()
end)

player:GetAttributeChangedSignal("ChestPickup"):Connect(function()
	sfx("pickup", 0.6, 1, 0.2)
end)

local evGui = Instance.new("ScreenGui")
evGui.Name = "SurvivorsEvent"
evGui.ResetOnSpawn = false
evGui.IgnoreGuiInset = true
evGui.DisplayOrder = 6
evGui.Parent = player:WaitForChild("PlayerGui")
local evLabel = Instance.new("TextLabel")
evLabel.AnchorPoint = Vector2.new(0.5, 0)
evLabel.Position = UDim2.new(0.5, 0, 0, 84)
evLabel.Size = UDim2.fromOffset(340, 26)
evLabel.BackgroundTransparency = 1
evLabel.Font = Enum.Font.GothamBlack
evLabel.TextSize = 18
evLabel.TextColor3 = Color3.fromRGB(255, 200, 90)
evLabel.TextStrokeTransparency = 0.4
evLabel.Visible = false
evLabel.Parent = evGui

RunService.RenderStepped:Connect(function()
	local ev = workspace:GetAttribute("Event")
	if ev and ev ~= "" then
		local left = math.max(0, math.ceil((workspace:GetAttribute("EventEnd") or 0) - workspace:GetServerTimeNow()))
		evLabel.Visible = true
		evLabel.Text = string.upper(ev) .. "   " .. left .. "s"
	else
		evLabel.Visible = false
	end
end)
