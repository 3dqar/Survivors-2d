-- HUD: gyvybės, XP, laikas, ginklų sąrašas, patobulinimų kortelės, pranešimai, žaidimo pabaiga.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Defs = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Weapons"))
local Config = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("SurvivorsRemotes")
local fxRemote = remotes:WaitForChild("Fx")
local offerRemote = remotes:WaitForChild("Offer")
local pickRemote = remotes:WaitForChild("Pick")
local readyRemote = remotes:WaitForChild("Ready")

task.spawn(function()
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- Pagalbinės funkcijos
---------------------------------------------------------------------
local WHITE = Color3.fromRGB(240, 242, 255)
local GOLD = Color3.fromRGB(255, 214, 90)
local PANEL = Color3.fromRGB(22, 24, 38)

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, thickness)
	return make("UIStroke", { Color = color, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or WHITE
	return make("TextLabel", props, parent)
end

local gui = make("ScreenGui", {
	Name = "SurvivorsHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
}, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------------
-- Raudonas žalos blyksnis
---------------------------------------------------------------------
local hurt = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 30, 40),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
}, gui)

player:GetAttributeChangedSignal("HurtCount"):Connect(function()
	hurt.BackgroundTransparency = 0.72
	TweenService:Create(hurt, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end)

---------------------------------------------------------------------
-- Viršus: laikas ir nužudymai
---------------------------------------------------------------------
local timerLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(200, 40),
	Text = "00:00", Font = Enum.Font.GothamBlack, TextSize = 34, TextStrokeTransparency = 0.5, ZIndex = 3,
}, gui)
local killsLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(200, 22),
	Text = "Kills 0", TextSize = 16, TextColor3 = Color3.fromRGB(190, 195, 225), TextStrokeTransparency = 0.6, ZIndex = 3,
}, gui)

---------------------------------------------------------------------
-- Apačia: HP ir XP juostos
---------------------------------------------------------------------
local bars = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0.55, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 3,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(560, 56), MinSize = Vector2.new(240, 56) }, bars)

local hpBack = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = PANEL, BorderSizePixel = 0, ZIndex = 3 }, bars)
corner(hpBack, 8)
stroke(hpBack, Color3.fromRGB(60, 64, 96), 2)
local hpFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(235, 75, 85), BorderSizePixel = 0, ZIndex = 4 }, hpBack)
corner(hpFill, 8)
local hpText = label({ Size = UDim2.fromScale(1, 1), Text = "100 / 100", TextSize = 16, TextStrokeTransparency = 0.6, ZIndex = 5 }, hpBack)

local xpBack = make("Frame", { Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = PANEL, BorderSizePixel = 0, ZIndex = 3 }, bars)
corner(xpBack, 8)
stroke(xpBack, Color3.fromRGB(60, 64, 96), 2)
local xpFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 170, 255), BorderSizePixel = 0, ZIndex = 4 }, xpBack)
corner(xpFill, 8)
local levelText = label({ Size = UDim2.fromScale(1, 1), Text = "LV 1", TextSize = 13, TextStrokeTransparency = 0.6, ZIndex = 5 }, xpBack)

---------------------------------------------------------------------
-- Kairė: ginklai ir pasyvai
---------------------------------------------------------------------
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3,
}, gui)
corner(panel, 10)
make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, panel)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, panel)

local function rebuildPanel()
	for _, child in panel:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local order = 0
	local function add(text, color, size)
		order += 1
		label({
			Size = UDim2.new(1, 0, 0, size + 4), Text = text, TextSize = size, TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 4,
		}, panel)
	end
	local any = false
	for id, lv in string.gmatch(player:GetAttribute("Weapons") or "", "(%a+):(%d+)") do
		local d = Defs.Weapons[id]
		if d then
			any = true
			add(string.format("%s   Lv %d", d.name, tonumber(lv)), d.color, 15)
		end
	end
	local firstPassive = true
	for id, lv in string.gmatch(player:GetAttribute("Passives") or "", "(%a+):(%d+)") do
		local d = Defs.Passives[id]
		if d then
			if firstPassive and any then
				add("", WHITE, 4)
			end
			firstPassive = false
			any = true
			add(string.format("%s   Lv %d", d.name, tonumber(lv)), Color3.fromRGB(190, 195, 225), 13)
		end
	end
	panel.Visible = any
end
player:GetAttributeChangedSignal("Weapons"):Connect(rebuildPanel)
player:GetAttributeChangedSignal("Passives"):Connect(rebuildPanel)
rebuildPanel()

---------------------------------------------------------------------
-- Pranešimai
---------------------------------------------------------------------
local banner = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 0), Size = UDim2.fromOffset(700, 50),
	Text = "", Font = Enum.Font.GothamBlack, TextSize = 36, TextColor3 = GOLD, TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 6,
}, gui)

local bannerToken = 0
local function showBanner(text)
	bannerToken += 1
	local mine = bannerToken
	banner.Text = text
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	task.delay(2.2, function()
		if mine == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

fxRemote.OnClientEvent:Connect(function(batch)
	for _, f in batch do
		if f[1] == "m" then
			showBanner(f[2])
		end
	end
end)

local reviveLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(700, 60),
	Text = "", Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = Color3.fromRGB(255, 120, 130),
	TextStrokeTransparency = 0.4, Visible = false, ZIndex = 6,
}, gui)

---------------------------------------------------------------------
-- Žaidimo pabaiga
---------------------------------------------------------------------
local over = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 14), BackgroundTransparency = 0.25,
	Visible = false, ZIndex = 20, Active = true,
}, gui)
label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(700, 80),
	Text = "THE HORDE WINS", Font = Enum.Font.GothamBlack, TextSize = 54, TextColor3 = Color3.fromRGB(255, 90, 100), ZIndex = 21,
}, over)
local overStats = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(700, 80),
	Text = "", TextSize = 26, ZIndex = 21,
}, over)
local overTimer = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(700, 40),
	Text = "", TextSize = 20, TextColor3 = Color3.fromRGB(190, 195, 225), ZIndex = 21,
}, over)

local function fmtTime(s)
	s = math.floor(s)
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

---------------------------------------------------------------------
-- Patobulinimų kortelės
---------------------------------------------------------------------
local offerGui = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
	Visible = false, ZIndex = 30, Active = true,
}, gui)
local offerTitle = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.new(0.9, 0, 0, 50),
	Text = "", Font = Enum.Font.GothamBlack, TextSize = 36, TextScaled = true, TextColor3 = GOLD, ZIndex = 31,
}, offerGui)
make("UITextSizeConstraint", { MaxTextSize = 36, MinTextSize = 16 }, offerTitle)
local cardsHolder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.96, 0, 0.5, 0),
	BackgroundTransparency = 1, ZIndex = 31,
}, offerGui)
make("UISizeConstraint", { MinSize = Vector2.new(0, 170), MaxSize = Vector2.new(2000, 230) }, cardsHolder)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder,
}, cardsHolder)
local timerBack = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromOffset(360, 8),
	BackgroundColor3 = PANEL, BorderSizePixel = 0, ZIndex = 31,
}, offerGui)
corner(timerBack, 4)
local timerFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 32 }, timerBack)
corner(timerFill, 4)
local hint = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromOffset(500, 24),
	Text = "Click a card or press 1-4", TextSize = 15, TextColor3 = Color3.fromRGB(190, 195, 225), ZIndex = 31,
}, offerGui)

local currentOffer
local cards = {}
local timerTween

local function hideOffer()
	offerGui.Visible = false
	currentOffer = nil
	if timerTween then
		timerTween:Cancel()
		timerTween = nil
	end
end

local function choose(index)
	if not currentOffer then
		return
	end
	local option = currentOffer.options[index]
	if not option then
		return
	end
	pickRemote:FireServer(currentOffer.id, option.id)
	hideOffer()
end

local function showOffer(data)
	for _, c in cards do
		c:Destroy()
	end
	cards = {}
	currentOffer = data
	offerTitle.Text = data.title
	local touch = UserInputService.TouchEnabled
	hint.Text = touch and "Tap a card" or ("Click a card or press 1-" .. #data.options)

	for i, option in data.options do
		local card = make("TextButton", {
			Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(28, 30, 48), BorderSizePixel = 0,
			Size = UDim2.new(0.23, 0, 1, 0), LayoutOrder = i, ZIndex = 32,
		}, cardsHolder)
		make("UISizeConstraint", { MaxSize = Vector2.new(230, 230) }, card)
		corner(card, 12)
		stroke(card, option.color, 2.5)
		label({
			Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -64, 0, 18), Text = option.tag, TextSize = 12,
			TextColor3 = option.color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33,
		}, card)
		label({
			Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -24, 0, 56), Text = option.name, Font = Enum.Font.GothamBlack,
			TextSize = 22, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33,
		}, card)
		label({
			Position = UDim2.new(0, 12, 0, 94), Size = UDim2.new(1, -24, 1, -122), Text = option.text, Font = Enum.Font.Gotham,
			TextSize = touch and 13 or 15, TextWrapped = true, TextColor3 = Color3.fromRGB(200, 205, 230),
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33,
		}, card)
		label({
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -8), Size = UDim2.fromOffset(40, 20),
			Text = "[" .. i .. "]", TextSize = 14, TextColor3 = Color3.fromRGB(150, 155, 190), ZIndex = 33,
		}, card)
		-- ikona: Config.Icons[<id>] = "rbxassetid://..." arba spalvotas ženkliukas su raidėmis
		local key = string.match(option.id, ":(%w+)$")
		local iconId = key and Config.Icons[key]
		if iconId and iconId ~= "" then
			make("ImageLabel", {
				Image = iconId, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(40, 40), ZIndex = 33,
			}, card)
		else
			local mono = ""
			for w in string.gmatch(option.name, "%a+") do
				mono ..= string.upper(string.sub(w, 1, 1))
				if #mono == 2 then
					break
				end
			end
			local badge = make("Frame", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = option.color, BorderSizePixel = 0, ZIndex = 33,
			}, card)
			corner(badge, 20)
			label({ Size = UDim2.fromScale(1, 1), Text = mono, TextSize = 17, TextColor3 = Color3.fromRGB(20, 22, 34), ZIndex = 34 }, badge)
		end
		card.Activated:Connect(function()
			choose(i)
		end)
		cards[#cards + 1] = card
	end

	timerFill.Size = UDim2.fromScale(1, 1)
	if timerTween then
		timerTween:Cancel()
	end
	timerTween = TweenService:Create(timerFill, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
	timerTween:Play()
	offerGui.Visible = true

	local mine = data
	task.delay(data.seconds + 0.2, function()
		if currentOffer == mine then
			hideOffer()
		end
	end)
end

offerRemote.OnClientEvent:Connect(showOffer)

local keyMap = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentOffer then
		return
	end
	local index = keyMap[input.KeyCode]
	if index then
		choose(index)
	end
end)

---------------------------------------------------------------------
-- Kasdienis atnaujinimas
---------------------------------------------------------------------
local hpRatio, xpRatio = 1, 0

RunService.RenderStepped:Connect(function(dt)
	local smooth = math.min(1, dt * 12)

	local hp = player:GetAttribute("HP") or 0
	local maxHp = math.max(1, player:GetAttribute("MaxHP") or 100)
	hpRatio += (hp / maxHp - hpRatio) * smooth
	hpFill.Size = UDim2.new(math.clamp(hpRatio, 0, 1), 0, 1, 0)
	hpText.Text = string.format("%d / %d", hp, maxHp)

	local xp = player:GetAttribute("XP") or 0
	local need = math.max(1, player:GetAttribute("XPNeed") or 10)
	xpRatio += (xp / need - xpRatio) * smooth
	xpFill.Size = UDim2.new(math.clamp(xpRatio, 0, 1), 0, 1, 0)
	levelText.Text = "LV " .. (player:GetAttribute("Level") or 1)

	timerLabel.Text = fmtTime(workspace:GetAttribute("RunTime") or 0)
	killsLabel.Text = "Kills " .. (player:GetAttribute("Kills") or 0)

	local alive = player:GetAttribute("Alive")
	local state = workspace:GetAttribute("RunState")
	if state == "Playing" and alive == false then
		local seconds = player:GetAttribute("ReviveIn") or 0
		reviveLabel.Visible = true
		reviveLabel.Text = seconds > 0 and ("YOU FELL  -  REVIVING IN " .. seconds) or "WAITING FOR A TEAMMATE..."
	else
		reviveLabel.Visible = false
	end

	if state == "GameOver" then
		over.Visible = true
		overStats.Text = string.format(
			"Survived %s   -   Team kills %d\nYour kills %d",
			fmtTime(workspace:GetAttribute("ResultTime") or 0),
			workspace:GetAttribute("ResultKills") or 0,
			player:GetAttribute("Kills") or 0
		)
		local left = math.max(0, math.ceil((workspace:GetAttribute("RestartAt") or 0) - workspace:GetServerTimeNow()))
		overTimer.Text = "New run in " .. left
		if currentOffer then
			hideOffer()
		end
	else
		over.Visible = false
	end
end)

readyRemote:FireServer()
