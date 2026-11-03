-- Survivors 2D server-managed playlist. Play exactly one song, then next, repeat.
-- Supported Studio layout:
-- SoundService/Music (Folder or SoundGroup)/01, 02, ...
-- OR SoundService/SoundGroup/01, 02, ... (legacy screenshot).
-- Tracks must be available to this Roblox experience (audio privacy permission).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local function container()
    local named = SoundService:FindFirstChild("Music")
    if named and (named:IsA("Folder") or named:IsA("SoundGroup")) then return named end
    local legacy = SoundService:FindFirstChild("SoundGroup")
    if legacy and legacy:IsA("SoundGroup") then return legacy end
    return nil
end

local function tracks(parent)
    local result = {}
    for _, child in ipairs(parent:GetDescendants()) do
        if child:IsA("Sound") and child.SoundId ~= "" then
            child.Looped = false
            table.insert(result, child)
        end
    end
    table.sort(result, function(a, b)
        if a.Name == b.Name then return a:GetFullName() < b:GetFullName() end
        return a.Name < b.Name
    end)
    return result
end

local function stopAll(list)
    for _, song in ipairs(list) do
        if song.IsPlaying then song:Stop() end
        song.Looped = false
        song.Playing = false
    end
end

local missingLogged = false
while true do
    local parent = container()
    if not parent then
        if not missingLogged then
            warn("[Survivors Music] Missing SoundService/Music or SoundService/SoundGroup. Add a Folder named Music and put Sounds inside.")
            missingLogged = true
        end
        task.wait(3)
        continue
    end
    local songs = tracks(parent)
    if #songs == 0 then
        if not missingLogged then
            warn("[Survivors Music] No Sound children with SoundId in " .. parent:GetFullName())
            missingLogged = true
        end
        task.wait(3)
        continue
    end
    missingLogged = false
    stopAll(songs)

    for _, song in ipairs(songs) do
        if not song:IsDescendantOf(parent) then continue end
        -- Preload before playing; skip inaccessible or invalid tracks without blocking forever.
        local preloadDone = false
        task.spawn(function()
            pcall(function()
                ContentProvider:PreloadAsync({song})
            end)
            preloadDone = true
        end)
        local preloadStart = os.clock()
        while not preloadDone and os.clock() - preloadStart < 12 do
            task.wait(0.1)
        end
        if not song.IsLoaded or song.TimeLength <= 0 then
            warn("[Survivors Music] Cannot load: " .. song.Name .. " (" .. song.SoundId .. "). Check asset permissions.")
            continue
        end

        stopAll(songs)
        local finished = false
        local ended = song.Ended:Connect(function()
            finished = true
        end)
        song.TimePosition = 0
        song.Volume = song.Volume > 0 and song.Volume or 0.35
        song:Play()
        print("[Survivors Music] Now playing: " .. song.Name)

        local deadline = os.clock() + math.max(5, song.TimeLength + 5)
        while song:IsDescendantOf(parent) and not finished and os.clock() < deadline do
            task.wait(0.2)
        end
        ended:Disconnect()
        song:Stop()
    end
    task.wait(0.1)
end
