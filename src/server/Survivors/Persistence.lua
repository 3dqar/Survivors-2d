-- ServerScriptService/Survivors/Persistence  (ModuleScript)
-- Leaderstats, monetos, skrynios, nuolatiniai patobulinimai, DataStore + pasaulinė lentelė.
-- Be paskelbtos vietos veikia tik sesijos metu (be saugojimo).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meta = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Meta"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("Cosmetics"))
local Goals = require(script.Parent:WaitForChild("Goals"))

local Persistence = {}
Persistence.onLoaded = nil -- Game_server nustato: perskaičiuoja statistiką

local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("SurvivorsV2")
end)
if not okStore then
	store = nil
end
local okTop, topStore = pcall(function()
	return DataStoreService:GetOrderedDataStore("SurvivorsBestV1")
end)
if not okTop then
	topStore = nil
end

-- Separate lifetime OrderedDataStores: existing survival-time board keeps its key.
local ordered = { time = topStore }
for metric, storeName in { bestKills = "SurvivorsBestKillsV1", bestLevel = "SurvivorsBestLevelV1", totalKills = "SurvivorsTotalKillsV1" } do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName)
	end)
	ordered[metric] = ok and result or nil
end

local rng = Random.new()
local data = {}
local tops, topAt, topBusy, names = {}, {}, {}, {}

local function refreshValues(d)
	if d.player then d.player:SetAttribute("ChestPending", d.pending ~= nil) end
	d.bestValue.Value = d.best
	d.killsValue.Value = d.kills
	d.coinsValue.Value = d.coins
	d.bestKillsValue.Value = d.bestKills
	d.bestLevelValue.Value = d.bestLevel
end

-- Per-player serial saving prevents a delayed older SetAsync from overwriting a newer run.
-- Only save after a successful profile read; never overwrite data if GetAsync failed.
local function save(player)
    local d = data[player]
    if not store or not d or not d.loaded or d.noSave then return end

    -- When called during another save, wait for it to finish. PlayerRemoving and
    -- BindToClose must not discard writes queued during an in-flight request.
    if d.saving then
        while d.saving and data[player] == d do
            task.wait(0.05)
        end
    end
    if data[player] ~= d or not d.dirty then return end
    d.saving = true

    local attempts = 0
    while d.dirty and attempts < 4 and data[player] == d do
        attempts += 1
        d.dirty = false
        local payload = {
            best = d.best, kills = d.kills, bestKills = d.bestKills, bestLevel = d.bestLevel,
            coins = d.coins, chests = d.chests,
            up = table.clone(d.up),
            pending = d.pending and table.clone(d.pending) or nil,
            stats = table.clone(d.stats), ach = table.clone(d.ach),
            daily = { day = d.daily.day, prog = table.clone(d.daily.prog), done = table.clone(d.daily.done) },
            preferredHero = d.preferredHero,
            cosmetics = { owned = table.clone(d.cosmetics.owned), equipped = d.cosmetics.equipped },
        }
        local ok, err = pcall(function()
            store:SetAsync(tostring(player.UserId), payload)
        end)
        if not ok then
            d.dirty = true
            warn("[Survivors] Profile save failed for " .. player.UserId .. ": " .. tostring(err))
            break
        end
        -- If another event changed money/upgrades during the write, loop and save
        -- that later snapshot too; calls for the same player never race.
    end
    d.saving = false
end

local function touch(player)
	local d = data[player]
	if not d then
		return
	end
	d.dirty = true
	refreshValues(d)
	if not d.timer then
		d.timer = true
		task.delay(15, function()
			d.timer = false
			save(player)
		end)
	end
end

local function updateOrdered(player, metric, score)
	local board = ordered[metric]
	local d = data[player]
	if not board or not d or d.noSave or not d.loaded then return end
	task.spawn(function()
		local ok, err = pcall(function()
			board:UpdateAsync(tostring(player.UserId), function(old)
				return math.max(tonumber(old) or 0, math.floor(score))
			end)
		end)
		if not ok then
			warn("[Survivors] Global " .. metric .. " update failed: " .. tostring(err))
		end
	end)
end

local function refreshTop(metric)
	local board = ordered[metric]
	if not board or topBusy[metric] or os.clock() - (topAt[metric] or -1e9) < 60 then return end
	topBusy[metric] = true
	task.spawn(function()
		local ok, page = pcall(function()
			return board:GetSortedAsync(false, 10):GetCurrentPage()
		end)
		if ok then
			local list = {}
			for _, entry in page do
				local uid = tonumber(entry.key) or 0
				if not names[uid] then
					local okName, username = pcall(function()
						return Players:GetNameFromUserIdAsync(uid)
					end)
					names[uid] = okName and username or ("Player " .. tostring(entry.key))
				end
				list[#list + 1] = { name = names[uid], score = entry.value }
			end
			tops[metric] = list
		else
			warn("[Survivors] Global leaderboard read failed (" .. metric .. "): " .. tostring(page))
		end
		topAt[metric] = os.clock()
		topBusy[metric] = false
	end)
end

function Persistence.attach(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local function value(name)
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = folder
		return v
	end
	local d = {
		player = player,
		best = 0, kills = 0, bestKills = 0, bestLevel = 0, coins = 0, chests = 0, up = {}, pending = nil,
		stats = {}, ach = {}, preferredHero = nil, daily = { day = 0, prog = {}, done = {} }, toastN = 0,
        cosmetics = { owned = {}, equipped = nil },
		loaded = false, dirty = false, saving = false, timer = false, noSave = false,
		bestValue = value("Best (s)"), killsValue = value("Total kills"), coinsValue = value("Coins"),
		bestKillsValue = value("Best kills"), bestLevelValue = value("Best level"),
	}
	folder.Parent = player
	data[player] = d

	local function done(gift)
		d.loaded = true
        player:SetAttribute("CosmeticTrail", d.cosmetics.equipped or "")
		refreshValues(d)
		if gift then
			touch(player)
		end
		if Persistence.onLoaded then
			Persistence.onLoaded(player)
		end
	end

	if not store then
		d.chests = 1
		done(false)
		return
	end
	task.spawn(function()
		local ok, saved = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if data[player] ~= d then
			return
		end
		local gift = false
		if ok then
			if type(saved) == "table" then
				d.best = math.max(d.best, tonumber(saved.best) or 0)
				d.bestKills = math.max(0, tonumber(saved.bestKills) or 0)
				d.bestLevel = math.max(0, tonumber(saved.bestLevel) or (type(saved.stats) == "table" and tonumber(saved.stats.level)) or 0)
				d.kills += tonumber(saved.kills) or 0
				d.coins += tonumber(saved.coins) or 0
				d.chests += tonumber(saved.chests) or 0
				if type(saved.up) == "table" then
					d.up = saved.up
				end
				if type(saved.pending) == "table" then
					d.pending = saved.pending
				end
				if type(saved.preferredHero) == "string" then
					d.preferredHero = saved.preferredHero
				end
                if type(saved.cosmetics) == "table" then
                    local owned = saved.cosmetics.owned
                    if type(owned) == "table" then
                        for id, has in pairs(owned) do
                            if type(id) == "string" and Cosmetics.ById[id] and has == true then
                                d.cosmetics.owned[id] = true
                            end
                        end
                    end
                    local equipped = saved.cosmetics.equipped
                    if type(equipped) == "string" and d.cosmetics.owned[equipped] then
                        d.cosmetics.equipped = equipped
                    end
                end
				if type(saved.stats) == "table" then
					d.stats = saved.stats
				end
				if type(saved.ach) == "table" then
					d.ach = saved.ach
				end
				if type(saved.daily) == "table" and type(saved.daily.prog) == "table" and type(saved.daily.done) == "table" then
					d.daily = saved.daily
				end
			else
				d.chests += 1 -- pirmoji dovana
				gift = true
			end
		else
			d.noSave = true -- nepavyko užkrauti: niekada neperrašome senų duomenų
		end
		done(gift)
	end)
end

function Persistence.bonus(player)
	local b = { hp = 0, dmg = 0, speed = 0, xp = 0, regen = 0, crit = 0 }
	local d = data[player]
	if d then
		for id, lv in d.up do
			local s = Meta.Stats[id]
			if s then
				b[s.key] += s.per * lv
			end
		end
	end
	return b
end

---------------------------------------------------------------------
-- Pasiekimai ir dienos iššūkiai
---------------------------------------------------------------------
local function rollDaily(d)
	local day = Goals.dayNumber()
	if d.daily.day ~= day then
		d.daily = { day = day, prog = {}, done = {} }
	end
end

local function lifetime(d, metric)
	if metric == "kills" then
		return d.kills
	elseif metric == "time" then
		return d.best
	end
	return d.stats[metric] or 0
end

local function toast(player, d, msg)
	d.toastN += 1
	player:SetAttribute("Toast", d.toastN .. "|" .. msg)
end

local function checkGoals(player, d)
	rollDaily(d)
	for _, a in Goals.Achievements do
		if not d.ach[a.id] and lifetime(d, a.metric) >= a.target then
			d.ach[a.id] = true
			d.coins += a.coins
			toast(player, d, "ACHIEVEMENT: " .. a.name .. "  +" .. a.coins .. " coins")
		end
	end
	for i, c in Goals.dailyFor(d.daily.day) do
		if not d.daily.done[i] and (d.daily.prog[c.metric] or 0) >= c.target then
			d.daily.done[i] = true
			d.coins += c.coins
			toast(player, d, "DAILY DONE: " .. c.name .. "  +" .. c.coins .. " coins")
		end
	end
end

-- metric: kills/titans/evos/time/level. skipLife: kills ir time jau įrašomi į d.kills / d.best
function Persistence.progress(player, metric, value, skipLife)
	local d = data[player]
	if not d or not d.loaded or not Goals.Mode[metric] then
		return
	end
	rollDaily(d)
	local add = Goals.Mode[metric] == "add"
	if not skipLife and metric ~= "kills" and metric ~= "time" then
		if add then
			d.stats[metric] = (d.stats[metric] or 0) + value
		else
			d.stats[metric] = math.max(d.stats[metric] or 0, value)
		end
	end
	local p = d.daily.prog
	if add then
		p[metric] = (p[metric] or 0) + value
	else
		p[metric] = math.max(p[metric] or 0, value)
	end
	checkGoals(player, d)
	touch(player)
end

-- po žaidimo: monetos pagal nužudymus ir laiką
function Persistence.record(player, secs, kills, level)
	local d = data[player]
	if not d or not d.loaded then return 0 end
	secs = math.max(0, math.floor(tonumber(secs) or 0))
	kills = math.max(0, math.floor(tonumber(kills) or 0))
	level = math.max(1, math.floor(tonumber(level) or 1))
	local gained = math.floor(kills / 5 + secs / 20)
	d.coins += gained
	d.kills += kills
	if secs > d.best then
		d.best = secs
		updateOrdered(player, "time", d.best)
	end
	if kills > d.bestKills then
		d.bestKills = kills
		updateOrdered(player, "bestKills", kills)
	end
	if level > d.bestLevel then
		d.bestLevel = level
		updateOrdered(player, "bestLevel", level)
	end
	updateOrdered(player, "totalKills", d.kills)
	touch(player)
	Persistence.progress(player, "kills", kills, true)
	Persistence.progress(player, "time", secs, true)
	Persistence.progress(player, "level", level)
	-- At the end of each run, flush profile immediately, not only at the delayed autosave.
	task.spawn(save, player)
	return gained
end

function Persistence.addChest(player, n)
	local d = data[player]
	if d then
		d.chests += n
		touch(player)
	end
end

local function state(player, ok, msg)
	local d = data[player]
	if not d then
		return { ok = false, msg = "No data" }
	end
	for _, metric in { "time", "bestKills", "bestLevel", "totalKills" } do
		refreshTop(metric)
	end
	local server = {}
	for p, pd in data do
		server[#server + 1] = { name = p.DisplayName, level = p:GetAttribute("Level") or 1, kills = p:GetAttribute("Kills") or 0, best = pd.best, bestKills = pd.bestKills, bestLevel = pd.bestLevel }
	end
	table.sort(server, function(a, b)
		return a.kills > b.kills
	end)
	rollDaily(d)
	local ach = {}
	for _, a in Goals.Achievements do
		ach[#ach + 1] = { name = a.name, desc = a.desc, target = a.target, coins = a.coins, value = math.min(lifetime(d, a.metric), a.target), done = d.ach[a.id] == true }
	end
	local daily = {}
	for i, c in Goals.dailyFor(d.daily.day) do
		daily[i] = { name = c.name, target = c.target, coins = c.coins, value = math.min(d.daily.prog[c.metric] or 0, c.target), done = d.daily.done[i] == true }
	end
	return {
		ok = ok ~= false, msg = msg, loaded = d.loaded, coins = d.coins, chests = d.chests, up = d.up,
		pending = d.pending, best = d.best, kills = d.kills, bestKills = d.bestKills, bestLevel = d.bestLevel,
		price = Meta.ChestPrice, top = tops.time or {}, topKills = tops.bestKills or {}, topLevel = tops.bestLevel or {}, topTotalKills = tops.totalKills or {}, server = server,
		ach = ach, daily = daily, dailyReset = (d.daily.day + 1) * 86400 - os.time(),
        cosmetics = { owned = table.clone(d.cosmetics.owned), equipped = d.cosmetics.equipped or "" },
	}
end
Persistence.state = state

-- The game loop holds a dead player safely in the reward screen until KEEP or SELL.
function Persistence.hasPending(player)
    local d = data[player]
    return d ~= nil and d.pending ~= nil
end

function Persistence.open(player)
	local d = data[player]
	if not d or not d.loaded then
		return state(player, false, "Loading...")
	end
	if d.pending then
		return state(player, false, "Resolve your current reward first.")
	end
	if d.chests <= 0 then
		return state(player, false, "You have no chests.")
	end
	d.chests -= 1
	local stat, r
	for _ = 1, 6 do
		stat, r = Meta.roll(rng)
		if (d.up[stat] or 0) < Meta.MaxLevel then
			break
		end
	end
	d.pending = { stat = stat, r = r }
	touch(player)
	return state(player, true, "Chest opened!")
end

local function resolve(player, sell)
	local d = data[player]
	if not d or not d.pending then
		return state(player, false, "Nothing to resolve.")
	end
	local p = d.pending
	local rar = Meta.Rarities[p.r]
	local lv = d.up[p.stat] or 0
	local msg
	if sell or lv >= Meta.MaxLevel then
		d.coins += rar.sell
		msg = (sell and "Sold" or "Already maxed - sold") .. " for " .. rar.sell .. " coins."
	else
		d.up[p.stat] = math.min(Meta.MaxLevel, lv + rar.lv)
		msg = Meta.Stats[p.stat].name .. " upgraded!"
	end
	d.pending = nil
	touch(player)
	if Persistence.onLoaded then
		Persistence.onLoaded(player)
	end
	return state(player, true, msg)
end

function Persistence.keep(player)
	return resolve(player, false)
end

function Persistence.sell(player)
	return resolve(player, true)
end

function Persistence.buy(player)
	local d = data[player]
	if not d or not d.loaded then
		return state(player, false, "Loading...")
	end
	if d.coins < Meta.ChestPrice then
		return state(player, false, "Not enough coins.")
	end
	d.coins -= Meta.ChestPrice
	d.chests += 1
	touch(player)
	return state(player, true, "Chest bought!")
end

-- Cosmetic operations are server-authoritative, persistence-backed and never grant combat stats.
-- UI can call Meta(cosmeticBuy/cosmeticEquip/cosmeticUnequip, cosmeticId).
local function cosmeticsAvailable(player)
    local d = data[player]
    if not d or not d.loaded then return nil, "Profile is loading." end
    if d.noSave then return nil, "Saving unavailable. Try again later." end
    if d.pending then return nil, "Resolve the chest reward first." end
    return d
end

function Persistence.grantCosmetic(player, id)
    local d = data[player]
    if not d or not d.loaded or d.noSave or not Cosmetics.ById[id] then
        return false
    end
    if d.cosmetics.owned[id] then return false end
    d.cosmetics.owned[id] = true
    touch(player)
    task.spawn(save, player)
    return true
end

function Persistence.cosmeticBuy(player, id)
    local d, err = cosmeticsAvailable(player)
    if not d then return state(player, false, err) end
    if type(id) ~= "string" then return state(player, false, "Invalid item.") end
    local item = Cosmetics.ById[id]
    if not item then return state(player, false, "Unknown cosmetic.") end
    if d.cosmetics.owned[id] then return state(player, false, "Already owned.") end
    if d.coins < item.price then return state(player, false, "Not enough coins.") end
    d.coins -= item.price
    d.cosmetics.owned[id] = true
    touch(player)
    task.spawn(save, player)
    return state(player, true, item.name .. " unlocked!")
end

function Persistence.cosmeticEquip(player, id)
    local d, err = cosmeticsAvailable(player)
    if not d then return state(player, false, err) end
    if type(id) ~= "string" or not Cosmetics.ById[id] or not d.cosmetics.owned[id] then
        return state(player, false, "Cosmetic not owned.")
    end
    if d.cosmetics.equipped == id then return state(player, true, "Already equipped.") end
    d.cosmetics.equipped = id
    player:SetAttribute("CosmeticTrail", id)
    touch(player)
    return state(player, true, "Trail equipped.")
end

function Persistence.cosmeticUnequip(player)
    local d, err = cosmeticsAvailable(player)
    if not d then return state(player, false, err) end
    if d.cosmetics.equipped == nil then return state(player, true, "No trail equipped.") end
    d.cosmetics.equipped = nil
    player:SetAttribute("CosmeticTrail", "")
    touch(player)
    return state(player, true, "Trail removed.")
end

-- Last selected hero is a convenience preference; validate against Config on use.
function Persistence.preferredHero(player)
	local d = data[player]
	return d and d.loaded and d.preferredHero or nil
end

function Persistence.setPreferredHero(player, id)
	local d = data[player]
	if d and d.loaded and type(id) == "string" and d.preferredHero ~= id then
		d.preferredHero = id
		touch(player)
	end
end

function Persistence.waitLoaded(player, timeout)
	local deadline = os.clock() + (timeout or 10)
	while data[player] and not data[player].loaded and os.clock() < deadline do
		task.wait(0.1)
	end
	return data[player] and data[player].loaded == true
end

function Persistence.detach(player)
	save(player)
	data[player] = nil
end

function Persistence.saveAll()
	for player in data do
		save(player)
	end
end

return Persistence
