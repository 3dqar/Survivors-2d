-- Survivors 2D - playlist: plays songs in order and repeats forever.
-- Roblox Studio: SoundService > Music (Folder) > 01, 02, 03... (Sound).
-- Songs must have valid SoundId and be usable by this experience.
local SoundService = game:GetService("SoundService")
local folder = SoundService:WaitForChild("Music", 30)
if not folder then
    warn("[Survivors Music] Create SoundService/Music Folder and move your Sound objects into it.")
    return
end

local function sortedSongs()
    local songs = {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Sound") and obj.SoundId ~= "" then
            table.insert(songs, obj)
            obj.Looped = false
            obj:Stop() -- prevent multiple autoplaying tracks
        end
    end
    table.sort(songs, function(a, b)
        return a.Name < b.Name
    end)
    return songs
end

local songs = sortedSongs()
if #songs == 0 then
    warn("[Survivors Music] Music folder has no Sounds with SoundId.")
    return
end

while true do
    for _, song in ipairs(songs) do
        if song.Parent == folder then
            -- Stop any tracks left playing by another script or Studio settings.
            for _, other in ipairs(songs) do
                if other ~= song and other.IsPlaying then other:Stop() end
            end
            song.Looped = false
            song.TimePosition = 0
            local finished = false
            local connection = song.Ended:Connect(function()
                finished = true
            end)
            song:Play()
            -- Ended is fired at natural completion. If audio is removed or invalid,
            -- move on rather than hanging forever.
            local deadline = os.clock() + 300
            while not finished and song.Parent == folder and os.clock() < deadline do
                task.wait(0.25)
                if song.IsLoaded and song.TimeLength > 0 then
                    deadline = math.max(deadline, os.clock() + song.TimeLength + 5)
                end
            end
            connection:Disconnect()
            song:Stop()
        end
    end
    task.wait(0.1)
    songs = sortedSongs()
    if #songs == 0 then
        warn("[Survivors Music] No songs found, stopping music controller.")
        return
    end
end
