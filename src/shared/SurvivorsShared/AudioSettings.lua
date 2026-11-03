-- Client-only volume settings for Survivors 2D.
-- Separate per-player Music and FX channels using local SoundGroups.
-- Session settings: no DataStore access required.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local Audio = {}
local levels = { Music = 0.65, FX = 0.8 }
local groups = {}
for _, kind in ipairs({ "Music", "FX" }) do
    local group = SoundService:FindFirstChild("Survivors" .. kind .. "Volume")
    if not group or not group:IsA("SoundGroup") then
        group = Instance.new("SoundGroup")
        group.Name = "Survivors" .. kind .. "Volume"
        group.Parent = SoundService
    end
    group.Volume = levels[kind]
    groups[kind] = group
end

local function isPlaylistSound(sound)
    local folder = SoundService:FindFirstChild("Music")
    if not folder then
        folder = SoundService:FindFirstChild("SoundGroup")
    end
    return folder ~= nil and sound:IsDescendantOf(folder)
end

function Audio.assignFX(sound)
    if sound and sound:IsA("Sound") then
        sound.SoundGroup = groups.FX
    end
end

local function classify(sound)
    if sound:IsA("Sound") then
        sound.SoundGroup = isPlaylistSound(sound) and groups.Music or groups.FX
    end
end

-- Existing music and any new Sound inserted later are routed to the correct channel.
for _, item in ipairs(SoundService:GetDescendants()) do
    classify(item)
end
SoundService.DescendantAdded:Connect(function(item)
    classify(item)
end)

function Audio.get(kind)
    return levels[kind] or 0
end

function Audio.set(kind, level)
    if not groups[kind] then return end
    local value = math.clamp(tonumber(level) or 0, 0, 1)
    value = math.floor(value * 100 + 0.5) / 100
    levels[kind] = value
    groups[kind].Volume = value
    if localPlayer then
        localPlayer:SetAttribute("Survivors" .. kind .. "Volume", value)
    end
end

Audio.set("Music", levels.Music)
Audio.set("FX", levels.FX)
return Audio
