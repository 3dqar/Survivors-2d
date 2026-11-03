-- ServerScriptService/Survivors/Goals  (ModuleScript)  NAUJAS
-- Pasiekimų ir dienos iššūkių aprašai. Rodikliai (metric):
--   kills  - nužudymai (kaupiasi)     titans - nugalėti Titanai (kaupiasi)   evos - evoliucijos (kaupiasi)
--   time   - ilgiausias išgyventas laikas, s (geriausias)   level - aukščiausias lygis (geriausias)
local Goals = {}

Goals.Mode = { kills = "add", titans = "add", evos = "add", time = "max", level = "max" }

Goals.Achievements = {
	{ id = "k1", name = "Exterminator I", desc = "Defeat 1,000 enemies in total", metric = "kills", target = 1000, coins = 30 },
	{ id = "k2", name = "Exterminator II", desc = "Defeat 10,000 enemies in total", metric = "kills", target = 10000, coins = 120 },
	{ id = "k3", name = "Exterminator III", desc = "Defeat 50,000 enemies in total", metric = "kills", target = 50000, coins = 400 },
	{ id = "t1", name = "Survivor I", desc = "Survive 5 minutes in one run", metric = "time", target = 300, coins = 30 },
	{ id = "t2", name = "Survivor II", desc = "Survive 10 minutes in one run", metric = "time", target = 600, coins = 80 },
	{ id = "t3", name = "Survivor III", desc = "Survive 20 minutes in one run", metric = "time", target = 1200, coins = 250 },
	{ id = "b1", name = "Titan Slayer I", desc = "Defeat 1 Titan", metric = "titans", target = 1, coins = 25 },
	{ id = "b2", name = "Titan Slayer II", desc = "Defeat 10 Titans", metric = "titans", target = 10, coins = 100 },
	{ id = "b3", name = "Titan Slayer III", desc = "Defeat 50 Titans", metric = "titans", target = 50, coins = 350 },
	{ id = "e1", name = "Awakening", desc = "Evolve a weapon", metric = "evos", target = 1, coins = 40 },
	{ id = "e2", name = "Arsenal Master", desc = "Evolve 25 weapons", metric = "evos", target = 25, coins = 200 },
	{ id = "l1", name = "Power Surge", desc = "Reach level 20 in one run", metric = "level", target = 20, coins = 40 },
	{ id = "l2", name = "Ascended", desc = "Reach level 40 in one run", metric = "level", target = 40, coins = 150 },
}

-- dienos iššūkių baseinas (kiekvieną UTC dieną parenkami 3 skirtingi)
Goals.DailyPool = {
	{ name = "Defeat 400 enemies today", metric = "kills", target = 400, coins = 25 },
	{ name = "Defeat 1,200 enemies today", metric = "kills", target = 1200, coins = 55 },
	{ name = "Defeat 2 Titans today", metric = "titans", target = 2, coins = 40 },
	{ name = "Survive 6 minutes in one run", metric = "time", target = 360, coins = 35 },
	{ name = "Survive 12 minutes in one run", metric = "time", target = 720, coins = 70 },
	{ name = "Evolve a weapon", metric = "evos", target = 1, coins = 30 },
	{ name = "Reach level 15 in one run", metric = "level", target = 15, coins = 30 },
}

function Goals.dayNumber()
	return os.time() // 86400
end

-- grąžina 3 šios dienos iššūkius (visiems serveriams vienodi)
function Goals.dailyFor(day)
	local rng = Random.new(day)
	local pool = table.clone(Goals.DailyPool)
	local out = {}
	for i = 1, 3 do
		local j = rng:NextInteger(1, #pool)
		out[i] = pool[j]
		table.remove(pool, j)
	end
	return out
end

return Goals
