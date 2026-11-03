-- ServerScriptService/Survivors/Grid  (ModuleScript, šalia Game_server)
-- Paprastas erdvinis tinklelis: greita paieška "kas šalia taško".
local Grid = {}
Grid.__index = Grid

local CELL = 8

local function key(cx, cz)
	return cx * 100003 + cz
end

function Grid.new()
	return setmetatable({ cells = {}, maxR = 1 }, Grid)
end

function Grid:clear()
	self.cells = {}
	self.maxR = 1
end

function Grid:insert(e)
	local k = key(math.floor(e.x / CELL), math.floor(e.z / CELL))
	local c = self.cells[k]
	if c then
		c[#c + 1] = e
	else
		self.cells[k] = { e }
	end
	if e.r > self.maxR then
		self.maxR = e.r
	end
end

-- grąžina priešus, kurių apskritimas (e.r) kertasi su apskritimu (x, z, r)
function Grid:query(x, z, r)
	local out, n = {}, 0
	local reach = r + self.maxR
	local x0, x1 = math.floor((x - reach) / CELL), math.floor((x + reach) / CELL)
	local z0, z1 = math.floor((z - reach) / CELL), math.floor((z + reach) / CELL)
	local cells = self.cells
	for cx = x0, x1 do
		for cz = z0, z1 do
			local c = cells[key(cx, cz)]
			if c then
				for _, e in c do
					local dx, dz = e.x - x, e.z - z
					local lim = r + e.r
					if dx * dx + dz * dz <= lim * lim then
						n += 1
						out[n] = e
					end
				end
			end
		end
	end
	return out
end

return Grid
