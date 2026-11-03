-- Survivors: serverio logika (priešai, ginklai, XP, patobulinimai, bangos, pralaimėjimas/restartas).
-- Visa simuliacija vyksta serveryje fiksuotu žingsniu; klientas tik rodo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("SurvivorsShared")
local Config = require(Shared:WaitForChild("Config"))
local Defs = require(Shared:WaitForChild("Weapons"))
local Grid = require(script.Parent:WaitForChild("Grid"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Persistence = require(script.Parent:WaitForChild("Persistence"))

workspace:WaitForChild("SurvivorsArena")

---------------------------------------------------------------------
-- Remote'ai
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "SurvivorsRemotes"
remotes.Parent = ReplicatedStorage

local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local fxRemote = newRemote("Fx")        -- serveris -> klientai: efektai
local offerRemote = newRemote("Offer")  -- serveris -> klientas: patobulinimų pasirinkimas
local pickRemote = newRemote("Pick")    -- klientas -> serveris: pasirinkimas
local readyRemote = newRemote("Ready")  -- klientas -> serveris: UI paruoštas
local joinRemote = newRemote("Join")  -- klientas -> serveris: JOIN pagrindiniame meniu
local playAgainRemote = newRemote("PlayAgain") -- client -> server: manual restart after team wipe
Fx.init(fxRemote)

local enemyFolder = Instance.new("Folder")
enemyFolder.Name = "Enemies"
enemyFolder.Parent = workspace
local projFolder = Instance.new("Folder")
projFolder.Name = "Projectiles"
projFolder.Parent = workspace

---------------------------------------------------------------------
-- Būsena
---------------------------------------------------------------------
local rng = Random.new()
local half = Config.ArenaSize / 2 - 4
local enemies = {}
local projectiles = {}
local eprojs = {}   -- priešų šūviai
local strikes = {}  -- meteorai / pavojaus zonos
local grid = Grid.new()
local drops = {}  -- nukritusios skrynios
local perf = 1    -- našumo koeficientas (mažina priešų limitą, jei serveris lėtėja)
local stats = {} -- [Player] = žaidėjo būsena
local run = {}

local killPlayer, spawnPlayer, revivePlayer, checkGameOver, restartRun, spawnEnemy

local function resetRun()
	run.state = "Playing"
	run.time = 0
	run.kills = 0
	run.nextBoss = Config.BossEvery
	run.nextSwarm = Config.SwarmEvery
	run.spawnAcc = 0
	run.restartAt = 0
	run.event, run.eventLeft = nil, 0
	run.nextEvent = Config.EventFirst
	run.nextStrike = 0
	run.nextElite = Config.EliteFirst
	run.pcount = 1
	run.xpEvent, run.speedEvent, run.spawnEvent = 1, 1, 1
	workspace:SetAttribute("Event", "")
end
resetRun()
workspace:SetAttribute("RunState", "Playing")
workspace:SetAttribute("RunTime", 0)

local function getRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function resetStats(st)
	st.weapons = {}
	st.passives = {}
	st.timers = {}
	st.hero = nil
	st.level = 1
	st.xp = 0
	st.kills = 0
	st.pending = 0
	st.offer = nil
	st.offerTitle = ""
	st.offerExpires = 0
	st.maxHp = Config.BasePlayerHP
	st.hp = st.maxHp
	st.regen = 0
	st.dmgMult = 1
	st.cdMult = 1
	st.speedMult = 1
	st.xpMult = 1
	st.crit = Config.CritChance
	st.iframe = 0
	st.alive = false
	st.spawning = false
	st.reviveAt = 0
	st.waitingReward = false
end

local function newStats(player)
	local st = { player = player }
	resetStats(st)
	return st
end

local function recalc(st)
	local p = st.passives
	local b = Persistence.bonus(st.player)
	local h = st.hero and Config.Heroes[st.hero] or {}
	st.dmgMult = (1 + Defs.Passives.Might.per * (p.Might or 0)) * (1 + b.dmg + (h.dmg or 0))
	st.cdMult = (1 - Defs.Passives.Haste.per) ^ (p.Haste or 0)
	st.speedMult = (1 + Defs.Passives.Boots.per * (p.Boots or 0)) * (1 + b.speed + (h.speed or 0))
	st.regen = Defs.Passives.Recovery.per * (p.Recovery or 0) + b.regen + (h.regen or 0)
	st.xpMult = (1 + Defs.Passives.Wisdom.per * (p.Wisdom or 0)) * (1 + b.xp)
	local newMax = math.max(30, Config.BasePlayerHP + Defs.Passives.Vitality.per * (p.Vitality or 0) + b.hp + (h.hp or 0))
	st.crit = Config.CritChance + b.crit + (h.crit or 0)
	if newMax > st.maxHp then
		st.hp += newMax - st.maxHp
	end
	st.maxHp = newMax
	st.hp = math.min(st.hp, newMax)
end

local function applyMovement(st)
	local char = st.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.BaseWalkSpeed * st.speedMult
	end
end

-- kai užsikrauna / pasikeičia nuolatiniai patobulinimai
Persistence.onLoaded = function(player)
	local st = stats[player]
	if st then
		recalc(st)
		applyMovement(st)
	end
end

local function listString(map, order)
	local out = {}
	for _, id in order do
		local lv = map[id]
		if lv and lv > 0 then
			out[#out + 1] = id .. ":" .. lv
		end
	end
	return table.concat(out, "|")
end

-- Perduoda būseną klientui per atributus (replikuojasi automatiškai).
local function publish(player, st)
	player:SetAttribute("HP", math.ceil(st.hp))
	player:SetAttribute("MaxHP", st.maxHp)
	player:SetAttribute("Level", st.level)
	player:SetAttribute("XP", math.floor(st.xp))
	player:SetAttribute("XPNeed", Config.xpNeeded(st.level))
	player:SetAttribute("Kills", st.kills)
	player:SetAttribute("Alive", st.alive)
	player:SetAttribute("Hero", st.hero or "")
	player:SetAttribute("ReviveIn", st.alive and 0 or math.max(0, math.ceil(st.reviveAt - os.clock())))
	player:SetAttribute("Weapons", listString(st.weapons, Defs.AllWeapons))
	player:SetAttribute("Passives", listString(st.passives, Defs.PassiveOrder))
	local bid = st.weapons.Blades and "Blades" or (st.weapons.Bladestorm and "Bladestorm")
	local blades = bid and st.weapons[bid]
	if blades then
		local L = Defs.Weapons[bid].levels[blades]
		player:SetAttribute("BladeCount", L.count)
		player:SetAttribute("BladeRadius", L.radius)
		player:SetAttribute("BladeSpeed", L.speed)
	else
		player:SetAttribute("BladeCount", 0)
	end
	local aid = st.weapons.Inferno and "Inferno" or (st.weapons.Hellfire and "Hellfire")
	player:SetAttribute("AuraRadius", aid and Defs.Weapons[aid].levels[st.weapons[aid]].radius or 0)
end

---------------------------------------------------------------------
-- Patobulinimų pasiūlymai
---------------------------------------------------------------------
local nextOfferId = 0

local function sendOffer(player, st, title, options)
	nextOfferId += 1
	st.offer = { id = nextOfferId, options = options }
	st.offerTitle = title
	st.offerExpires = os.clock() + Config.OfferSeconds
	offerRemote:FireClient(player, { id = nextOfferId, title = title, seconds = Config.OfferSeconds, options = options })
end

local function sendStartingOffer(player, st)
	local options = {}
	local ids = table.clone(Defs.WeaponOrder)
	for i = #ids, 2, -1 do
		local j = rng:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	-- veikėjo firminis ginklas visada pasiūlomas
	local sig = st.hero and Config.Heroes[st.hero] and Config.Heroes[st.hero].weapon
	if sig then
		local at = table.find(ids, sig)
		if at and at > 4 then
			ids[at], ids[4] = ids[4], ids[at]
		end
	end
	for i = 1, math.min(4, #ids) do
		local d = Defs.Weapons[ids[i]]
		options[i] = { id = "W:" .. ids[i], name = d.name, text = d.notes[1], tag = ids[i] == sig and "SIGNATURE WEAPON" or "WEAPON", color = d.color }
	end
	sendOffer(player, st, "CHOOSE YOUR WEAPON", options)
end

local function sendHeroOffer(player, st)
	-- Returning players reuse their saved hero; the first session still offers a choice.
	local preferred = Persistence.preferredHero(player)
	if preferred and Config.Heroes[preferred] then
		st.hero = preferred
		recalc(st)
		applyMovement(st)
		sendStartingOffer(player, st)
		publish(player, st)
		return
	end
	local options = {}
	for i, id in Config.HeroOrder do
		local h = Config.Heroes[id]
		options[i] = { id = "C:" .. id, name = h.name, text = h.text, tag = "HERO", color = h.color }
	end
	sendOffer(player, st, "CHOOSE YOUR HERO", options)
end

local function buildLevelOptions(st)
	local pool = {}
	for _, id in Defs.WeaponOrder do
		local d, lv = Defs.Weapons[id], st.weapons[id] or 0
		if lv < d.max then
			pool[#pool + 1] = {
				id = "W:" .. id, name = d.name, text = d.notes[lv + 1], color = d.color,
				tag = lv == 0 and "NEW WEAPON" or ("WEAPON  LV " .. (lv + 1)),
			}
		end
	end
	for _, id in Defs.PassiveOrder do
		local d, lv = Defs.Passives[id], st.passives[id] or 0
		if lv < d.max then
			pool[#pool + 1] = {
				id = "P:" .. id, name = d.name, text = d.blurb, color = d.color,
				tag = "PASSIVE  LV " .. (lv + 1),
			}
		end
	end
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for base, ev in Defs.Evolutions do
		if st.weapons[base] == Defs.Weapons[base].max and (st.passives[ev.need] or 0) > 0 then
			local e = Defs.Weapons[ev.to]
			table.insert(pool, 1, { id = "E:" .. base, name = e.name, text = e.notes[1], color = e.color, tag = "EVOLUTION" })
		end
	end
	local options = {}
	for i = 1, math.min(3, #pool) do
		options[i] = pool[i]
	end
	if #options < 3 then
		options[#options + 1] = {
			id = "HEAL", name = "Second Wind", text = "Restore 50% of your HP.",
			tag = "BONUS", color = Color3.fromRGB(110, 230, 140),
		}
	end
	return options
end

local function tryOffer(player, st)
	if st.offer or st.pending <= 0 then
		return
	end
	st.pending -= 1
	sendOffer(player, st, "LEVEL UP!   LV " .. (st.level - st.pending), buildLevelOptions(st))
end

local function applyPick(player, st, optionId)
	if optionId == "HEAL" then
		st.hp = math.min(st.maxHp, st.hp + st.maxHp * 0.5)
	else
		local kind, id = string.match(optionId, "^(%a):(%w+)$")
		if kind == "C" and Config.Heroes[id] and not st.hero then
			st.hero = id
			Persistence.setPreferredHero(player, id)
			recalc(st)
			applyMovement(st)
			st.offer = nil
			sendStartingOffer(player, st)
			publish(player, st)
			return
		elseif kind == "W" and Defs.Weapons[id] then
			local lv = st.weapons[id] or 0
			if lv < Defs.Weapons[id].max then
				st.weapons[id] = lv + 1
				if lv == 0 then
					st.timers[id] = 0.4
				end
			end
		elseif kind == "E" and Defs.Evolutions[id] and st.weapons[id] == Defs.Weapons[id].max then
			local to = Defs.Evolutions[id].to
			st.weapons[id] = nil
			st.timers[id] = nil
			st.weapons[to] = 1
			st.timers[to] = 0.3
			Persistence.progress(player, "evos", 1)
		elseif kind == "P" and Defs.Passives[id] then
			local lv = st.passives[id] or 0
			if lv < Defs.Passives[id].max then
				st.passives[id] = lv + 1
			end
		end
	end
	recalc(st)
	applyMovement(st)
	st.offer = nil
	tryOffer(player, st)
	publish(player, st)
end

pickRemote.OnServerEvent:Connect(function(player, offerId, optionId)
	local st = stats[player]
	if not st or not st.offer then
		return
	end
	if type(offerId) ~= "number" or offerId ~= st.offer.id or type(optionId) ~= "string" then
		return
	end
	for _, o in st.offer.options do
		if o.id == optionId then
			applyPick(player, st, optionId)
			return
		end
	end
end)

readyRemote.OnServerEvent:Connect(function(player)
	local st = stats[player]
	if st and st.offer then
		offerRemote:FireClient(player, {
			id = st.offer.id,
			title = st.offerTitle,
			seconds = math.max(1, st.offerExpires - os.clock()),
			options = st.offer.options,
		})
	end
end)

local function grantXP(player, st, amount)
	local before = st.level
	st.xp += amount * st.xpMult
	local need = Config.xpNeeded(st.level)
	while st.xp >= need do
		st.xp -= need
		st.level += 1
		st.pending += 1
		need = Config.xpNeeded(st.level)
	end
	if st.level > before then
		local root = getRoot(player)
		if root then
			Fx.force({ "u", root.Position.X, 0.3, root.Position.Z })
		end
	end
	tryOffer(player, st)
end

---------------------------------------------------------------------
-- Priešai
---------------------------------------------------------------------
local function destroyDrop(i)
	local d = drops[i]
	d.part:Destroy()
	d.beacon:Destroy()
	drops[i] = drops[#drops]
	drops[#drops] = nil
end

-- skrynia krenta iš dangaus, švyti ir sukasi; pasiima pirmas prisilietęs gyvas žaidėjas
local function dropChest(x, z)
	if #drops >= Config.MaxChestDrops then
		destroyDrop(1)
	end
	local gold = Color3.fromRGB(255, 205, 80)
	local part = Instance.new("Part")
	part.Name = "ChestDrop"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = Vector3.new(2.6, 1.8, 1.8)
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(235, 180, 60)
	part.Position = Vector3.new(x, 45, z)
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 18
	light.Brightness = 2
	light.Parent = part
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(gold)
	sparks.Parent = part
	local beacon = Instance.new("Part")
	beacon.Name = "ChestBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanTouch = false
	beacon.CanQuery = false
	beacon.CastShadow = false
	beacon.Size = Vector3.new(0.6, 70, 0.6)
	beacon.Material = Enum.Material.Neon
	beacon.Color = gold
	beacon.Transparency = 0.55
	beacon.Position = Vector3.new(x, 35, z)
	beacon.Parent = projFolder
	part.Parent = projFolder
	drops[#drops + 1] = { part = part, beacon = beacon, x = x, z = z, y = 45, life = Config.ChestLife, spin = rng:NextNumber(0, 6.28) }
	Fx.force({ "s", "drop", x, z })
end

local function updateDrops(dt, targets)
	if #drops == 0 then
		return
	end
	local now = os.clock()
	local parts, cfs, n = {}, {}, 0
	local r2 = Config.ChestPickupRadius ^ 2
	local i = 1
	while i <= #drops do
		local d = drops[i]
		d.life -= dt
		local remove = d.life <= 0
		if not remove then
			if d.y > 1.4 then
				d.y = math.max(1.4, d.y - 40 * dt)
				if d.y == 1.4 then
					Fx.push({ "p", d.x, 0.4, d.z, 6, 255, 215, 90 })
				end
			else
				for _, t in targets do
					local dx, dz = t.x - d.x, t.z - d.z
					if dx * dx + dz * dz <= r2 then
						Persistence.addChest(t.player, 1)
						t.player:SetAttribute("ChestPickup", (t.player:GetAttribute("ChestPickup") or 0) + 1)
						Fx.push({ "p", d.x, 0.4, d.z, 9, 255, 215, 90 })
						remove = true
						break
					end
				end
			end
		end
		if remove then
			destroyDrop(i)
		else
			local bob = d.y <= 1.4 and math.sin(now * 3 + d.spin) * 0.3 or 0
			n += 1
			parts[n] = d.part
			cfs[n] = CFrame.new(d.x, d.y + bob, d.z) * CFrame.Angles(0, now * 1.5 + d.spin, 0)
			i += 1
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function killEnemy(e, owner)
	e.alive = false
	run.kills += 1
	owner.kills += 1
	e.part:Destroy()
	Fx.push({ "k", e.x, e.y, e.z, e.cr, e.cg, e.cb, e.r })
	if e.split then
		for i = 1, 2 do
			spawnEnemy("Mini", e.x + (i == 1 and -1.5 or 1.5), e.z, run.pcount)
		end
	end
	for player, st in stats do
		if st.alive then
			grantXP(player, st, e.xp * run.xpEvent * (st == owner and 1 or Config.XPShareOthers))
		end
	end
	if e.boss then
		for _, st in stats do
			if st.alive then
				st.hp = math.min(st.maxHp, st.hp + st.maxHp * 0.4)
				Persistence.addChest(st.player, 1)
				Persistence.progress(st.player, "titans", 1)
			end
		end
		Fx.force({ "p", e.x, 0.4, e.z, 34, 255, 150, 70 })
		Fx.force({ "m", "TITAN DEFEATED  -  CHEST EARNED" })
	elseif e.kind ~= "Mini" and rng:NextNumber() < (e.elite and Config.ChestDropElite or Config.ChestDropNormal) then
		dropChest(e.x, e.z)
	end
end

local function hitEnemy(e, dmg, owner, kdx, kdz, kpow)
	if not e.alive then
		return
	end
	local crit = rng:NextNumber() < (owner.crit or Config.CritChance)
	local amount = dmg * owner.dmgMult * (crit and Config.CritMult or 1)
	e.hp -= amount
	if not e.flash then
		e.part.Color = Color3.new(1, 1, 1)
	end
	e.flash = os.clock() + 0.07
	if kpow and kpow > 0 then
		e.kx += kdx * kpow * e.knock
		e.kz += kdz * kpow * e.knock
	end
	Fx.push({ "d", e.x, e.y + e.r, e.z, math.floor(amount + 0.5), crit and 1 or 0 })
	if e.bar then
		e.bar.Size = UDim2.new(math.clamp(e.hp / e.maxHp, 0, 1), 0, 1, 0)
	end
	if e.hp <= 0 then
		killEnemy(e, owner)
	end
end

function spawnEnemy(kind, x, z, playerCount, elite)
	local base = Config.Enemies[kind]
	if elite then
		base = table.clone(base)
		base.size = base.size * Config.EliteSize
		base.hp = base.hp * Config.EliteHpMult
		base.xp = base.xp * 6
		base.dmg = base.dmg * 1.3
		base.color = base.color:Lerp(Color3.fromRGB(255, 215, 80), 0.45)
	end
	local t = run.time
	local hpMult = (1 + t / 130) * (1 + 0.35 * (math.max(1, playerCount) - 1))
	local hp = base.hp * hpMult

	local part = Instance.new("Part")
	part.Name = kind
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Shape = base.shape
	part.Material = base.material
	part.Color = base.color
	part.Size = Vector3.new(base.size, base.size, base.size)
	part.Position = Vector3.new(x, base.size / 2, z)
	if base.mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = base.mesh
		m.Parent = part
	end
	local decos = {}
	for _, d in base.decos or {} do
		local dp = Instance.new("Part")
		dp.Anchored = true
		dp.CanCollide = false
		dp.CanTouch = false
		dp.CanQuery = false
		dp.CastShadow = false
		dp.Shape = d.shape
		dp.Material = d.material
		dp.Color = d.color
		dp.Size = d.size * base.size
		dp.Parent = part
		local pos = d.pos * base.size
		local rot = CFrame.Angles(math.rad(d.rot.X), math.rad(d.rot.Y), math.rad(d.rot.Z))
		decos[#decos + 1] = { part = dp, pos = pos, rot = rot, rel = CFrame.new(pos) * rot, spin = d.spin }
	end
	part.Parent = enemyFolder

	local e = {
		part = part, kind = kind, decos = decos, baseColor = base.color,
		x = x, z = z, y = base.size / 2, r = base.size / 2,
		hp = hp, maxHp = hp,
		speed = base.speed * (1 + math.min(t / 400, 0.6)) * rng:NextNumber(0.9, 1.1),
		dmg = base.dmg * (1 + t / 300),
		xp = base.xp, knock = base.knock, boss = base.boss == true, elite = elite == true,
		cr = math.floor(base.color.R * 255), cg = math.floor(base.color.G * 255), cb = math.floor(base.color.B * 255),
		ai = base.ai, range = base.range, shotCd = base.shotCd, shotSpeed = base.shotSpeed, split = base.split,
			shotDmg = base.shotDmg and base.shotDmg * (1 + t / 300), boom = base.boom,
			boomDmg = base.boomDmg and base.boomDmg * (1 + t / 300), shotT = rng:NextNumber(0.5, 2),
			cd = {}, kx = 0, kz = 0, alive = true, phase = rng:NextNumber(0, 6.28),
	}

	if base.boss or elite then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(base.boss and 240 or 110, base.boss and 16 or 9)
		gui.StudsOffset = Vector3.new(0, base.size / 2 + 3, 0)
		gui.AlwaysOnTop = true
		gui.Parent = part
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		back.BorderSizePixel = 0
		back.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(235, 70, 70)
		fill.BorderSizePixel = 0
		fill.Parent = back
		e.bar = fill
	end

	enemies[#enemies + 1] = e
	return e
end

local function ringPos(target)
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(Config.SpawnRingMin, Config.SpawnRingMax)
		local x, z = target.x + math.cos(a) * r, target.z + math.sin(a) * r
		if math.abs(x) <= half and math.abs(z) <= half then
			return x, z
		end
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = Config.SpawnRingMin
	return math.clamp(target.x + math.cos(a) * r, -half, half), math.clamp(target.z + math.sin(a) * r, -half, half)
end

local function pickKind(t)
	local w = {
		{ "Grunt", 10 },
		{ "Runner", t > 25 and math.min(7, (t - 25) / 8) or 0 },
		{ "Brute", t > 70 and math.min(3.5, (t - 70) / 30) or 0 },
		{ "Bomber", t > 60 and math.min(3, (t - 60) / 40) or 0 },
		{ "Spitter", t > 90 and math.min(2.5, (t - 90) / 50) or 0 },
		{ "Splitter", t > 110 and math.min(2.5, (t - 110) / 50) or 0 },
	}
	local total = 0
	for _, p in w do
		total += p[2]
	end
	local r = rng:NextNumber(0, total)
	for _, p in w do
		r -= p[2]
		if r <= 0 then
			return p[1]
		end
	end
	return "Grunt"
end

local function capFor(count)
	return math.floor(math.min(Config.MaxEnemiesCap, Config.MaxEnemiesBase + Config.MaxEnemiesPerPlayer * count) * perf)
end

local EliteKinds = { "Grunt", "Runner", "Brute", "Spitter", "Splitter" }
local function spawnElite(targets)
	local n = 0
	for _, e in enemies do
		if e.alive and e.elite then
			n += 1
		end
	end
	if n >= Config.MaxElites then
		return
	end
	local x, z = ringPos(targets[rng:NextInteger(1, #targets)])
	spawnEnemy(EliteKinds[rng:NextInteger(1, #EliteKinds)], x, z, #targets, true)
end

local function updateSpawner(dt, targets)
	local t = run.time
	local count = #targets
	run.pcount = count
	local rate = math.min(34, (1.6 + t / 20) * (0.7 + 0.45 * count) * run.spawnEvent)
	run.spawnAcc += rate * dt
	while run.spawnAcc >= 1 do
		run.spawnAcc -= 1
		if #enemies < capFor(count) then
			local x, z = ringPos(targets[rng:NextInteger(1, count)])
			spawnEnemy(pickKind(t), x, z, count)
		end
	end

	if t >= run.nextBoss then
		run.nextBoss += Config.BossEvery
		local x, z = ringPos(targets[rng:NextInteger(1, count)])
		spawnEnemy("Titan", x, z, count)
		Fx.force({ "m", "A TITAN APPROACHES" })
	end

	if t >= run.nextElite then
		run.nextElite += Config.EliteEvery
		for _ = 1, 1 + count // 4 do
			spawnElite(targets)
		end
		Fx.force({ "m", "AN ELITE APPEARS" })
	end

	if t >= run.nextSwarm then
		run.nextSwarm += Config.SwarmEvery
		if #enemies < capFor(count) + 30 then
			local target = targets[rng:NextInteger(1, count)]
			for i = 0, 21 do
				local a = i / 22 * math.pi * 2
				local x = math.clamp(target.x + math.cos(a) * 52, -half, half)
				local z = math.clamp(target.z + math.sin(a) * 52, -half, half)
				spawnEnemy("Runner", x, z, count)
			end
			Fx.force({ "m", "SWARM!" })
		end
	end
end

local function hurtPlayer(player, st, amount)
	if not st.alive or st.iframe > 0 then
		return
	end
	st.hp -= amount
	st.iframe = 0.4
	player:SetAttribute("HurtCount", (player:GetAttribute("HurtCount") or 0) + 1)
	if st.hp <= 0 then
		killPlayer(player, st)
	end
end

local function enemyShot(e, target)
	if #eprojs > 80 then
		return
	end
	local dx, dz = target.x - e.x, target.z - e.z
	local d = math.sqrt(dx * dx + dz * dz) + 1e-4
	local part = Instance.new("Part")
	part.Name = "EnemyShot"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 80, 140)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Position = Vector3.new(e.x, 2.5, e.z)
	part.Parent = projFolder
	eprojs[#eprojs + 1] = { part = part, x = e.x, z = e.z, dx = dx / d, dz = dz / d, speed = e.shotSpeed, dmg = e.shotDmg, life = 3 }
end

local function explodeBomber(e, targets)
	if not e.alive then
		return
	end
	e.alive = false
	e.part:Destroy()
	Fx.force({ "p", e.x, 0.4, e.z, e.boom, 255, 90, 50 })
	for _, t in targets do
		local dx, dz = t.x - e.x, t.z - e.z
		if dx * dx + dz * dz <= e.boom * e.boom then
			hurtPlayer(t.player, t.st, e.boomDmg)
		end
	end
end

local function updateEnemyProjectiles(dt, targets)
	local parts, cfs, n = {}, {}, 0
	local i = 1
	while i <= #eprojs do
		local p = eprojs[i]
		p.x += p.dx * p.speed * dt
		p.z += p.dz * p.speed * dt
		p.life -= dt
		local remove = p.life <= 0 or math.abs(p.x) > half + 10 or math.abs(p.z) > half + 10
		if not remove then
			for _, t in targets do
				local dx, dz = t.x - p.x, t.z - p.z
				if dx * dx + dz * dz < 2.6 then
					hurtPlayer(t.player, t.st, p.dmg)
					remove = true
					break
				end
			end
		end
		if remove then
			p.part:Destroy()
			eprojs[i] = eprojs[#eprojs]
			eprojs[#eprojs] = nil
		else
			n += 1
			parts[n] = p.part
			cfs[n] = CFrame.new(p.x, 2.5, p.z)
			i += 1
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function updateEnemies(dt, targets)
	local parts, cfs, n = {}, {}, 0
	local booms = {}
	local now = os.clock()
	for _, e in enemies do
		if e.alive then
			local best, bd = nil, math.huge
			for _, t in targets do
				local dx, dz = t.x - e.x, t.z - e.z
				local d = dx * dx + dz * dz
				if d < bd then
					bd = d
					best = t
				end
			end
			local dist = math.sqrt(bd)
			local dirx, dirz = 0, 0

			if dist > Config.RecycleDistance and not e.boss then
				e.x, e.z = ringPos(best)
				e.kx, e.kz = 0, 0
			else
				if dist > 0.01 then
					dirx, dirz = (best.x - e.x) / dist, (best.z - e.z) / dist
				end
				-- atstūmimas nuo kitų priešų, kad nesusilietų į vieną kamuolį
				local sx, sz = 0, 0
				for _, o in grid:query(e.x, e.z, e.r) do
					if o ~= e then
						local dx, dz = e.x - o.x, e.z - o.z
						local d2 = dx * dx + dz * dz
						if d2 < 1e-4 then
							dx, dz = rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
							d2 = dx * dx + dz * dz + 1e-3
						end
						local d = math.sqrt(d2)
						local overlap = (e.r + o.r) - d
						if overlap > 0 then
							local f = overlap / (e.r + o.r)
							sx += dx / d * f
							sz += dz / d * f
						end
					end
				end
				local sp = e.speed * run.speedEvent
					if e.ai == "ranged" then
						if dist < e.range then
							sp = 0
						end
						e.shotT -= dt
						if e.shotT <= 0 and dist < e.range + 14 then
							e.shotT = e.shotCd
							enemyShot(e, best)
						end
					elseif e.ai == "bomber" and dist < 2.6 then
						booms[#booms + 1] = e
					end
				e.x = math.clamp(e.x + (dirx * sp + sx * sp * 1.6 + e.kx) * dt, -half, half)
				e.z = math.clamp(e.z + (dirz * sp + sz * sp * 1.6 + e.kz) * dt, -half, half)
				e.kx *= 0.86
				e.kz *= 0.86
			end

			local bob = math.abs(math.sin(now * 7 + e.phase)) * (e.boss and 0.15 or 0.5)
			local pos = Vector3.new(e.x, e.y + bob, e.z)
			local cf
			if dirx == 0 and dirz == 0 then
				cf = CFrame.new(pos)
			else
				cf = CFrame.lookAt(pos, Vector3.new(e.x + dirx, pos.Y, e.z + dirz))
			end
			if not e.boss then
				cf *= CFrame.Angles(0, 0, math.sin(now * 7 + e.phase) * 0.18)
			end
			n += 1
			parts[n] = e.part
			cfs[n] = cf
			for _, d in e.decos do
				n += 1
				parts[n] = d.part
				if d.spin then
					cfs[n] = cf * CFrame.new(d.pos) * CFrame.Angles(0, now * d.spin + e.phase, 0) * d.rot
				else
					cfs[n] = cf * d.rel
				end
			end
			if e.flash and now >= e.flash then
				e.flash = nil
				e.part.Color = e.baseColor
			end
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, e in booms do
		explodeBomber(e, targets)
	end
end

---------------------------------------------------------------------
-- Ginklai
---------------------------------------------------------------------
local function nearestEnemy(x, z, range)
	local best, bd = nil, range * range
	for _, e in enemies do
		if e.alive then
			local dx, dz = e.x - x, e.z - z
			local d = dx * dx + dz * dz
			if d < bd then
				bd = d
				best = e
			end
		end
	end
	return best
end

local function fireBolt(st, px, pz, L)
	local target = nearestEnemy(px, pz, L.range)
	if not target then
		return false
	end
	local base = math.atan2(target.z - pz, target.x - px)
	local color = Defs.Weapons.Bolt.color
	for i = 1, L.count do
		if #projectiles >= Config.MaxProjectiles then
			break
		end
		local a = base + (i - (L.count + 1) / 2) * 0.17
		local part = Instance.new("Part")
		part.Name = "Bolt"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.3, 1.3, 1.3)
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Position = Vector3.new(px, 3, pz)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.5, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.5, 0)
		a1.Parent = part
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.25
		tr.FaceCamera = true
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(color)
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.Parent = part
		part.Parent = projFolder
		projectiles[#projectiles + 1] = {
			part = part, x = px, z = pz, y = 3,
			dx = math.cos(a), dz = math.sin(a),
			speed = L.speed, dmg = L.dmg, pierce = L.pierce,
			life = 1.6, hit = {}, owner = st,
		}
	end
	Fx.push({ "s", "shot", px, pz })
	return true
end

local function fireNova(st, px, pz, L)
	local hits = grid:query(px, pz, L.radius)
	if #hits == 0 then
		return false
	end
	for _, e in hits do
		if e.alive then
			local dx, dz = e.x - px, e.z - pz
			local d = math.sqrt(dx * dx + dz * dz) + 1e-4
			hitEnemy(e, L.dmg, st, dx / d, dz / d, 28)
		end
	end
	local c = Defs.Weapons.Nova.color
	Fx.push({ "p", px, 0.4, pz, L.radius, math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) })
	return true
end

local function fireChain(st, px, pz, L)
	local first = nearestEnemy(px, pz, L.range)
	if not first then
		return false
	end
	local pts = { px, pz }
	local visited = {}
	local cur = first
	for j = 1, L.jumps do
		visited[cur] = true
		pts[#pts + 1] = cur.x
		pts[#pts + 1] = cur.z
		local cx, cz = cur.x, cur.z
		hitEnemy(cur, L.dmg * (0.9 ^ (j - 1)), st, 0, 0, 0)
		local best, bd = nil, math.huge
		for _, o in grid:query(cx, cz, 14) do
			if o.alive and not visited[o] then
				local d = (o.x - cx) ^ 2 + (o.z - cz) ^ 2
				if d < bd then
					bd = d
					best = o
				end
			end
		end
		if not best then
			break
		end
		cur = best
	end
	Fx.push({ "c", pts })
	return true
end

local function addStrike(x, z, r, dmg, delay, owner)
	strikes[#strikes + 1] = { t = delay, x = x, z = z, r = r, dmg = dmg, owner = owner, hostile = owner == nil }
	Fx.push({ "w", x, z, r, delay })
end

local function fireMeteor(st, px, pz, L)
	local cands = {}
	for _, e in enemies do
		if e.alive and (e.x - px) ^ 2 + (e.z - pz) ^ 2 <= L.range * L.range then
			cands[#cands + 1] = e
		end
	end
	if #cands == 0 then
		return false
	end
	for _ = 1, L.count do
		local e = cands[rng:NextInteger(1, #cands)]
		addStrike(e.x, e.z, L.radius, L.dmg, 0.9, st)
	end
	return true
end

local function fireInferno(st, px, pz, L)
	local hits = grid:query(px, pz, L.radius)
	if #hits == 0 then
		return false
	end
	for _, e in hits do
		if e.alive then
			local dx, dz = e.x - px, e.z - pz
			local d = math.sqrt(dx * dx + dz * dz) + 1e-4
			hitEnemy(e, L.dmg, st, dx / d, dz / d, 2)
		end
	end
	return true
end

local fireFns = {
	Bolt = fireBolt, Stormbolt = fireBolt, Nova = fireNova, Blizzard = fireNova, Chain = fireChain, Thunder = fireChain,
	Meteor = fireMeteor, Starfall = fireMeteor, Inferno = fireInferno, Hellfire = fireInferno,
}

local function updateWeapons(dt, targets)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, t in targets do
		local st, px, pz = t.st, t.x, t.z
		for id, lv in st.weapons do
			local L = Defs.Weapons[id].levels[lv]
			if id == "Blades" or id == "Bladestorm" then
				for i = 0, L.count - 1 do
					local a = serverNow * L.speed + i * (2 * math.pi / L.count)
					local bx, bz = px + math.cos(a) * L.radius, pz + math.sin(a) * L.radius
					for _, e in grid:query(bx, bz, 1.6) do
						local nextOk = e.cd[st]
						if e.alive and (not nextOk or now >= nextOk) then
							e.cd[st] = now + Config.BladeHitInterval
							local dx, dz = e.x - px, e.z - pz
							local d = math.sqrt(dx * dx + dz * dz) + 1e-4
							hitEnemy(e, L.dmg, st, dx / d, dz / d, 6)
							Fx.push({ "s", "blade", e.x, e.z })
						end
					end
				end
			else
				local timer = (st.timers[id] or 0) - dt
				if timer <= 0 then
					local fired = false
					local fn = fireFns[id]
						if fn then
							fired = fn(st, px, pz, L)
						end
					timer = fired and (L.cd * st.cdMult) or 0.12
				end
				st.timers[id] = timer
			end
		end
	end
end

local function updateProjectiles(dt)
	local parts, cfs, n = {}, {}, 0
	local i = 1
	while i <= #projectiles do
		local p = projectiles[i]
		p.x += p.dx * p.speed * dt
		p.z += p.dz * p.speed * dt
		p.life -= dt
		local remove = p.life <= 0 or math.abs(p.x) > half + 10 or math.abs(p.z) > half + 10
		if not remove then
			for _, e in grid:query(p.x, p.z, 0.9) do
				if e.alive and not p.hit[e] then
					p.hit[e] = true
					hitEnemy(e, p.dmg, p.owner, p.dx, p.dz, 10)
					if p.pierce <= 0 then
						remove = true
						break
					end
					p.pierce -= 1
				end
			end
		end
		if remove then
			p.part:Destroy()
			projectiles[i] = projectiles[#projectiles]
			projectiles[#projectiles] = nil
		else
			n += 1
			parts[n] = p.part
			cfs[n] = CFrame.new(p.x, p.y, p.z)
			i += 1
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------------
-- Žaidėjų žala / mirtis / prikėlimas
---------------------------------------------------------------------
local function contactDamage(targets)
	for _, t in targets do
		local st = t.st
		if st.alive and st.iframe <= 0 then
			local hits = grid:query(t.x, t.z, 1.7)
			local n, maxDmg = 0, 0
			for _, e in hits do
				n += 1
				if e.dmg > maxDmg then
					maxDmg = e.dmg
				end
			end
			if n > 0 then
				st.hp -= maxDmg + (n - 1) * 2
				st.iframe = 0.5
				t.player:SetAttribute("HurtCount", (t.player:GetAttribute("HurtCount") or 0) + 1)
				if st.hp <= 0 then
					killPlayer(t.player, st)
				end
			end
		end
	end
end

function killPlayer(player, st)
	if not st.alive then
		return
	end
	st.alive = false
	player:SetAttribute("HasDied", true)
	st.hp = 0
	st.reviveAt = os.clock() + Config.ReviveSeconds
	local deathRoot = getRoot(player)
	if deathRoot then
		Fx.force({ "p", deathRoot.Position.X, 0.4, deathRoot.Position.Z, 16, 255, 90, 100 })
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
	publish(player, st)
	checkGameOver()
end

function spawnPlayer(player, st, position, hpFraction)
	st.spawning = true
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	if not ok or not stats[player] then
		st.spawning = false
		return
	end
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not (hum and root) then
		st.spawning = false
		return
	end
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if position then
		char:PivotTo(CFrame.new(position))
	end
	hum.Died:Connect(function()
		if player.Character == char then
			killPlayer(player, st)
		end
	end)
	recalc(st)
	st.hp = st.maxHp * (hpFraction or 1)
	st.alive = true
	st.spawning = false
	st.reviveAt = 0
	applyMovement(st)
	publish(player, st)
end

function revivePlayer(player, st, targets)
	if #targets == 0 then
		return
	end
	-- Keep the dead player safe until they claim their chest reward.
	-- Otherwise automatic teammate revival hides the menu mid-roulette.
	if Persistence.hasPending(player) then
		return
	end
	local anchor = targets[rng:NextInteger(1, #targets)]
	st.spawning = true
	task.spawn(function()
		spawnPlayer(player, st, Vector3.new(anchor.x + 3, 4, anchor.z), 0.5)
		st.iframe = 2.5
	end)
end

local function endRun()
	run.state = "GameOver"
	run.restartAt = 0 -- no automatic restart; wait for PLAY
	local secs = math.floor(run.time)
	workspace:SetAttribute("ResultTime", secs)
	workspace:SetAttribute("ResultKills", run.kills)
	workspace:SetAttribute("RestartAt", 0)
	workspace:SetAttribute("RunState", "GameOver")
	for player, st in stats do
		-- Only participants earned this run's time/score.
		if st.joined then
			Persistence.record(player, secs, st.kills, st.level)
		end
	end
end

function checkGameOver()
	if run.state ~= "Playing" then
		return
	end
	local any = false
	for _, st in stats do
		if st.joined then
			any = true
		end
		if st.joined and (st.alive or st.spawning) then
			return
		end
	end
	if any then
		endRun()
	end
end

function restartRun()
	for _, e in enemies do
		e.part:Destroy()
	end
	table.clear(enemies)
	for _, p in projectiles do
		p.part:Destroy()
	end
	table.clear(projectiles)
	for _, p in eprojs do
		p.part:Destroy()
	end
	table.clear(eprojs)
	table.clear(strikes)
	for i = #drops, 1, -1 do
		destroyDrop(i)
	end
	resetRun()
	workspace:SetAttribute("RunState", "Playing")
	workspace:SetAttribute("RunTime", 0)
	for player, st in stats do
		resetStats(st)
		if not st.joined then
			publish(player, st)
			continue
		end
		if Persistence.hasPending(player) then
			-- Do not respawn while chest roulette is rolling or KEEP/SELL is undecided.
			-- Remain dead, safe and able to use the menu until KEEP/SELL.
			st.waitingReward = true
			player:SetAttribute("HasDied", true)
			publish(player, st)
			continue
		end
		-- Protect restart from simultaneous deaths/leaves during character creation.
		st.spawning = true
		player:SetAttribute("HasDied", false)
		task.spawn(function()
			local loaded = Persistence.waitLoaded(player, 30)
			if stats[player] ~= st then return end
			if not loaded then
				st.spawning = false
				st.waitingReward = true
				player:SetAttribute("HasDied", true)
				publish(player, st)
				warn("[Survivors] Could not load profile before restart for " .. player.UserId)
				return
			end
			if Persistence.hasPending(player) then
				st.spawning = false
				st.waitingReward = true
				player:SetAttribute("HasDied", true)
				publish(player, st)
				return
			end
			if run.state ~= "Playing" then
				st.spawning = false
				return
			end
			spawnPlayer(player, st, nil, 1)
			if stats[player] == st and run.state == "Playing" and st.alive then
				sendHeroOffer(player, st)
			end
		end)
	end
end

---------------------------------------------------------------------
-- Pagrindinis žingsnis
---------------------------------------------------------------------
local function collectTargets()
	local list = {}
	for player, st in stats do
		if st.alive then
			local root = getRoot(player)
			if root then
				list[#list + 1] = { player = player, st = st, x = root.Position.X, z = root.Position.Z }
			end
		end
	end
	return list
end

local function updateStrikes(dt, targets)
	local i = 1
	while i <= #strikes do
		local sk = strikes[i]
		sk.t -= dt
		if sk.t <= 0 then
			local c = sk.hostile and { 255, 90, 50 } or { 255, 160, 70 }
			Fx.force({ "p", sk.x, 0.4, sk.z, sk.r, c[1], c[2], c[3] })
			if sk.hostile then
				for _, t in targets do
					local dx, dz = t.x - sk.x, t.z - sk.z
					if dx * dx + dz * dz <= (sk.r + 0.8) ^ 2 then
						hurtPlayer(t.player, t.st, sk.dmg)
					end
				end
			else
				for _, e in grid:query(sk.x, sk.z, sk.r) do
					if e.alive then
						local dx, dz = e.x - sk.x, e.z - sk.z
						local d = math.sqrt(dx * dx + dz * dz) + 1e-4
						hitEnemy(e, sk.dmg, sk.owner, dx / d, dz / d, 20)
					end
				end
			end
			strikes[i] = strikes[#strikes]
			strikes[#strikes] = nil
		else
			i += 1
		end
	end
end

local function endEvent()
	run.event = nil
	run.xpEvent, run.speedEvent, run.spawnEvent = 1, 1, 1
	run.nextEvent = run.time + rng:NextNumber(Config.EventGapMin, Config.EventGapMax)
	workspace:SetAttribute("Event", "")
end

local function updateEvents(dt, targets)
	if run.event then
		run.eventLeft -= dt
		if run.event == "Meteor Shower" then
			run.nextStrike -= dt
			if run.nextStrike <= 0 then
				run.nextStrike = 0.45
				local tg = targets[rng:NextInteger(1, #targets)]
				local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 28)
				local x = math.clamp(tg.x + math.cos(a) * r, -half, half)
				local z = math.clamp(tg.z + math.sin(a) * r, -half, half)
				addStrike(x, z, 8, 22 + run.time / 15, 1.4, nil)
			end
		end
		if run.event == "Elite Hunt" then
			run.nextStrike -= dt
			if run.nextStrike <= 0 then
				run.nextStrike = 4
				spawnElite(targets)
			end
		end
		if run.eventLeft <= 0 then
			endEvent()
		end
	elseif run.time >= run.nextEvent then
		local ev = Config.Events[rng:NextInteger(1, #Config.Events)]
		run.event = ev.name
		run.eventLeft = ev.dur
		run.nextStrike = 0
		if ev.name == "Blood Moon" then
			run.speedEvent, run.spawnEvent = 1.2, 1.5
		elseif ev.name == "XP Frenzy" then
			run.xpEvent, run.spawnEvent = 2.5, 1.3
		end
		workspace:SetAttribute("EventEnd", workspace:GetServerTimeNow() + ev.dur)
		workspace:SetAttribute("Event", ev.name)
		Fx.force({ "m", "EVENT: " .. string.upper(ev.name) })
	end
end

local tickCount = 0

local function step(dt)
	if run.state == "GameOver" then
		-- Game-over screen remains until a player presses PLAY.
		return
	end

	local now = os.clock()
	-- A saved chest reward can outlast the team game-over screen.
	-- Resume only that player after the server confirms KEEP or SELL.
	for player, st in stats do
		if st.waitingReward and st.joined and not st.spawning and not Persistence.hasPending(player) then
			st.waitingReward = false
			st.spawning = true -- prevents multiple queued respawns on successive frames
			player:SetAttribute("HasDied", false)
			task.spawn(function()
				if stats[player] ~= st or run.state ~= "Playing" then
					st.spawning = false
					return
				end
				spawnPlayer(player, st, nil, 1)
				Persistence.waitLoaded(player, 10)
				if stats[player] == st and run.state == "Playing" and st.alive then
					sendHeroOffer(player, st)
				end
			end)
		end
	end
	local targets = collectTargets()
	if #targets > 0 then
		run.time += dt
	end

	-- atributų publikavimas ~10 Hz
	tickCount += 1
	if tickCount % 3 == 0 then
		for player, st in stats do
			publish(player, st)
		end
		workspace:SetAttribute("RunTime", math.floor(run.time))
	end

	for _, t in targets do
		local st = t.st
		st.iframe = math.max(0, st.iframe - dt)
		if st.regen > 0 then
			st.hp = math.min(st.maxHp, st.hp + st.regen * dt)
		end
	end

	for player, st in stats do
		if st.offer and now >= st.offerExpires then
			local opts = st.offer.options
			applyPick(player, st, opts[rng:NextInteger(1, #opts)].id)
		end
		if not st.alive and not st.spawning and st.reviveAt > 0 and now >= st.reviveAt then
			revivePlayer(player, st, targets)
		end
	end

	if #targets == 0 then
		return
	end

	grid:clear()
	for _, e in enemies do
		if e.alive then
			grid:insert(e)
		end
	end

	updateWeapons(dt, targets)
	updateProjectiles(dt)
	contactDamage(targets)
	updateEnemies(dt, targets)
	updateEnemyProjectiles(dt, targets)
	updateStrikes(dt, targets)
	updateDrops(dt, targets)
	updateEvents(dt, targets)
	updateSpawner(dt, targets)

	-- pašalinti negyvus priešus iš masyvo
	local i = 1
	while i <= #enemies do
		if not enemies[i].alive then
			enemies[i] = enemies[#enemies]
			enemies[#enemies] = nil
		else
			i += 1
		end
	end
end

local acc = 0
local lastWarn = 0
local avgDt = 1 / 60
RunService.Heartbeat:Connect(function(dt)
	-- našumo apsauga: jei serveris lėtėja, mažiname priešų limitą (ir atgal, kai atsigauna)
	avgDt = avgDt * 0.95 + dt * 0.05
	if avgDt > 1 / 38 then
		perf = math.max(0.5, perf - dt * 0.05)
	elseif avgDt < 1 / 50 then
		perf = math.min(1, perf + dt * 0.02)
	end
	acc += math.min(dt, 0.1)
	local n = 0
	while acc >= Config.Step and n < 3 do
		acc -= Config.Step
		n += 1
		local ok, err = pcall(step, Config.Step)
		if not ok and os.clock() - lastWarn > 2 then
			lastWarn = os.clock()
			warn("[Survivors] step error: " .. tostring(err))
		end
	end
	Fx.flush()
end)

---------------------------------------------------------------------
-- Žaidėjų prisijungimas / atsijungimas
---------------------------------------------------------------------
local function onPlayerAdded(player)
	local st = newStats(player)
	st.joined = false
	stats[player] = st
	player:SetAttribute("HasJoined", false)
	player:SetAttribute("HasDied", false)
	Persistence.attach(player)
	publish(player, st)
	-- Stay safely out of the arena until the player presses JOIN.
end

-- Team run starts again only by an explicit PLAY after GameOver.
-- One player can start the next shared run; chest owners must choose KEEP/SELL first.
playAgainRemote.OnServerEvent:Connect(function(player)
    local st = stats[player]
    if run.state ~= "GameOver" or not st or not st.joined then return end
    if Persistence.hasPending(player) then
        player:SetAttribute("ChestNotice", "Finish your chest reward in MENU before PLAY.")
        return
    end
    restartRun()
end)

-- JOIN requests are checked server-side; UI calls cannot force an extra life.
joinRemote.OnServerEvent:Connect(function(player)
	local st = stats[player]
	if not st or st.joined or st.spawning then
		return
	end
	st.joined = true
	player:SetAttribute("HasJoined", true)
	-- Persistent pending reward is checked again AFTER loading in the spawn task.
	if run.state ~= "Playing" then
		-- Joined during the result screen: automatically enter on the next run.
		return
	end

	-- Late joiners catch up to the current team's progress.
	local sum, count = 0, 0
	for other, entry in stats do
		if other ~= player and entry.joined then
			sum += entry.level
			count += 1
		end
	end
	if count > 0 then
		st.pending = math.max(0, math.floor((sum / count - 1) * 0.5))
		st.level = 1 + st.pending
	end
	task.spawn(function()
		-- Load persistent chest data BEFORE spawning, otherwise JOIN can race GetAsync.
		local loaded = Persistence.waitLoaded(player, 30)
		if stats[player] ~= st then return end
		if not loaded then
			warn("[Survivors] Could not load profile before JOIN for " .. player.UserId)
			st.joined = false
			player:SetAttribute("HasJoined", false)
			return
		end
		if Persistence.hasPending(player) then
			st.waitingReward = true
			player:SetAttribute("HasDied", true)
			publish(player, st)
			return
		end
		if run.state ~= "Playing" then return end
		spawnPlayer(player, st, nil, 1)
		if stats[player] == st and run.state == "Playing" and st.alive then
			sendHeroOffer(player, st)
		end
	end)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local leaving = stats[player]
	if leaving and leaving.joined and run.state == "Playing" then
		Persistence.record(player, math.floor(run.time), leaving.kills, leaving.level)
	end
	stats[player] = nil
	Persistence.detach(player)
	checkGameOver()
end)

game:BindToClose(function()
	Persistence.saveAll()
end)
