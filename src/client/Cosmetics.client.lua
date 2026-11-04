-- Local-only cosmetics renderer. No expensive replicated particles, no external asset IDs.
-- The supporter VIP visuals use different names/attachments and are never touched.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("SurvivorsShared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local tracked = {}
local function cleanup(player)
    local t = tracked[player]
    if not t then return end
    if t.model then t.model:Destroy() end
    if t.emitter then t.emitter:Destroy() end
    if t.attachments then for _, a in ipairs(t.attachments) do a:Destroy() end end
    for _, connection in ipairs(t.connections) do connection:Disconnect() end
    tracked[player] = nil
end

local function apply(player)
    local t = tracked[player]
    if not t then return end
    if t.model then t.model:Destroy(); t.model = nil end
    if t.attachments then for _, attachment in ipairs(t.attachments) do attachment:Destroy() end; t.attachments = nil end
    if t.emitter then t.emitter:Destroy(); t.emitter = nil end
    local id = player:GetAttribute("CosmeticTrail")
    local def = type(id) == "string" and Cosmetics.ById[id]
    if not def then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or player.Character ~= character then return end

    local folder = Instance.new("Folder")
    folder.Name = "NHS_CosmeticLocal"
    folder.Parent = root
    t.model = folder

    local a = Instance.new("Attachment")
    a.Name = "CosmeticTop"
    a.Position = Vector3.new(0, 0.55, 0)
    -- Attachments live on HumanoidRootPart; only cosmetic-owned instances are removed.
    a.Parent = root
    local b = Instance.new("Attachment")
    b.Name = "CosmeticBottom"
    b.Position = Vector3.new(0, -0.6, 0)
    b.Parent = root
    -- Keep both roots trackable so re-equipping never accumulates attachments.
    t.attachments = { a, b }

    local trail = Instance.new("Trail")
    trail.Name = "NHS_CosmeticTrail"
    trail.Attachment0 = a
    trail.Attachment1 = b
    trail.Lifetime = (def.style == "smoke" or def.style == "void") and 0.75 or 0.46
    trail.MinLength = 0.08
    trail.FaceCamera = true
    trail.LightEmission = 0.65
    trail.Color = ColorSequence.new(def.colors[1], def.colors[2])
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.27),
        NumberSequenceKeypoint.new(0.5, 0.44),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(0.55, 0.9),
        NumberSequenceKeypoint.new(1, 0),
    })
    trail.Parent = folder

    local emission = Instance.new("ParticleEmitter")
    emission.Name = "NHS_CosmeticSpark"
    emission.Enabled = true
    emission.Rate = (def.style == "flame" or def.style == "spark") and 8 or 5
    emission.Lifetime = NumberRange.new(0.22, 0.65)
    emission.Speed = NumberRange.new(0.4, 1.7)
    emission.SpreadAngle = Vector2.new(28, 28)
    emission.LightEmission = 0.7
    emission.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.18),
        NumberSequenceKeypoint.new(0.7, 0.14),
        NumberSequenceKeypoint.new(1, 0),
    })
    emission.Transparency = NumberSequence.new(0.18, 1)
    emission.Color = ColorSequence.new(def.colors[1], def.colors[2])
    if def.style == "smoke" or def.style == "void" then
        emission.Drag = 4
        emission.Acceleration = Vector3.new(0, 1.5, 0)
        emission.Rate = 5
    elseif def.style == "spark" or def.style == "crystal" then
        emission.Rotation = NumberRange.new(-180, 180)
        emission.RotSpeed = NumberRange.new(-45, 45)
        emission.Rate = 8
    elseif def.style == "petal" then
        emission.Acceleration = Vector3.new(0, -0.7, 0)
        emission.Speed = NumberRange.new(0.2, 1)
        emission.RotSpeed = NumberRange.new(-75, 75)
    elseif def.style == "droplet" then
        emission.Acceleration = Vector3.new(0, -3, 0)
        emission.Speed = NumberRange.new(0.2, 1)
    end
    emission.Parent = b
    t.emitter = emission
    t.trail = trail
    t.id = id
end

local function resetVisual(player)
    local t = tracked[player]
    if not t then return end
    if t.model then t.model:Destroy(); t.model = nil end
    if t.emitter then t.emitter:Destroy(); t.emitter = nil end
    if t.attachments then
        for _, a in ipairs(t.attachments) do a:Destroy() end
        t.attachments = nil
    end
end

local function bind(player)
    if tracked[player] then return end
    local t = { connections = {}, model = nil }
    tracked[player] = t
    table.insert(t.connections, player:GetAttributeChangedSignal("CosmeticTrail"):Connect(function()
        resetVisual(player)
        apply(player)
    end))
    table.insert(t.connections, player.CharacterAdded:Connect(function(character)
        resetVisual(player)
        task.spawn(function()
            local root = character:WaitForChild("HumanoidRootPart", 10)
            if root and player.Character == character and tracked[player] == t then apply(player) end
        end)
    end))
    table.insert(t.connections, player.CharacterRemoving:Connect(function()
        resetVisual(player)
    end))
    if player.Character then task.defer(apply, player) end
end

Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(function(player)
    resetVisual(player)
    cleanup(player)
end)
for _, player in ipairs(Players:GetPlayers()) do bind(player) end

-- Slow, local-only color cycling keeps RGB Prism visually different from the VIP RGB nametag/trail.
local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.13 then return end
    acc = 0
    local hue = (os.clock() * 0.12) % 1
    for player, t in pairs(tracked) do
        if t.id == "rgb_prism" and t.trail and t.trail.Parent and player.Character then
            t.trail.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, 0.8, 1)),
                ColorSequenceKeypoint.new(0.5, Color3.fromHSV((hue + 0.25) % 1, 0.65, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromHSV((hue + 0.5) % 1, 0.9, 1)),
            })
        end
    end
end)
