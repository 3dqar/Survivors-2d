-- StarterPlayer/StarterPlayerScripts/Menu_client  (LocalScript)
-- Meniu tik po mirties (MENU arba M): Leaderboard / Chests / Upgrades / Goals (pasiekimai + dienos iššūkiai).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("SurvivorsShared")
local Meta = require(Shared:WaitForChild("Meta"))
local Config = require(Shared:WaitForChild("Config"))
local SupportProducts = require(Shared:WaitForChild("SupportProducts"))
local AudioSettings = require(Shared:WaitForChild("AudioSettings"))
local remotes = ReplicatedStorage:WaitForChild("SurvivorsRemotes")
local metaRF = remotes:WaitForChild("Meta")
local joinRemote = remotes:WaitForChild("Join")

local BG, PANEL, ACC, TXT = Color3.fromRGB(14, 16, 28), Color3.fromRGB(30, 34, 56), Color3.fromRGB(90, 170, 255), Color3.fromRGB(235, 238, 250)
local DIM = Color3.fromRGB(190, 195, 225)
local TOUCH = UserInputService.TouchEnabled
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

local function text(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or TXT
	props.TextSize = props.TextSize or 16
	return new("TextLabel", props, parent)
end

local function button(props, parent, onClick)
	props.Font = Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or TXT
	props.TextSize = props.TextSize or 16
	props.BackgroundColor3 = props.BackgroundColor3 or ACC
	props.BorderSizePixel = 0
	local b = new("TextButton", props, parent)
	round(b, 8)
	b.Activated:Connect(onClick)
	return b
end

local function sfx(name, vol)
	local id = Config.Sounds[name]
	if id and id ~= "" then
		local s = new("Sound", { SoundId = id, Volume = vol or 0.5 }, SoundService)
		AudioSettings.assignFX(s)
		s:Play()
		task.delay(4, function()
			s:Destroy()
		end)
	end
end

local function fmt(secs)
	secs = math.floor(secs or 0)
	return string.format("%d:%02d", secs // 60, secs % 60)
end

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "SurvivorsMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))

local menuBtn = button({
	Text = "MENU", Size = TOUCH and UDim2.fromOffset(156, 48) or UDim2.fromOffset(160, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 95, 1, -24),
	BackgroundColor3 = PANEL, TextSize = 15,
}, gui, function() end)

local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(3, 4, 12), BackgroundTransparency = 0.24, BorderSizePixel = 0, Visible = false, ZIndex = 9, Active = true }, gui)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.86),
	BackgroundColor3 = BG, BorderSizePixel = 0, Visible = false, ZIndex = 10,
}, gui)
round(panel, 14)
new("UISizeConstraint", { MaxSize = Vector2.new(920, 620) }, panel)
new("UIStroke", { Color = Color3.fromRGB(90, 105, 140), Thickness = 2 }, panel)

local menuTitle = text({ Position = UDim2.fromOffset(24, 9), Size = UDim2.new(1, -95, 0, 46), Text = "MENU", Font = Enum.Font.GothamBlack, TextColor3 = ACC, TextSize = TOUCH and 26 or 34, TextXAlignment = LEFT, ZIndex = 12 }, panel)
local tabsFrame = new("ScrollingFrame", {
    Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 46),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
    ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.X,
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 11,
}, panel)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabsFrame)

local content = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 116), Size = UDim2.new(1, -28, 1, -190), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 11,
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)

local S, tab, busy = nil, "Leaderboard", false
local startChestAnimation
local chestAnimating = false
local order = 0
local render

local function act(action)
	if busy then
		return
	end
	busy = true
	local ok, res = pcall(function()
		return metaRF:InvokeServer(action)
	end)
	busy = false
	if ok and res then
		S = res
		if action == "open" and res.ok and res.pending then
			sfx("chest", 0.7)
		elseif action ~= "state" then
			sfx("click", 0.4)
		end
		render()
		if action == "open" and res.ok and res.pending and startChestAnimation then
			startChestAnimation(res.pending, true)
		elseif (action == "keep" or action == "sell") and res.ok and not res.pending and startChestAnimation then
			startChestAnimation(nil, false)
		end
	end
end

local function row(height)
	order += 1
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = PANEL, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 12 }, content)
	round(f, 8)
	return f
end

local function header(t)
	local r = row(26)
	r.BackgroundTransparency = 1
	text({ Size = UDim2.fromScale(1, 1), Text = t, TextColor3 = ACC, TextSize = 14, TextXAlignment = LEFT, ZIndex = 13 }, r)
end

local function renderBoard()
	header(string.format("YOUR ALL-TIME RECORDS  |  Best kills: %d   Best level: %d", S.bestKills or 0, S.bestLevel or 0))
	local r0 = row(30)
	text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = string.format("Total kills: %d    Longest run: %s", S.kills or 0, fmt(S.best)), TextXAlignment = LEFT, TextSize = 14, ZIndex = 13 }, r0)
	header("THIS SERVER  -  current run")
	for i, e in S.server do
		local r = row(30)
		text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.45, 0, 1, 0), Text = i .. ". " .. e.name, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13 }, r)
		text({
			Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -10, 1, 0), TextXAlignment = RIGHT, TextSize = 14, TextColor3 = DIM, ZIndex = 13,
			Text = string.format("Lv %d   Kills %d   Best %s", e.level, e.kills, fmt(e.best)),
		}, r)
	end
	local boards = {
		{ "GLOBAL TOP - most kills in one run", S.topKills, false },
		{ "GLOBAL TOP - highest level", S.topLevel, false },
		{ "GLOBAL TOP - total lifetime kills", S.topTotalKills, false },
		{ "GLOBAL TOP - longest survival", S.top, true },
	}
	for _, board in boards do
		header(board[1])
		if #(board[2] or {}) == 0 then
			local empty = row(30)
			text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = "No saved scores yet (publish + enable API access in Studio).", TextXAlignment = LEFT, TextSize = 13, TextColor3 = DIM, ZIndex = 13 }, empty)
		end
		for i, e in board[2] or {} do
			local r = row(30)
			text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = i .. ". " .. e.name, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13 }, r)
			text({ Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -10, 1, 0), Text = board[3] and fmt(e.score) or tostring(e.score), TextXAlignment = RIGHT, TextColor3 = Color3.fromRGB(255, 215, 90), ZIndex = 13 }, r)
		end
	end
end

local function renderChests()
    local r = row(74)
    text({
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -240, 1, 0),
        TextXAlignment = LEFT, TextWrapped = true, TextSize = 15, ZIndex = 13,
        Text = "Chests: " .. tostring(S.chests or 0) .. "\nOpen a chest to roll a permanent upgrade!",
    }, r)
    button({
        Text = S.pending and "VIEW REWARD" or "OPEN",
        Size = UDim2.fromOffset(S.pending and 125 or 90, 42),
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -128, 0.5, 0), ZIndex = 13,
    }, r, function()
        if chestAnimating then return end
        if S.pending then
            if startChestAnimation then startChestAnimation(S.pending, false) end
        else
            act("open")
        end
    end)
    button({
        Text = "BUY " .. tostring(S.price or 0), Size = UDim2.fromOffset(110, 42),
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(240, 190, 70),
        TextColor3 = Color3.fromRGB(30, 25, 10), ZIndex = 13,
    }, r, function()
        if not chestAnimating then act("buy") end
    end)
    if S.msg then
        local m = row(34)
        text({
            Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
            Text = S.msg, TextXAlignment = LEFT, TextSize = 14,
            TextColor3 = S.ok and Color3.fromRGB(120, 230, 150) or Color3.fromRGB(255, 130, 130),
            TextWrapped = true, ZIndex = 13,
        }, m)
    end
    if S.pending then
        local p = S.pending
        local st, rarity = Meta.Stats[p.stat], Meta.Rarities[p.r]
        if st and rarity then
            local preview = row(70)
            new("UIStroke", { Color = rarity.color, Thickness = 1.5 }, preview)
            text({
                Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28),
                Text = rarity.name:upper() .. "  •  " .. st.name, Font = Enum.Font.GothamBlack,
                TextColor3 = rarity.color, TextXAlignment = LEFT, TextSize = 19, ZIndex = 13,
            }, preview)
            text({
                Position = UDim2.fromOffset(12, 37), Size = UDim2.new(1, -24, 0, 24),
                Text = "You have an unclaimed reward. Press VIEW REWARD to keep or sell.",
                TextXAlignment = LEFT, TextWrapped = true, TextColor3 = DIM, TextSize = 13, ZIndex = 13,
            }, preview)
        end
    end
end

-- CS-style visual roulette only: server already selected the actual item.
-- KEEP/SELL only appear once roulette stops. Pending rewards stay on server.
local roulette = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 7, 16),
    BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false,
    ZIndex = 60, Active = true,
}, gui)
local roulettePanel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0.94, 0, 0, 370), BackgroundColor3 = BG,
    BorderSizePixel = 0, ZIndex = 61,
}, roulette)
round(roulettePanel, 16)
new("UISizeConstraint", { MaxSize = Vector2.new(840, 370) }, roulettePanel)
new("UIStroke", { Color = Color3.fromRGB(90, 105, 140), Thickness = 2 }, roulettePanel)
local rouletteTitle = text({
    Position = UDim2.new(0, 12, 0, 16), Size = UDim2.new(1, -24, 0, 36),
    Text = "OPENING CHEST...", Font = Enum.Font.GothamBlack, TextSize = 25,
    TextColor3 = Color3.fromRGB(255, 210, 85), TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 62,
}, roulettePanel)
local viewport = new("Frame", {
    Position = UDim2.new(0, 18, 0, 72), Size = UDim2.new(1, -36, 0, 142),
    ClipsDescendants = true, BackgroundColor3 = Color3.fromRGB(13, 16, 30),
    BorderSizePixel = 0, ZIndex = 62,
}, roulettePanel)
round(viewport, 9)
local strip = new("Frame", {
    Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 6500, 1, 0),
    BackgroundTransparency = 1, ZIndex = 63,
}, viewport)
local pointer = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
    Size = UDim2.fromOffset(4, 142), BackgroundColor3 = Color3.fromRGB(255, 227, 96),
    BorderSizePixel = 0, ZIndex = 67,
}, viewport)
local rouletteResult = text({
    Position = UDim2.new(0, 12, 0, 225), Size = UDim2.new(1, -24, 0, 38),
    Text = "", Font = Enum.Font.GothamBlack, TextSize = 21, TextWrapped = true,
    TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62,
}, roulettePanel)
local rouletteDetails = text({
    Position = UDim2.new(0, 12, 0, 260), Size = UDim2.new(1, -24, 0, 29),
    Text = "", TextSize = 14, TextColor3 = DIM, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62,
}, roulettePanel)
local keepButton = button({
    Text = "KEEP", Position = UDim2.new(0.5, -158, 1, -67),
    Size = UDim2.fromOffset(146, 46), BackgroundColor3 = Color3.fromRGB(65, 184, 107),
    TextSize = 19, Visible = false, ZIndex = 64,
}, roulettePanel, function()
    if chestAnimating or busy then return end
    act("keep")
end)
local sellButton = button({
    Text = "SELL", Position = UDim2.new(0.5, 12, 1, -67),
    Size = UDim2.fromOffset(146, 46), BackgroundColor3 = Color3.fromRGB(209, 151, 50),
    TextColor3 = Color3.fromRGB(22, 21, 16),
    TextSize = 19, Visible = false, ZIndex = 64,
}, roulettePanel, function()
    if chestAnimating or busy then return end
    act("sell")
end)

local activeRoulette = 0
startChestAnimation = function(pending, animate)
    activeRoulette += 1
    local token = activeRoulette
    if not pending then
        chestAnimating = false
        roulette.Visible = false
        return
    end
    local reward = Meta.Stats[pending.stat]
    local rarity = Meta.Rarities[pending.r]
    if not reward or not rarity then return end

    roulette.Visible = true
    chestAnimating = animate
    keepButton.Visible = false
    sellButton.Visible = false
    rouletteResult.Text = ""
    rouletteDetails.Text = ""
    rouletteTitle.Text = animate and "OPENING CHEST..." or "YOUR CHEST REWARD"
    for _, child in ipairs(strip:GetChildren()) do child:Destroy() end

    local cardW, gap = 132, 8
    local step = cardW + gap
    local count, winningIndex = 43, 37
    local rng = Random.new()
    local function createTile(index, statId, rarityId)
        local stat = Meta.Stats[statId]
        local rar = Meta.Rarities[rarityId]
        local tile = new("Frame", {
            Position = UDim2.fromOffset((index - 1) * step, 7),
            Size = UDim2.fromOffset(cardW, 126),
            BackgroundColor3 = Color3.fromRGB(32, 36, 58), BorderSizePixel = 0,
            ZIndex = 64,
        }, strip)
        round(tile, 8)
        new("UIStroke", { Color = rar.color, Thickness = 2 }, tile)
        text({
            Position = UDim2.fromOffset(5, 9), Size = UDim2.new(1, -10, 0, 24),
            Text = rar.name:upper(), TextColor3 = rar.color,
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 65,
        }, tile)
        text({
            Position = UDim2.fromOffset(5, 41), Size = UDim2.new(1, -10, 0, 42),
            Text = stat.name, TextColor3 = stat.color, Font = Enum.Font.GothamBlack,
            TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 65,
        }, tile)
        text({
            Position = UDim2.fromOffset(5, 92), Size = UDim2.new(1, -10, 0, 23),
            Text = "+" .. tostring(rar.lv) .. " LV", TextColor3 = DIM,
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 65,
        }, tile)
    end

    for i = 1, count do
        local statId, rarityId
        if i == winningIndex then
            statId, rarityId = pending.stat, pending.r
        else
            statId, rarityId = Meta.roll(rng)
        end
        createTile(i, statId, rarityId)
    end
    strip.Size = UDim2.new(0, count * step, 1, 0)
    local center = math.max(1, viewport.AbsoluteSize.X) / 2
    local selectedX = (winningIndex - 1) * step + cardW / 2
    strip.Position = UDim2.fromOffset(center - (cardW / 2), 0)

    local function reveal()
        if token ~= activeRoulette then return end
        chestAnimating = false
        rouletteTitle.Text = "YOU UNBOXED!"
        rouletteResult.Text = rarity.name:upper() .. "  -  " .. reward.name
        rouletteResult.TextColor3 = rarity.color
        local current = ((S and S.up) and S.up[pending.stat]) or 0
        rouletteDetails.Text = reward.text .. "  |  Current: " .. current .. " / " .. Meta.MaxLevel
        keepButton.Text = current >= Meta.MaxLevel and "MAXED" or "KEEP"
        sellButton.Text = "SELL  +" .. tostring(rarity.sell) .. " COINS"
        keepButton.Visible = true
        sellButton.Visible = true
        sfx("levelup", 0.5)
    end

    local targetX = center - selectedX + rng:NextNumber(-12, 12)
    if animate then
        local tween = TweenService:Create(strip,
            TweenInfo.new(5.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Position = UDim2.fromOffset(targetX, 0) })
        tween:Play()
        tween.Completed:Once(function()
            if token == activeRoulette then reveal() end
        end)
    else
        strip.Position = UDim2.fromOffset(targetX, 0)
        reveal()
    end
end

local function renderUpgrades()
	header("PERMANENT UPGRADES  -  from chests")
	for _, id in Meta.Order do
		local st = Meta.Stats[id]
		local lv = S.up[id] or 0
		local r = row(56)
		text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.6, 0, 0, 22), Text = st.name, TextXAlignment = LEFT, TextColor3 = st.color, ZIndex = 13 }, r)
		text({ Position = UDim2.new(0.6, 0, 0, 4), Size = UDim2.new(0.4, -12, 0, 22), Text = "Lv " .. lv .. " / " .. Meta.MaxLevel, TextXAlignment = RIGHT, ZIndex = 13 }, r)
		text({ Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 16), Text = st.text, TextXAlignment = LEFT, TextSize = 13, TextColor3 = DIM, ZIndex = 13 }, r)
		local back = new("Frame", { Position = UDim2.new(0, 12, 1, -9), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = BG, BorderSizePixel = 0, ZIndex = 13 }, r)
		new("Frame", { Size = UDim2.new(lv / Meta.MaxLevel, 0, 1, 0), BackgroundColor3 = st.color, BorderSizePixel = 0, ZIndex = 14 }, back)
	end
end

local function hm(secs)
	secs = math.max(0, math.floor(secs or 0))
	return string.format("%dh %02dm", secs // 3600, secs % 3600 // 60)
end

local function goalRow(g, sub)
	local r = row(58)
	text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.66, 0, 0, 22), Text = g.name, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 15, TextColor3 = g.done and Color3.fromRGB(120, 230, 150) or TXT, ZIndex = 13 }, r)
	text({
		Position = UDim2.new(0.66, 0, 0, 4), Size = UDim2.new(0.34, -12, 0, 22), TextXAlignment = RIGHT, TextSize = 14, ZIndex = 13,
		Text = g.done and "DONE" or (g.value .. " / " .. g.target), TextColor3 = g.done and Color3.fromRGB(120, 230, 150) or DIM,
	}, r)
	text({ Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 16), Text = sub, TextXAlignment = LEFT, TextSize = 13, TextColor3 = DIM, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13 }, r)
	local back = new("Frame", { Position = UDim2.new(0, 12, 1, -9), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = BG, BorderSizePixel = 0, ZIndex = 13 }, r)
	new("Frame", { Size = UDim2.new(math.clamp(g.value / math.max(1, g.target), 0, 1), 0, 1, 0), BackgroundColor3 = g.done and Color3.fromRGB(120, 230, 150) or Color3.fromRGB(255, 215, 90), BorderSizePixel = 0, ZIndex = 14 }, back)
end

local function renderGoals()
	header("DAILY CHALLENGES  -  resets in " .. hm(S.dailyReset))
	for _, c in S.daily or {} do
		goalRow(c, "Reward: +" .. c.coins .. " coins")
	end
	header("ACHIEVEMENTS")
	for _, a in S.ach or {} do
		goalRow(a, a.desc .. "   (+" .. a.coins .. " coins)")
	end
end


local function renderSupport()
    header("SUPPORT THE CREATOR")
    local intro = row(83)
    text({
        Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -28, 1, -18),
        Text = "Enjoy Survivors 2D? Support development and unlock permanent cosmetic rewards.",
        TextWrapped = true, TextSize = TOUCH and 13 or 15,
        TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = TXT, ZIndex = 13,
    }, intro)

    for _, product in ipairs(SupportProducts) do
        local r = row(83)
        local titleLabel = text({
            Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.56, -15, 0, 31),
            Text = product.title .. "  •  " .. tostring(product.robux) .. " R$",
            TextSize = TOUCH and 13 or 16, TextXAlignment = LEFT,
            TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 13,
        }, r)
        local perkLabel = text({
            Position = UDim2.fromOffset(12, 40), Size = UDim2.new(0.56, -15, 0, 37),
            Text = product.perk or "Permanent Supporter title",
            TextWrapped = true, TextSize = TOUCH and 11 or 13,
            TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
            TextColor3 = DIM, ZIndex = 13,
        }, r)
        local ready = type(product.id) == "number" and product.id > 0
        button({
            Text = ready and ("SUPPORT " .. tostring(product.robux) .. " R$") or "NOT SET UP",
            Size = UDim2.new(0.4, -12, 0, 43),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            TextSize = TOUCH and 12 or 14,
            BackgroundColor3 = ready and Color3.fromRGB(70, 175, 115) or Color3.fromRGB(85, 90, 108),
            ZIndex = 13,
        }, r, function()
            if not ready then return end
            if not (player:GetAttribute("HasJoined") ~= true
                or (player:GetAttribute("Alive") == false and player:GetAttribute("HasDied") == true)) then
                return
            end
            local ok, err = pcall(function()
                MarketplaceService:PromptProductPurchase(player, product.id)
            end)
            if not ok then
                warn("[Survivors Support] Could not open purchase dialog: " .. tostring(err))
            end
        end)
    end
end

local function renderSettings()
    header("AUDIO SETTINGS")
    local intro = row(57)
    text({
        Position = UDim2.fromOffset(14, 3), Size = UDim2.new(1, -28, 1, -6),
        Text = "Choose how loud music and game sound effects should be. Changes apply instantly.",
        TextSize = 14, TextWrapped = true, TextXAlignment = LEFT,
        TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 13,
    }, intro)

    local function volumeRow(kind, description)
        local r = row(102)
        text({
            Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.6, 0, 0, 23),
            Text = kind:upper(), TextSize = 17, TextXAlignment = LEFT,
            TextColor3 = ACC, ZIndex = 13,
        }, r)
        local percent = text({
            Position = UDim2.new(0.6, 0, 0, 8), Size = UDim2.new(0.4, -14, 0, 23),
            Text = "", TextSize = 16, TextXAlignment = RIGHT, ZIndex = 13,
        }, r)
        local minus = button({
            Position = UDim2.fromOffset(12, 39), Size = UDim2.fromOffset(42, 42),
            Text = "−", TextSize = 25, BackgroundColor3 = BG, ZIndex = 13,
        }, r, function() end)
        local plus = button({
            Position = UDim2.new(1, -54, 0, 39), Size = UDim2.fromOffset(42, 42),
            Text = "+", TextSize = 23, BackgroundColor3 = BG, ZIndex = 13,
        }, r, function() end)
        local track = new("TextButton", {
            Text = "", Position = UDim2.fromOffset(66, 56),
            Size = UDim2.new(1, -132, 0, 14), BackgroundColor3 = BG,
            AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 13,
        }, r)
        round(track, 7)
        local fill = new("Frame", {
            Size = UDim2.fromScale(AudioSettings.get(kind), 1), BackgroundColor3 = ACC,
            BorderSizePixel = 0, ZIndex = 14,
        }, track)
        round(fill, 7)
        local knob = new("Frame", {
            Size = UDim2.fromOffset(23, 23), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(AudioSettings.get(kind), 0.5),
            BackgroundColor3 = Color3.fromRGB(245, 247, 255),
            BorderSizePixel = 0, ZIndex = 15,
        }, track)
        round(knob, 12)
        local function set(value)
            AudioSettings.set(kind, math.clamp(value, 0, 1))
            local actual = AudioSettings.get(kind)
            percent.Text = tostring(math.floor(actual * 100 + 0.5)) .. "%"
            fill.Size = UDim2.fromScale(actual, 1)
            knob.Position = UDim2.fromScale(actual, 0.5)
        end
        local function positionToValue(x)
            return (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
        end
        minus.Activated:Connect(function() set(AudioSettings.get(kind) - 0.1) end)
        plus.Activated:Connect(function() set(AudioSettings.get(kind) + 0.1) end)
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                set(positionToValue(input.Position.X))
            end
        end)
        track.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                set(positionToValue(input.Position.X))
            elseif input.UserInputType == Enum.UserInputType.Touch then
                set(positionToValue(input.Position.X))
            end
        end)
        set(AudioSettings.get(kind))
        local desc = row(31)
        desc.BackgroundTransparency = 1
        text({
            Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0),
            Text = description, TextSize = 12, TextColor3 = DIM,
            TextXAlignment = LEFT, TextWrapped = true, ZIndex = 13,
        }, desc)
    end

    volumeRow("Music", "Playlist songs – 0% mutes only background music.")
    volumeRow("FX", "Combat hits, menu clicks, chests, upgrades and alerts.")
end

local tabButtons = {}
for _, name in { "Leaderboard", "Chests", "Upgrades", "Goals", "Support", "Settings" } do
	tabButtons[name] = button({ Text = name, Size = UDim2.fromOffset(117, 40), BackgroundColor3 = PANEL, TextSize = TOUCH and 15 or 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12 }, tabsFrame, function()
		tab = name
		sfx("click", 0.3)
		render()
	end)
end

function render()
	if not S then
		return
	end
	menuBtn.Text = (S.chests > 0 or S.pending) and "MENU !" or "MENU"
	if not panel.Visible then
		return
	end
	for name, b in tabButtons do
		b.BackgroundColor3 = name == tab and ACC or PANEL
	end
	for _, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	order = 0
	local cr = row(26)
	cr.BackgroundTransparency = 1
	text({ Size = UDim2.fromScale(1, 1), Text = "Coins: " .. S.coins, TextColor3 = Color3.fromRGB(255, 215, 90), TextSize = 15, TextXAlignment = RIGHT, ZIndex = 13 }, cr)
	if tab == "Leaderboard" then
		renderBoard()
	elseif tab == "Chests" then
		renderChests()
	elseif tab == "Goals" then
		renderGoals()
	elseif tab == "Support" then
		renderSupport()
	elseif tab == "Settings" then
		renderSettings()
	else
		renderUpgrades()
	end
end

local function isLobby()
	return player:GetAttribute("HasJoined") ~= true
end

local function canOpenMenu()
	return isLobby() or (player:GetAttribute("Alive") == false and player:GetAttribute("HasDied") == true)
end

local function showMenu(open)
	panel.Visible = open
	shade.Visible = open
	if open then
		if S and S.pending then tab = "Chests" end
		if S then render() end
		task.spawn(act, "state")
	end
end

local closeBtn = button({ Text = "X", Size = UDim2.fromOffset(48, 42), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), BackgroundColor3 = Color3.fromRGB(184, 52, 73), ZIndex = 12 }, panel, function()
	if not isLobby() then
		showMenu(false)
	end
end)

-- Declare before creating the button: Luau initializer callbacks otherwise capture a global nil.
local joinBtn
joinBtn = button({
	Text = "JOIN", Size = TOUCH and UDim2.fromOffset(150, 52) or UDim2.fromOffset(172, 54),
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -14),
	BackgroundColor3 = Color3.fromRGB(55, 185, 107), TextSize = 23, ZIndex = 12,
}, panel, function()
	if isLobby() then
		joinBtn.Text = "JOINING..."
		joinBtn.Active = false
		joinRemote:FireServer()
	else
		-- After death, the server controls revive / next-run timing.
		showMenu(false)
	end
end)

local function syncMenuAccess()
	local lobby = isLobby()
	local allowed = canOpenMenu()
	menuBtn.Visible = not lobby and allowed
	closeBtn.Visible = not lobby
	joinBtn.Text = lobby and "JOIN" or "BACK"
	joinBtn.Active = true
	-- No countdown can close the lobby: only explicit JOIN acknowledgement.
	if lobby then
		if not panel.Visible or not shade.Visible then showMenu(true) end
	elseif not allowed then
		showMenu(false)
	else
		-- Return to the original death / THE HORDE WINS view until MENU is clicked.
		if player:GetAttribute("HasDied") == true and player:GetAttribute("Alive") == false then
			-- Do not auto-open on death.
		end
	end
end

local function toggle()
	if not canOpenMenu() then
		showMenu(false)
		return
	end
	if isLobby() then
		showMenu(true)
	else
		showMenu(not panel.Visible)
	end
end

menuBtn.Activated:Connect(toggle)
player:GetAttributeChangedSignal("Alive"):Connect(syncMenuAccess)
player:GetAttributeChangedSignal("HasDied"):Connect(syncMenuAccess)
player:GetAttributeChangedSignal("HasJoined"):Connect(syncMenuAccess)
syncMenuAccess()
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		toggle()
	end
end)

-- pranešimai: pasiekimai / dienos iššūkiai / pasiimta skrynia
local toastLabel = text({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(420, 36),
	BackgroundTransparency = 0.2, BackgroundColor3 = PANEL, TextSize = 15, TextWrapped = true, Visible = false, ZIndex = 40,
}, gui)
round(toastLabel, 8)
local toastId = 0
local function toast(msg, color)
	toastId += 1
	local my = toastId
	toastLabel.Text = msg
	toastLabel.TextColor3 = color or Color3.fromRGB(255, 215, 90)
	toastLabel.Visible = true
	task.delay(4, function()
		if toastId == my then
			toastLabel.Visible = false
		end
	end)
end

player:GetAttributeChangedSignal("Toast"):Connect(function()
	local msg = string.match(tostring(player:GetAttribute("Toast") or ""), "^%d+|(.+)$")
	if msg then
		toast(msg)
		sfx("levelup", 0.5)
		task.spawn(act, "state")
	end
end)

player:GetAttributeChangedSignal("ChestPickup"):Connect(function()
	toast("CHEST COLLECTED!  Open it in MENU > Chests", Color3.fromRGB(255, 215, 90))
	task.spawn(act, "state")
end)

-- periodinis atnaujinimas (kad mygtukas rodytų "!", kai gauta skrynia)
task.spawn(function()
	while true do
		act("state")
		task.wait(panel.Visible and 5 or 15)
	end
end)
