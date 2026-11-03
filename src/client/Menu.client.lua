-- StarterPlayer/StarterPlayerScripts/Menu_client  (LocalScript)
-- Meniu tik po mirties (MENU arba M): Leaderboard / Chests / Upgrades / Goals (pasiekimai + dienos iššūkiai).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("SurvivorsShared")
local Meta = require(Shared:WaitForChild("Meta"))
local Config = require(Shared:WaitForChild("Config"))
local SupportProducts = require(Shared:WaitForChild("SupportProducts"))
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
	Text = "MENU", Size = TOUCH and UDim2.fromOffset(156, 48) or UDim2.fromOffset(160, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
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
local tabsFrame = new("Frame", { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 42), BackgroundTransparency = 1, ZIndex = 11 }, panel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabsFrame)

local content = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 116), Size = UDim2.new(1, -28, 1, -190), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 11,
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)

local S, tab, busy = nil, "Leaderboard", false
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
		if action == "open" and res.ok then
			sfx("chest", 0.7)
		elseif action ~= "state" then
			sfx("click", 0.4)
		end
		render()
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
	local r = row(70)
	text({
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -250, 1, 0), TextXAlignment = LEFT, TextWrapped = true, TextSize = 15, ZIndex = 13,
		Text = "Chests: " .. S.chests .. "\nA boss gives everyone one chest. Chests give permanent upgrades.",
	}, r)
	button({ Text = "OPEN", Size = UDim2.fromOffset(100, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -128, 0.5, 0), ZIndex = 13 }, r, function()
		act("open")
	end)
	button({
		Text = "BUY " .. S.price, Size = UDim2.fromOffset(110, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(240, 190, 70), TextColor3 = Color3.fromRGB(30, 25, 10), ZIndex = 13,
	}, r, function()
		act("buy")
	end)
	if S.msg then
		local m = row(30)
		text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Text = S.msg, TextXAlignment = LEFT, TextSize = 15, TextColor3 = S.ok and Color3.fromRGB(120, 230, 150) or Color3.fromRGB(255, 130, 130), ZIndex = 13 }, m)
	end
	if S.pending then
		local p = S.pending
		local st, rar = Meta.Stats[p.stat], Meta.Rarities[p.r]
		local lv = S.up[p.stat] or 0
		local c = row(130)
		text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), Text = rar.name:upper() .. "  -  " .. st.name, TextXAlignment = LEFT, TextColor3 = rar.color, TextSize = 22, Font = Enum.Font.GothamBlack, ZIndex = 13 }, c)
		text({
			Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 40), TextXAlignment = LEFT, TextWrapped = true, TextSize = 14, TextColor3 = DIM, ZIndex = 13,
			Text = string.format("%s\n+%d level  (now Lv %d / %d)", st.text, rar.lv, lv, Meta.MaxLevel),
		}, c)
		button({ Text = "KEEP", Size = UDim2.fromOffset(140, 38), Position = UDim2.new(0, 12, 1, -48), BackgroundColor3 = Color3.fromRGB(70, 190, 110), ZIndex = 13 }, c, function()
			act("keep")
		end)
		button({ Text = "SELL +" .. rar.sell, Size = UDim2.fromOffset(150, 38), Position = UDim2.new(0, 164, 1, -48), BackgroundColor3 = Color3.fromRGB(240, 190, 70), TextColor3 = Color3.fromRGB(30, 25, 10), ZIndex = 13 }, c, function()
			act("sell")
		end)
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
    local intro = row(62)
    text({ Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 1, -10),
        Text = "Support Survivors 2D and unlock a permanent cosmetic title!\\n50: yellow tag  |  100: RGB tag  |  1000: RGB tag + trail",
        TextWrapped = true, TextSize = 14, TextXAlignment = LEFT, ZIndex = 13 }, intro)
    for _, product in ipairs(SupportProducts) do
        local r = row(64)
        text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.62, -20, 1, -8),
            Text = product.title .. "  -  " .. tostring(product.robux) .. " Robux\\n" .. (product.perk or ""),
            TextSize = 15, TextXAlignment = LEFT, TextWrapped = true, ZIndex = 13 }, r)
        local ready = type(product.id) == "number" and product.id > 0
        button({ Text = ready and ("SUPPORT  " .. tostring(product.robux) .. " R$") or "NOT SET UP",
            Size = UDim2.new(0.37, -12, 0, 42), AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0), TextSize = TOUCH and 13 or 14,
            BackgroundColor3 = ready and Color3.fromRGB(70, 175, 115) or Color3.fromRGB(85, 90, 108), ZIndex = 13 }, r, function()
            if not ready then
                return
            end
            if not (player:GetAttribute("HasJoined") ~= true or (player:GetAttribute("Alive") == false and player:GetAttribute("HasDied") == true)) then
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
    if not (SupportProducts[1].id > 0 and SupportProducts[2].id > 0 and SupportProducts[3].id > 0) then
        local r = row(44)
        text({ Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
            Text = "Creator setup needed: set three Developer Product IDs in SupportProducts.lua.",
            TextWrapped = true, TextSize = 12, TextXAlignment = LEFT, TextColor3 = DIM, ZIndex = 13 }, r)
    end
end

local tabButtons = {}
for _, name in { "Leaderboard", "Chests", "Upgrades", "Goals", "Support" } do
	tabButtons[name] = button({ Text = name, Size = UDim2.new(0.2, -5, 1, 0), BackgroundColor3 = PANEL, TextSize = TOUCH and 15 or 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12 }, tabsFrame, function()
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
