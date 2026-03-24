--load all of orbit's files
local directory = { "/",
	"globals.lua",
	"itemactions.lua",
	"items.lua",
	"kartsonic.lua",
	"bots.lua",
	"spritefix.lua",
	"hud.lua",
	"camera.lua",
	"menu.lua",
-- 	"translator.lua",
	--KART_skinbind.lua is loaded via a command, see kartsonic.lua
}

local function load(dir, path)
	for i, v in ipairs(dir) do
		if i == 1 then continue end
		
		if type(v) == "string" then
			dofile(path..v)
		elseif type(v) == "table" then
			load(v, path..v[1].."/")
		end
	end
end

load(directory, "")