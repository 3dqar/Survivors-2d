-- Survivors 2D Support tiers: 50 yellow tag, 100 RGB tag, 1000 RGB tag + RGB trail.
-- Developer Products are permanent *highest-purchased-tier* cosmetics.
-- IMPORTANT: only one server script may own MarketplaceService.ProcessReceipt.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local products = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("SupportProducts"))
local byId = {}
for _, item in ipairs(products) do
    assert(type(item.id) == "number" and item.id > 0, "Support Product ID missing")
    assert(type(item.tier) == "number" and item.tier >= 1 and item.tier <= 3, "Invalid Support tier")
    assert(not byId[item.id], "Duplicate Support Product ID")
    byId[item.id] = item.tier
end

-- Keep existing DataStore name for migration; don't touch SurvivorsV2 profiles.
local store = DataStoreService:GetDataStore("SurvivorsVIPV1")
local visuals = {} -- [player] = { tag = TextLabel, trail = Trail? }
local connections = {}

local function setTier(player, tier)
    tier = math.clamp(math.floor(tonumber(tier) or 0), 0, 3)
    local previous = tonumber(player:GetAttribute("SupportTier")) or 0
    if tier > previous then
        player:SetAttribute("SupportTier", tier)
    end
    if math.max(previous, tier) > 0 then
        player:SetAttribute("SurvivorsVIP", true) -- compatibility with previous VIP flag
    end
end

local function removeOldVisuals(character)
    local head = character:FindFirstChild("Head")
    if head then
        local old = head:FindFirstChild("SurvivorsVIPTag")
        if old then old:Destroy() end
    end
end

local function applyVisuals(player, character)
    if player.Character ~= character then return end
    local tier = tonumber(player:GetAttribute("SupportTier")) or 0
    if tier < 1 then return end

    local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10)
    if not head or player.Character ~= character then return end
    local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
    if not root or player.Character ~= character then return end

    removeOldVisuals(character)
    local billboard = head:FindFirstChild("SurvivorsSupporterTag")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "SurvivorsSupporterTag"
        billboard.Size = UDim2.fromOffset(190, 38)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
        billboard.MaxDistance = 110
        billboard.AlwaysOnTop = true
        billboard.Parent = head
    end
    local label = billboard:FindFirstChild("SupporterText")
    if not label then
        label = Instance.new("TextLabel")
        label.Name = "SupporterText"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBlack
        label.Text = "★ SUPPORTER ★"
        label.TextColor3 = Color3.fromRGB(255, 213, 66)
        label.TextStrokeColor3 = Color3.fromRGB(24, 15, 33)
        label.TextStrokeTransparency = 0.12
        label.TextScaled = true
        label.Parent = billboard
    end

    local trail = root:FindFirstChild("SurvivorsRGBTrail")
    if tier == 3 then
        local top = root:FindFirstChild("SurvivorsTrailTop")
        if not top then
            top = Instance.new("Attachment")
            top.Name = "SurvivorsTrailTop"
            top.Position = Vector3.new(0, 0.85, 0)
            top.Parent = root
        end
        local bottom = root:FindFirstChild("SurvivorsTrailBottom")
        if not bottom then
            bottom = Instance.new("Attachment")
            bottom.Name = "SurvivorsTrailBottom"
            bottom.Position = Vector3.new(0, -0.85, 0)
            bottom.Parent = root
        end
        if not trail then
            trail = Instance.new("Trail")
            trail.Name = "SurvivorsRGBTrail"
            trail.Attachment0 = top
            trail.Attachment1 = bottom
            trail.Lifetime = 0.65
            trail.MinLength = 0.03
            trail.LightEmission = 0.8
            trail.FaceCamera = true
            trail.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.03),
                NumberSequenceKeypoint.new(1, 0.95),
            })
            trail.Parent = root
        end
    elseif trail then
        trail:Destroy()
        trail = nil
    end
    visuals[player] = {tag = label, trail = trail, character = character}
end

local function refresh(player)
    if player.Character and (tonumber(player:GetAttribute("SupportTier")) or 0) > 0 then
        task.spawn(applyVisuals, player, player.Character)
    end
end

local function bind(player)
    connections[player] = {
        player.CharacterAdded:Connect(function(character)
            visuals[player] = nil
            task.spawn(function()
                applyVisuals(player, character)
            end)
        end),
        player:GetAttributeChangedSignal("SupportTier"):Connect(function()
            refresh(player)
        end),
    }
    task.spawn(function()
        local ok, record = pcall(function()
            return store:GetAsync(tostring(player.UserId))
        end)
        if player.Parent ~= Players then return end
        if ok then
            if type(record) == "table" then
                local tier = tonumber(record.tier) or (record.vip == true and 1 or 0)
                setTier(player, tier)
            end
        else
            warn("[Survivors Support] Failed to load supporter status for " .. player.UserId)
        end
        refresh(player)
    end)
    refresh(player)
end

Players.PlayerAdded:Connect(bind)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(bind, player)
end
Players.PlayerRemoving:Connect(function(player)
    visuals[player] = nil
    if connections[player] then
        for _, connection in ipairs(connections[player]) do
            connection:Disconnect()
        end
        connections[player] = nil
    end
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
    accumulator += dt
    if accumulator < 0.1 then return end
    accumulator = 0
    local t = (os.clock() * 0.16) % 1
    for player, state in pairs(visuals) do
        if player.Parent ~= Players or player.Character ~= state.character or not state.tag.Parent then
            visuals[player] = nil
        else
            local tier = tonumber(player:GetAttribute("SupportTier")) or 0
            if tier == 1 then
                state.tag.TextColor3 = Color3.fromRGB(255, 213, 66)
            elseif tier >= 2 then
                state.tag.TextColor3 = Color3.fromHSV(t, 0.95, 1)
            end
            if tier >= 3 and state.trail and state.trail.Parent then
                state.trail.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(t, 1, 1)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromHSV((t + 0.35) % 1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV((t + 0.7) % 1, 1, 1)),
                })
            end
        end
    end
end)

MarketplaceService.ProcessReceipt = function(receipt)
    local purchasedTier = byId[receipt.ProductId]
    if not purchasedTier then
        warn("[Survivors Support] Unknown Developer Product " .. tostring(receipt.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    if type(receipt.PurchaseId) ~= "string" or receipt.PurchaseId == "" then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local newTier = purchasedTier
    local ok, err = pcall(function()
        local result = store:UpdateAsync(tostring(receipt.PlayerId), function(previous)
            local record = type(previous) == "table" and previous or {}
            local current = tonumber(record.tier) or (record.vip == true and 1 or 0)
            -- Highest tier is never reduced by a later lower-priced purchase.
            record.tier = math.max(current, purchasedTier)
            record.vip = true -- migration compatibility
            local receipts = type(record.receipts) == "table" and record.receipts or {}
            receipts[receipt.PurchaseId] = os.time()
            -- Bound the optional receipt log; permanent highest tier is the durable entitlement.
            local count = 0
            for _ in pairs(receipts) do count += 1 end
            if count > 80 then
                local oldestId, oldestTime
                for purchaseId, timestamp in pairs(receipts) do
                    if purchaseId ~= receipt.PurchaseId and
                        (oldestTime == nil or (tonumber(timestamp) or 0) < oldestTime) then
                        oldestId, oldestTime = purchaseId, tonumber(timestamp) or 0
                    end
                end
                if oldestId then receipts[oldestId] = nil end
            end
            record.receipts = receipts
            return record
        end)
        assert(type(result) == "table", "Invalid DataStore result")
        newTier = tonumber(result.tier) or purchasedTier
    end)
    if not ok then
        warn("[Survivors Support] Failed to persist receipt; will retry: " .. tostring(err))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local player = Players:GetPlayerByUserId(receipt.PlayerId)
    if player then
        setTier(player, newTier)
        refresh(player)
    end
    print("[Survivors Support] Purchase saved: " .. tostring(receipt.PurchaseId) ..
        " | tier " .. tostring(newTier))
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
