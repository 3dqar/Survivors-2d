-- Survivors 2D: Support Developer Products -> permanent VIP and animated RGB trail.
-- Single MarketplaceService.ProcessReceipt owner. No receipt is acknowledged until DataStore saved.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local products = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("SupportProducts"))
local productIDs = {}
for _, item in ipairs(products) do
    if type(item.id) == "number" and item.id > 0 then
        assert(not productIDs[item.id], "[Support] duplicate Product ID")
        productIDs[item.id] = true
    end
end

-- Separate VIP store avoids overwriting the existing SurvivorsV2 profile.
local vipStore = DataStoreService:GetDataStore("SurvivorsVIPV1")
local trails = {}
local seenCharacters = {}

local function clearVisuals(player)
    trails[player] = nil
end

local function addVisuals(player, character)
    if player:GetAttribute("SurvivorsVIP") ~= true or not character then return end
    local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10)
    local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
    if not head or not root or player.Character ~= character then return end

    if not head:FindFirstChild("SurvivorsVIPTag") then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "SurvivorsVIPTag"
        billboard.Size = UDim2.fromOffset(150, 32)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
        billboard.MaxDistance = 100
        billboard.AlwaysOnTop = true
        billboard.Parent = head
        local label = Instance.new("TextLabel")
        label.Name = "VIP"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.Text = "★ VIP ★"
        label.TextColor3 = Color3.fromRGB(255, 215, 90)
        label.TextStrokeColor3 = Color3.fromRGB(20, 15, 25)
        label.TextStrokeTransparency = 0.1
        label.TextScaled = true
        label.Parent = billboard
    end

    local trail = root:FindFirstChild("SurvivorsRGBTrail")
    if not trail then
        local top = Instance.new("Attachment")
        top.Name = "SurvivorsTrailTop"
        top.Position = Vector3.new(0, 0.75, 0)
        top.Parent = root
        local bottom = Instance.new("Attachment")
        bottom.Name = "SurvivorsTrailBottom"
        bottom.Position = Vector3.new(0, -0.75, 0)
        bottom.Parent = root
        trail = Instance.new("Trail")
        trail.Name = "SurvivorsRGBTrail"
        trail.Attachment0 = top
        trail.Attachment1 = bottom
        trail.Lifetime = 0.65
        trail.MinLength = 0.04
        trail.FaceCamera = true
        trail.LightEmission = 0.8
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.9)})
        trail.Parent = root
    end
    trails[player] = trail
end

local function updateVIP(player)
    if player:GetAttribute("SurvivorsVIP") == true and player.Character then
        task.spawn(addVisuals, player, player.Character)
    end
end

local function bindPlayer(player)
    seenCharacters[player] = player.CharacterAdded:Connect(function(char)
        clearVisuals(player)
        updateVIP(player)
    end)
    -- A slow initial read must never replace a VIP attribute already granted by a receipt.
    task.spawn(function()
        local ok, data = pcall(function()
            return vipStore:GetAsync(tostring(player.UserId))
        end)
        if player.Parent ~= Players then return end
        if ok then
            if type(data) == "table" and data.vip == true then
                player:SetAttribute("SurvivorsVIP", true)
            end
        else
            warn("[Survivors VIP] Failed loading VIP for " .. tostring(player.UserId))
        end
        updateVIP(player)
    end)
    if player.Character then updateVIP(player) end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(bindPlayer, player) end
Players.PlayerRemoving:Connect(function(player)
    clearVisuals(player)
    if seenCharacters[player] then seenCharacters[player]:Disconnect() end
    seenCharacters[player] = nil
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local tick = os.clock() * 0.17
    for player, trail in pairs(trails) do
        if player.Parent ~= Players or not trail.Parent then
            trails[player] = nil
        else
            trail.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromHSV(tick % 1, 1, 1)),
                ColorSequenceKeypoint.new(0.5, Color3.fromHSV((tick + 0.35) % 1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromHSV((tick + 0.7) % 1, 1, 1)),
            })
        end
    end
end)

MarketplaceService.ProcessReceipt = function(receipt)
    if not productIDs[receipt.ProductId] then
        warn("[Survivors Support] Unknown Product ID: " .. tostring(receipt.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    if type(receipt.PurchaseId) ~= "string" then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local key = tostring(receipt.PlayerId)
    local ok, err = pcall(function()
        vipStore:UpdateAsync(key, function(previous)
            local profile = type(previous) == "table" and previous or {}
            local receipts = type(profile.receipts) == "table" and profile.receipts or {}
            -- Grant is inherently idempotent: permanent VIP flag remains true.
            if not receipts[receipt.PurchaseId] then
                receipts[receipt.PurchaseId] = os.time()
            end
            -- Keep receipt list bounded. Older replay is still safe: VIP is a boolean.
            local count = 0
            for _ in pairs(receipts) do count += 1 end
            if count > 80 then
                local oldestKey, oldestDate
                for id, stamp in pairs(receipts) do
                    if id ~= receipt.PurchaseId and (not oldestDate or stamp < oldestDate) then
                        oldestKey, oldestDate = id, stamp
                    end
                end
                if oldestKey then receipts[oldestKey] = nil end
            end
            profile.vip = true
            profile.receipts = receipts
            return profile
        end)
    end)
    if not ok then
        warn("[Survivors VIP] Purchase not yet saved, Roblox will retry: " .. tostring(err))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local player = Players:GetPlayerByUserId(receipt.PlayerId)
    if player then
        player:SetAttribute("SurvivorsVIP", true)
        updateVIP(player)
    end
    print("[Survivors VIP] VIP granted; receipt " .. receipt.PurchaseId)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
