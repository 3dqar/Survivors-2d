-- ServerScriptService/Survivors/Fx  (ModuleScript, šalia Game_server)
-- Kaupia efektus ir siunčia klientams paketais ~20 kartų per sekundę.
local Fx = {}

local MAX_BATCH = 80
local remote
local batch = {}
local last = 0

function Fx.init(r)
	remote = r
end

-- nebūtini efektai (gali būti numesti, jei paketas pilnas)
function Fx.push(f)
	if #batch < MAX_BATCH then
		batch[#batch + 1] = f
	end
end

-- svarbūs pranešimai (visada įtraukiami)
function Fx.force(f)
	batch[#batch + 1] = f
end

function Fx.flush()
	if #batch == 0 or not remote then
		return
	end
	local now = os.clock()
	if now - last < 0.05 then
		return
	end
	last = now
	local out = batch
	batch = {}
	remote:FireAllClients(out)
end

return Fx
