--romoney5: "kart RMX" as suggested by marilyn

rawset(_G,"gamespeed",1) --(gamespeed+1)*50 cc, or gear gamespeed+1
rawset(_G,"franticitems",0)
local gs = CV_RegisterVar{name = "kart_speed", defaultvalue = gamespeed, flags = CV_NETVAR}
rawset(_G,"mapobjectscale", FU)
local ORIG_FRICTION = 62914
local SLOWTURNTICS = 6
local KART_FULLTURN = 800

rawset(_G,"starttime", 0)
rawset(_G,"wipeoutslowtime", 20)
rawset(_G,"stealtime", TICRATE/2)
rawset(_G,"sneakertime", TICRATE + (TICRATE/3))
rawset(_G,"itemtime", 8*TICRATE)

local kart_preservebumps = CV_RegisterVar{name = "kart_preservebumps", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR}
local kart_keeplandspeed = CV_RegisterVar{name = "kart_keeplandspeed", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR}
local kart_triangledash = CV_RegisterVar{name = "kart_triangledash", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR}
rawset(_G,"kart_booststacking", CV_RegisterVar{name = "kart_booststacking", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR}) --boost snacking
rawset(_G,"kart_rrpoweritems", CV_RegisterVar{name = "kart_rrpoweritems", defaultvalue = "Off", PossibleValue = {Off = 0, On = 1, Bonus = 2}, flags = CV_NETVAR})
rawset(_G,"kart_rrsliptide", CV_RegisterVar{name = "kart_rrsliptide", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR})
rawset(_G,"kart_franticitems", CV_RegisterVar{name = "kart_franticitems", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR})
rawset(_G,"kart_rubberband", CV_RegisterVar{name = "kart_rubberband", defaultvalue = "1.0", PossibleValue = {MIN = 0, MAX = INT32_MAX}, flags = CV_NETVAR|CV_FLOAT})
local kart_rrmomentum = kart_booststacking--CV_RegisterVar{name = "kart_rrmomentum", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR}
rawset(_G,"kart_debuggeneral", CV_RegisterVar{name = "kart_debug", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR})
rawset(_G,"kart_haste", CV_RegisterVar{name = "kart_haste", defaultvalue = "On", PossibleValue = CV_OnOff, flags = CV_NETVAR})
rawset(_G,"kart_retrocore", CV_RegisterVar{name = "kart_retrocore", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR})

local DAT_STAND = 0 --base sprites
local DAT_SRB2KART = 1 --regular srb2kart
local DAT_RINGRACERS = 2 --ring racers character
local DAT_TAKISKART = 3 --takis kart
local DAT_TAKISKART_L = 4 --takis kart legacy, used by soap and takis
local DAT_RUSHCHARS = 5 --marine boat jetski bicycle motorbike retro

--kart_skinbind freeslots an spr2 midgame in case a character doesn't use SPR2_PLAY or any other prefix
local addedbinds = {}
local processedbinds = {} --client-side
local validatedbinds = {} --client-side
local addedbinds_oldlen = #addedbinds

addHook("NetVars", function(net) addedbinds = net($) end)

COM_AddCommand("kart_skinbind", function(player, name)
	if not name then
		CONS_Printf(player, "kart_skinbind SPR2_<name>: Freeslots an SPR2 for usage with any broken Kart characters.\n"..
			"Note that the SPR2_ prefix is appended automatically, so only input the following four characters (e.g. VANI).\n"..
			"For the command to be usable, Kart RMX must be loaded after all other addons.")
		return
	elseif tostring(name):len() ~= 4 then
		CONS_Printf(player, "Name length must be exactly 4 characters.\nNote that the SPR2_ prefix is appended automatically, so only input the following four characters (e.g. VANI).")
		return
	end
	
	table.insert(addedbinds, name)
end)

local data = {}
-- data.sonic = {kartspeed = 8, kartweight = 2, translation = nil, t = DAT_TAKISKART}
-- data.tails = {kartspeed = 2, kartweight = 2, translation = nil, t = DAT_TAKISKART}

if not TakisKart_KarterData
	rawset(_G,"TakisKart_KarterData",{})
	rawset(_G,"TakisKart_Karters",{})
end

TakisKart_KarterData.sonic = $ or {stats = {8, 2}, legacyframes = false}
TakisKart_KarterData.tails = $ or {stats = {2, 2}, legacyframes = false}

--automatically add compatibility for srb2kart character packs, addonloaded apparently is run before any skins are allocated
addHook("ThinkFrame", do
	if #addedbinds ~= addedbinds_oldlen then
		for i = addedbinds_oldlen + 1, #addedbinds do
			local name = addedbinds[i]
			
			rawset(_G, "KART_skinbind_name", name)
			local success, spr = pcall(dofile, "KART_skinbind.lua")
			
			if not success then
				--let the desyncs begin
				print("Failed to find Lua file. For the command to be usable, Kart RMX must be loaded after all other addons.")
				break
			end
			
			table.insert(processedbinds, spr)
		end
	end

	for i = 0, #skins - 1 do
		local skin = skins[i]
		if not skin then break end
		
		local t = TakisKart_KarterData and TakisKart_KarterData[skin.name] and (not data[skin.name] or not (data[skin.name].t == DAT_TAKISKART or data[skin.name].t == DAT_TAKISKART_L))
		local bound = data[skin.name] and data[skin.name].t == DAT_STAND and #addedbinds ~= addedbinds_oldlen and not validatedbinds[i] --check again
		if not data[skin.name] or t or bound
			local type = DAT_STAND
			local speed, weight = 5, 5
			local spr2 = SPR2_STND
			if skin.sprites[SPR2_JSKI].numframes > 0 type = DAT_RUSHCHARS spr2 = SPR2_JSKI end
			if skin.sprites[SPR2_PLAY].numframes > 0 type = DAT_SRB2KART spr2 = SPR2_PLAY end
			if skin.sprites[SPR2_STIN].numframes > 0 type = DAT_RINGRACERS spr2 = SPR2_STIN end
			local takis = TakisKart_KarterData and TakisKart_KarterData[skin.name]
			if takis
				type = takis.legacyframes and DAT_TAKISKART_L or DAT_TAKISKART
				speed, weight = takis.stats[1], takis.stats[2]
				spr2 = SPR2_KART
			end
			
			--still nothing?
			if type == DAT_STAND then
				for i, spr in ipairs(processedbinds) do --then go through all the custom spr2 binds
					if skin.sprites[spr].numframes > 0 then --do they have it?
						type = DAT_SRB2KART --for now
						spr2 = spr --score!
						validatedbinds[i] = true
						break
					end
				end
			end
			
			print("Adding kart support for \""..skin.name.."\", type: "..tostring(type))
			data[skin.name] = {kartspeed = speed, kartweight = weight, translation = (type == DAT_SRB2KART) and "Palette_2.1_to_2.2" or nil, t = type, spr2 = spr2}
		end
	end
	
	addedbinds_oldlen = #addedbinds
end)

freeslot("SPR2_KART", "SPR2_PLAY",
"SPR_KDST", "SPR_DRIF", "SPR_AIDU", "SPR_BUMP", "SPR_SLPT",
"S_KARTAIZDRIFTSTRAT",
"S_BUMP1", "S_BUMP2", "S_BUMP3",
"S_DRIFTDUST1", "S_DRIFTDUST2", "S_DRIFTDUST3", "S_DRIFTDUST4",
"S_DRIFTSPARK_A1", "S_DRIFTSPARK_A2", "S_DRIFTSPARK_A3", "S_DRIFTSPARK_B1", "S_DRIFTSPARK_C1", "S_DRIFTSPARK_C2",
"S_FASTLINE1","S_FASTLINE2","S_FASTLINE3","S_FASTLINE4","S_FASTLINE5",
"SPR_DSHR","S_FASTDUST1",
"SPR_WIPD","S_WIPEOUTTRAIL1",

"SPR_BDRF","S_BRAKEDRIFT","MT_BRAKEDRIFT",

"SKINCOLOR_SAPPHIRE2", "SKINCOLOR_RASPBERRY2", "SKINCOLOR_KETCHUP2", "SKINCOLOR_PERIWINKLE2", "SKINCOLOR_INVINCFLASH")
freeslot("SPR2_STIN","SPR2_STIL","SPR2_STIR",    "SPR2_SLWN","SPR2_SLWL","SPR2_SLWR",      "SPR2_FSTN","SPR2_FSTL","SPR2_FSTR",    "SPR2_DRLN","SPR2_DRLO","SPR2_DRLI","SPR2_DRRN","SPR2_DRRO","SPR2_DRRI")
freeslot("SPR2_JSKI")

for i = 36,44
	for ii = 0,12
		local st = "sfx_krt"
		local st2 = "0"
		if ii >= 10
			st2 = ""
		end
		
		freeslot(st..R_Frame2Char(i)..st2..ii)
	end
end

for i = 1,8
	local st = "sfx_itrol"
	freeslot(st..i)
end
freeslot("sfx_itrolf", "sfx_itrole", "sfx_itrolm", "sfx_dbgsal")

freeslot("SPR_KART_SOAP_SPEEDLINE")

states[S_KARTAIZDRIFTSTRAT] = {SPR_AIDU, FF_ANIMATE|FF_PAPERSPRITE, 5*2, nil, 5, 2, S_NULL}

states[S_DRIFTDUST1] = {sprite = SPR_KDST, frame = 0, tics = 3, action = nil, var1 = 0, var2 = 0, nextstate = S_DRIFTDUST2}
states[S_DRIFTDUST2] = {sprite = SPR_KDST, frame = 1, tics = 3, action = nil, var1 = 0, var2 = 0, nextstate = S_DRIFTDUST3}
states[S_DRIFTDUST3] = {sprite = SPR_KDST, frame = FF_TRANS20|2, tics = 3, action = nil, var1 = 0, var2 = 0, nextstate = S_DRIFTDUST4}
states[S_DRIFTDUST4] = {sprite = SPR_KDST, frame = FF_TRANS20|3, tics = 3, action = nil, var1 = 0, var2 = 0, nextstate = S_NULL}

-- states[S_FASTLINE1] = {sprite = SPR_FAST, frame = FF_PAPERSPRITE|FF_FULLBRIGHT, tics = 1, action = nil, var1 = 0, var2 = 0, nextstate = S_FASTLINE2}
-- states[S_FASTLINE2] = {sprite = SPR_FAST, frame = FF_PAPERSPRITE|FF_FULLBRIGHT|1, tics = 1, action = nil, var1 = 0, var2 = 0, nextstate = S_FASTLINE3}
-- states[S_FASTLINE3] = {sprite = SPR_FAST, frame = FF_PAPERSPRITE|FF_FULLBRIGHT|2, tics = 1, action = nil, var1 = 0, var2 = 0, nextstate = S_FASTLINE4}
-- states[S_FASTLINE4] = {sprite = SPR_FAST, frame = FF_PAPERSPRITE|FF_FULLBRIGHT|3, tics = 1, action = nil, var1 = 0, var2 = 0, nextstate = S_FASTLINE5}
-- states[S_FASTLINE5] = {sprite = SPR_FAST, frame = FF_PAPERSPRITE|FF_FULLBRIGHT|4, tics = 1, action = nil, var1 = 0, var2 = 0, nextstate = S_NULL}
states[S_FASTLINE1] = {sprite = SPR_KART_SOAP_SPEEDLINE, frame = FF_PAPERSPRITE|FF_FULLBRIGHT, tics = 5, action = nil, var1 = 0, var2 = 0, nextstate = S_NULL}

-- states[S_DRIFTSPARK_A1] = {SPR_DRIF, FF_FULLBRIGHT|2, 2, nil, 0, 0, S_DRIFTSPARK_A2}
states[S_DRIFTSPARK_A1] = {SPR_DRIF, FF_FULLBRIGHT|2, 2, nil, 0, 0, S_DRIFTSPARK_A2}
states[S_DRIFTSPARK_A2] = {SPR_DRIF, FF_FULLBRIGHT|FF_TRANS20|2, 1, nil, 0, 0, S_DRIFTSPARK_A3}
states[S_DRIFTSPARK_A3] = {SPR_DRIF, FF_FULLBRIGHT|FF_TRANS50|2,   1, nil, 0, 0, S_NULL}
-- states[S_DRIFTSPARK_A2] = {SPR_DRIF, FF_FULLBRIGHT|FF_TRANS20|1, 1, nil, 0, 0, S_DRIFTSPARK_A3}
-- states[S_DRIFTSPARK_A3] = {SPR_DRIF, FF_FULLBRIGHT|FF_TRANS50,   1, nil, 0, 0, S_NULL}

-- states[S_DRIFTSPARK_B1] = {SPR_DRIF, FF_FULLBRIGHT|1, 2, nil, 0, 0, S_DRIFTSPARK_A2}

-- states[S_DRIFTSPARK_C1] = {SPR_DRIF, FF_FULLBRIGHT, 2, nil, 0, 0, S_DRIFTSPARK_C2}
-- states[S_DRIFTSPARK_C2] = {SPR_DRIF, FF_FULLBRIGHT|FF_TRANS20, 1, nil, 0, 0, S_DRIFTSPARK_A3}

states[S_BUMP1] = {SPR_BUMP, FF_FULLBRIGHT, 3, nil, 0, 0, S_BUMP2}
states[S_BUMP2] = {SPR_BUMP, FF_FULLBRIGHT|1, 3, nil, 0, 0, S_BUMP3}
states[S_BUMP3] = {SPR_BUMP, FF_FULLBRIGHT|2, 3, nil, 0, 0, S_NULL}

states[S_BRAKEDRIFT] = {SPR_BDRF, FF_FULLBRIGHT|FF_PAPERSPRITE|FF_ANIMATE|FF_ADD, -1, nil, 6-1, 2, S_BRAKEDRIFT}

states[S_FASTDUST1] = {SPR_DSHR, FF_PAPERSPRITE|FF_ANIMATE, 1*7, nil, 7-1, 1, S_NULL}

states[S_WIPEOUTTRAIL1] = {SPR_WIPD, 0|FF_ANIMATE, 3*5, nil, 5-1, 3, S_NULL}

mobjinfo[MT_BRAKEDRIFT] = {
	spawnstate = S_BRAKEDRIFT,		// spawnstate
	spawnhealth = 1000,				// spawnhealth
	reactiontime = 8,				// reactiontime
	radius = 8*FRACUNIT,			// radius
	height = 8*FRACUNIT,			// height
	dispoffset = 1,					// display offset
	MF_NOBLOCKMAP|MF_NOCLIP|MF_NOCLIPHEIGHT|MF_NOGRAVITY, // flags
}

--taken from blankart since they have the 2.2 palette
skincolors[SKINCOLOR_SAPPHIRE2] = {
    ramp = {0,128,129,131,133,135,149,150,152,154,156,158,159,253,254,31},
    chatcolor = V_BLUEMAP,
    accessible = false}

skincolors[SKINCOLOR_RASPBERRY2] = {
    ramp = {0,208,209,210,32,33,34,35,37,39,41,43,44,45,46,47},
    chatcolor = V_REDMAP,
    accessible = false}

skincolors[SKINCOLOR_KETCHUP2] = {
    ramp = {72,73,64,51,52,54,34,36,38,40,42,43,44,71,46,47},
    chatcolor = V_REDMAP,
    accessible = false}

skincolors[SKINCOLOR_PERIWINKLE2] = { --blue color?
	name = "Periwinkle2",
    ramp = {0,0,144,144,145,146,147,149,150,152,154,155,157,159,253,254},
    chatcolor = V_BLUEMAP,
    accessible = false}

skincolors[SKINCOLOR_INVINCFLASH] = {
	name = "Invincflash",
    ramp = {0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,12},
    chatcolor = V_REDMAP,
    accessible = false}


--respawning
freeslot("sfx_ddash","SPR_DEZL","S_DEZLASER")
states[S_DEZLASER] = {SPR_DEZL, FF_FULLBRIGHT|FF_PAPERSPRITE, 8, nil, 0, 0, S_NULL}

--2.2 mario invincibility
local function getrainbow(l2)
	return (SKINCOLOR_RUBY + ((l2 or leveltime) % (FIRSTSUPERCOLOR-SKINCOLOR_RUBY)))
end


local function K_GetKartSpeed(player, doboostpower)
	local k_speed = 150;
	local g_cc = FRACUNIT;
	local xspd = 3072;		// 4.6875 aka 3/64
	local kartspeed = player.kartspeed or 0;
	local finalspeed;

	if (doboostpower and not player.kartstuff[k_pogospring] and not P_IsObjectOnGround(player.mo))
		return (75*mapobjectscale); // air speed cap
	end
	local ccv = FU + (gamespeed-1)*12288
	g_cc = ccv + xspd
-- 	if gamespeed == 0
-- 		g_cc = 53248 + xspd; //  50cc =  81.25 + 4.69 =  85.94%
-- 	elseif gamespeed == 2
-- 		g_cc = 77824 + xspd; // 150cc = 118.75 + 4.69 = 123.44%
-- 	else
-- 		g_cc = 65536 + xspd; // 100cc = 100.00 + 4.69 = 104.69%
-- 	end

-- 	if (G_BattleGametype() and player.kartstuff[k_bumper] <= 0)
-- 		kartspeed = 1; end

	k_speed = $ + kartspeed*3; // 153 - 177

	finalspeed = FixedMul(FixedMul(k_speed<<14, g_cc), player.mo.scale);
	
	if (doboostpower)
		return FixedMul(finalspeed, player.kartstuff[k_boostpower]+player.kartstuff[k_speedboost]);
	end
	return finalspeed;
end
rawset(_G,"K_GetKartSpeed",K_GetKartSpeed)

local function K_GetKartAccel(player)
	local k_accel = 32; // 36;
	local kartspeed = player.kartspeed;
-- 	print(kartspeed)

-- 	if (G_BattleGametype() and player.kartstuff[k_bumper] <= 0)
-- 		kartspeed = 1;

	//k_accel = $ + 3 * (9 - kartspeed); // 36 - 60
	k_accel = $ + 4 * (9 - kartspeed); // 32 - 64

	return FixedMul(k_accel, FRACUNIT+player.kartstuff[k_accelboost]);
end


--k_kart.c
local function K_3dKartMovement(player,onground,forwardmove)
	local accelmax = 4000;
	local newspeed, oldspeed, finalspeed;
	local p_speed = K_GetKartSpeed(player, true);
	local p_accel = K_GetKartAccel(player);
	
	if (not onground) return 0; end // If the player isn't on the ground, there is no change in speed
	
	// ACCELCODE!!!1!11!
	oldspeed = R_PointToDist2(0, 0, player.rmomx, player.rmomy); // FixedMul(P_AproxDistance(player.rmomx, player.rmomy), player.mo.scale);
	if kart_rrmomentum.value and oldspeed > p_speed
		oldspeed = p_speed
	end
	newspeed = FixedDiv(FixedDiv(FixedMul(oldspeed, accelmax - p_accel) + FixedMul(p_speed, p_accel), accelmax), ORIG_FRICTION);

	if (player.kartstuff[k_pogospring]) // Pogo Spring minimum/maximum thrust
		local hscale = mapobjectscale /*+ (mapobjectscale - player.mo.scale)*/;
		local minspeed = 24*hscale;
		local maxspeed = 28*hscale;

		if (newspeed > maxspeed and player.kartstuff[k_pogospring] == 2)
			newspeed = maxspeed; end
		if (newspeed < minspeed)
			newspeed = minspeed; end
	end

	finalspeed = newspeed - oldspeed;

	// forwardmove is:
	//  50 while accelerating,
	//  25 while clutching,
	//   0 with no gas, and
	// -25 when only braking.

	finalspeed = $ * forwardmove/25;
	finalspeed = $ / 2;

	if (forwardmove < 0 and finalspeed > mapobjectscale*2)
		return finalspeed/2;
	elseif (forwardmove < 0)
		return -mapobjectscale/2;
	end
	
	if (finalspeed < 0)
		finalspeed = 0; end

	return finalspeed;
end

local function K_MomentumToFacing(player)
	local dangle = player.mo.angle - R_PointToAngle2(0, 0, player.mo.momx, player.mo.momy);

	if (dangle > ANGLE_180)
		dangle = InvAngle(dangle);
	end

	// If you aren't on the ground or are moving in too different of a direction don't do this
	if (player.mo.eflags & MFE_JUSTHITFLOOR)
		 // Just hit floor ALWAYS redirects
	elseif (not P_IsObjectOnGround(player.mo) or dangle > ANGLE_90)
		return;
	end
	
	P_Thrust(player.mo, player.mo.angle, player.speed - FixedMul(player.speed, player.mo.friction));
	player.mo.momx = FixedMul(player.mo.momx - player.cmomx, player.mo.friction) + player.cmomx;
	player.mo.momy = FixedMul(player.mo.momy - player.cmomy, player.mo.friction) + player.cmomy;
end


local function P_3dMovement(player)
	local cmd;
	local movepushangle, movepushsideangle; // Analog
	//INT32 topspeed, acceleration, thrustfactor;
	local movepushforward, movepushside = 0,0;
	local dangle; // replaces old quadrants bits
	//boolean dangleflip = false; // SRB2kart - toaster
	//fixed_t normalspd = FixedMul(player.normalspeed, player.mo.scale);
	local analogmove = false;
	local oldMagnitude, newMagnitude;
	local totalthrust = {x=0,y=0,z=0};

-- 	totalthrust.x = totalthrust.y = 0; // I forget if this is needed
	totalthrust.z = FRACUNIT*P_MobjFlip(player.mo)/3; // A bit of extra push-back on slopes

	// Get the old momentum; this will be needed at the end of the function! -SH
	oldMagnitude = R_PointToDist2(player.mo.momx - player.cmomx, player.mo.momy - player.cmomy, 0, 0);

	analogmove = false--player.pflags & PF_ANALOGMODE--P_AnalogMove(player);

	cmd = player.kmd;

	if ((player.exiting or mapreset) or (player.pflags & PF_STASIS) or player.kartstuff[k_spinouttimer]) // pw_introcam?
		cmd.forwardmove, cmd.sidemove = 0,0;
		if (player.kartstuff[k_sneakertimer])
			cmd.forwardmove = 50; end
	end
	
	if (not (player.pflags & PF_FORCESTRAFE) and not player.kartstuff[k_pogospring])
		cmd.sidemove = 0; end --$*4/50 end--

	if (analogmove)
		movepushangle = (cmd.angleturn<<16 /* not FRACBITS */);
	else
		if (player.kartstuff[k_drift] != 0)
			movepushangle = player.mo.angle-(ANGLE_45/5)*player.kartstuff[k_drift];
		elseif (player.kartstuff[k_spinouttimer] or player.kartstuff[k_wipeoutslow])	// if spun out, use the boost angle
			movepushangle = player.kartstuff[k_boostangle];
		else
			movepushangle = player.mo.angle;
		end
	end
	movepushsideangle = movepushangle-ANGLE_90;

	// cmomx/cmomy stands for the conveyor belt speed.
	if (player.onconveyor == 2) // Wind/Current
		//if (player.mo.z > player.mo.watertop or player.mo.z + player.mo.height < player.mo.waterbottom)
		if (not (player.mo.eflags & (MFE_UNDERWATER|MFE_TOUCHWATER)))
			player.cmomx, player.cmomy = 0,0; end
	elseif (player.onconveyor == 4 and not P_IsObjectOnGround(player.mo)) // Actual conveyor belt
		player.cmomx, player.cmomy = 0,0;
	elseif (player.onconveyor != 2 and player.onconveyor != 4
				and player.onconveyor != 1
	)
		player.cmomx, player.cmomy = 0,0;
	end

	player.rmomx = player.mo.momx - player.cmomx;
	player.rmomy = player.mo.momy - player.cmomy;

	// Calculates player's speed based on distance-of-a-line formula
	player.speed = R_PointToDist2(0, 0, player.rmomx, player.rmomy);

	// Monster Iestyn - 04-11-13
	// Quadrants are stupid, excessive and broken, let's do this a much simpler way!
	// Get delta angle from rmom angle and player angle first
	dangle = R_PointToAngle2(0,0, player.rmomx, player.rmomy) - player.mo.angle;
	if (dangle > ANGLE_180) //flip to keep to one side
		dangle = InvAngle(dangle);
		//dangleflip = true;
	end

	// anything else will leave both at 0, so no need to do anything else

	//{ SRB2kart 220217 - Toaster Code for misplaced thrust
	/*
	if (!player.kartstuff[k_drift]) // Not Drifting
	{
		angle_t difference = dangle/2;
		boolean reverse = (dangle >= ANGLE_90);

		if (dangleflip)
			difference = InvAngle(difference);

		if (reverse)
			difference = $ + ANGLE_180;

		P_InstaThrust(player.mo, player.mo.angle + difference, player.speed);
	}
	*/
	//}

	// When sliding, don't allow forward/back
	if (player.pflags & PF_SLIDING)
		cmd.forwardmove = 0;
	end

	// Do not let the player control movement if not onground.
	// SRB2Kart: pogo spring and speed bumps are supposed to control like you're on the ground
	local onground = (P_IsObjectOnGround(player.mo) or (player.kartstuff[k_pogospring]));

-- 	player.aiming = cmd.aiming<<FRACBITS;

	// Forward movement
	if (not ((player.exiting or mapreset) or (P_PlayerInPain(player) and not onground)))
		//movepushforward = cmd.forwardmove * (thrustfactor * acceleration);
		movepushforward = K_3dKartMovement(player, onground, cmd.forwardmove);
		
		// allow very small movement while in air for gameplay
		if (not onground) and not kart_rrmomentum.value
			movepushforward = $ >> 2; // proper air movement
		end

		// don't need to account for scale here with kart accel code
		//movepushforward = FixedMul(movepushforward, player.mo.scale);

		if (player.mo.kmovefactor != FRACUNIT) // Friction-scaled acceleration...
-- 			print(fixmul(player.mo.kmovefactor,fixdiv(ORIG_FRICTION,FU*29/32)))
			movepushforward = FixedMul(movepushforward, fixmul(player.mo.kmovefactor,fixdiv(ORIG_FRICTION,FU*29/32)));
		end

-- 		if cmd.forwardmove<0--(cmd.buttons & BT_BRAKE and !cmd.forwardmove) // SRB2kart - braking isn't instant
-- 			movepushforward = $ / 64; end

		if (cmd.forwardmove > 0)
			player.kartstuff[k_brakestop] = 0;
		elseif (player.kartstuff[k_brakestop] < 6) // Don't start reversing with brakes until you've made a stop first
			if (player.speed < 8*FRACUNIT)
				player.kartstuff[k_brakestop] = $ + 1; end
			movepushforward = 0;
		end
		
		totalthrust.x = $ + P_ReturnThrustX(player.mo, movepushangle, movepushforward);
		totalthrust.y = $ + P_ReturnThrustY(player.mo, movepushangle, movepushforward);
	elseif (not (player.kartstuff[k_spinouttimer]))
		K_MomentumToFacing(player);
	end

	// Sideways movement
	if (cmd.sidemove != 0 and not ((player.exiting or mapreset) or player.kartstuff[k_spinouttimer]))
		if (cmd.sidemove > 0)
			movepushside = (cmd.sidemove * FRACUNIT/128) + FixedDiv(player.speed, K_GetKartSpeed(player, true));
		else
			movepushside = (cmd.sidemove * FRACUNIT/128) - FixedDiv(player.speed, K_GetKartSpeed(player, true));
		end

		totalthrust.x = $ + P_ReturnThrustX(player.mo, movepushsideangle, movepushside);
		totalthrust.y = $ + P_ReturnThrustY(player.mo, movepushsideangle, movepushside);
	end

-- 	if ((totalthrust.x or totalthrust.y)
-- 		and player.mo.standingslope and (not (player.mo.standingslope.flags & SL_NOPHYSICS)) and abs(player.mo.standingslope.zdelta) > FRACUNIT/2)
-- 		// Factor thrust to slope, but only for the part pushing up it!
-- 		// The rest is unaffected.
-- 		angle_t thrustangle = R_PointToAngle2(0, 0, totalthrust.x, totalthrust.y)-player.mo.standingslope.xydirection;

-- 		if (player.mo.standingslope.zdelta < 0) // Direction goes down, so thrustangle needs to face toward
-- 			if (thrustangle < ANGLE_90 or thrustangle > ANGLE_270)
-- 				P_QuantizeMomentumToSlope(&totalthrust, player.mo.standingslope);
-- 			end
-- 		else // Direction goes up, so thrustangle needs to face away
-- 			if (thrustangle > ANGLE_90 and thrustangle < ANGLE_270)
-- 				P_QuantizeMomentumToSlope(&totalthrust, player.mo.standingslope);
-- 			end
-- 		end
-- 	end

	player.mo.momx = $ + totalthrust.x;
	player.mo.momy = $ + totalthrust.y;
	
	if (not onground) and kart_rrmomentum.value
		local airspeedcap = (50*mapobjectscale);
		local speed = R_PointToDist2(0, 0, player.mo.momx, player.mo.momy);
		if (speed > airspeedcap)
			local newspeed = speed - ((speed - airspeedcap) / 32);
			player.mo.momx = FixedMul(FixedDiv(player.mo.momx, speed), newspeed);
			player.mo.momy = FixedMul(FixedDiv(player.mo.momy, speed), newspeed);
		end
	end


	// Time to ask three questions:
	// 1) Are we over topspeed?
	// 2) If "yes" to 1, were we moving over topspeed to begin with?
	// 3) If "yes" to 2, are we now going faster?

	// If "yes" to 3, normalize to our initial momentum; this will allow thoks to stay as fast as they normally are.
	// If "no" to 3, ignore it; the player might be going too fast, but they're slowing down, so let them.
	// If "no" to 2, normalize to topspeed, so we can't suddenly run faster than it of our own accord.
	// If "no" to 1, we're not reaching any limits yet, so ignore this entirely!
	// -Shadow Hog
	if not kart_rrmomentum.value or not P_IsObjectOnGround(player.mo)
		newMagnitude = R_PointToDist2(player.mo.momx - player.cmomx, player.mo.momy - player.cmomy, 0, 0);
		if (newMagnitude > K_GetKartSpeed(player, true)) //topspeed)
			local tempmomx, tempmomy;
			if (oldMagnitude > K_GetKartSpeed(player, true) and (onground or kart_rrmomentum.value)) // SRB2Kart: onground check for air speed cap
				if (newMagnitude > oldMagnitude)
					tempmomx = FixedMul(FixedDiv(player.mo.momx - player.cmomx, newMagnitude), oldMagnitude);
					tempmomy = FixedMul(FixedDiv(player.mo.momy - player.cmomy, newMagnitude), oldMagnitude);
					player.mo.momx = tempmomx + player.cmomx;
					player.mo.momy = tempmomy + player.cmomy;
				end
				// else do nothing
			else
				tempmomx = FixedMul(FixedDiv(player.mo.momx - player.cmomx, newMagnitude), K_GetKartSpeed(player, true)); //topspeed)
				tempmomy = FixedMul(FixedDiv(player.mo.momy - player.cmomy, newMagnitude), K_GetKartSpeed(player, true)); //topspeed)
				player.mo.momx = tempmomx + player.cmomx;
				player.mo.momy = tempmomy + player.cmomy;
			end
		end
	end
end

// sets k_boostpower, k_speedboost, and k_accelboost to whatever we need it to be
local function sliptidehandling()
	return kart_booststacking.value and FU*7/8 or FU*5/4-FU
end

local function K_SpawnWipeoutTrail(mo, translucent)
	local dust;
	local aoff;

	assert(mo != nil);
	assert(mo.valid);

	if (mo.player)
		aoff = (mo.player.frameangle + ANGLE_180);
	else
		aoff = (mo.angle + ANGLE_180);
	end

	if ((leveltime / 2) & 1)
		aoff = $ - ANGLE_45;
	else
		aoff = $ + ANGLE_45;
	end

	dust = P_SpawnMobj(mo.x + FixedMul(24*mo.scale, cos(aoff)) + (P_RandomRange(-8,8) << FRACBITS),
		mo.y + FixedMul(24*mo.scale, sin(aoff)) + (P_RandomRange(-8,8) << FRACBITS),
		mo.z, MT_THOK);--WIPEOUTTRAIL);

	dust.state = S_WIPEOUTTRAIL1
	dust.target = mo;
	dust.angle = R_PointToAngle2(0,0,mo.momx,mo.momy);
	dust.scale = mo.scale;
	K_FlipFromObject(dust, mo);

	if (translucent) // offroad effect
		dust.momx = mo.momx/2;
		dust.momy = mo.momy/2;
		dust.momz = mo.momz/2;
	end

	if (translucent)
		dust.flags2 = $ | MF2_SHADOW;
	end
end
rawset(_G,"K_SpawnWipeoutTrail",K_SpawnWipeoutTrail)

local function K_GetKartBoostPower(player)
	local boostpower = FRACUNIT;
	local speedboost, accelboost, handleboost = 0,0,0;
	local numboosts = 0
	
	local maxmetabolismincrease = FU/2
	local metabolism = FU - ((9-player.kartweight)*maxmetabolismincrease/8)
	local SLIPTIDEHANDLING = sliptidehandling()

	if (player.kartstuff[k_spinouttimer] and player.kartstuff[k_wipeoutslow] == 1) // Slow down after you've been bumped
		player.kartstuff[k_boostpower],player.kartstuff[k_speedboost],player.kartstuff[k_accelboost] = 0,0,0;
		return;
	end
	
	// Offroad is separate, it's difficult to factor it in with a variable value anyway.
	if (not(player.kartstuff[k_invincibilitytimer] or player.kartstuff[k_hyudorotimer] or player.kartstuff[k_sneakertimer])
		and player.kartstuff[k_offroad] >= 0)
		boostpower = FixedDiv(boostpower, player.kartstuff[k_offroad] + FRACUNIT);
	end

	if (player.kartstuff[k_bananadrag] > TICRATE)
		boostpower = (4*boostpower)/5;
	end
	
	local function ADDBOOST(s,a,h)
		if kart_booststacking.value --ring racers behavior
			numboosts = $ + 1
			speedboost = $ + fixdiv(s,FU+(metabolism*(numboosts-1)))
			accelboost = $ + fixdiv(a,FU+(metabolism*(numboosts-1)))
		else --srb2kart behavior
			speedboost = max($,s)
			accelboost = max($,a)
		end
		handleboost = max($,h or 0)
	end

	// Banana drag/offroad dust
	if (boostpower < FRACUNIT
		and player.mo and P_IsObjectOnGround(player.mo)
		and player.speed > 0
		and not player.spectator)
		K_SpawnWipeoutTrail(player.mo, true);
		if (leveltime % 6 == 0)
			S_StartSound(player.mo, sfx_cdfm70);
		end
	end

	if (player.kartstuff[k_sneakertimer]) // Sneaker
		local s = 0
		if gamespeed == 0
				s = 53740+768;
		elseif gamespeed == 2
				s = 17294+768;
		else
				s = 32768;
		end
		for i=1,(kart_booststacking.value and player.kartstuff[k_numsneakers] or 1)
			ADDBOOST(kart_booststacking.value and FU/2 or s, 8*FRACUNIT, SLIPTIDEHANDLING) // + 50% top speed, + 800% acceleration
		end
	end

	if (player.kartstuff[k_invincibilitytimer]) // Invincibility
		local extra = 0
		if kart_rrpoweritems.value
			extra = FU / 1400 * (player.kartstuff[k_invincibilitytimer] - --[[i haven't played through ring racers enough to know what most of these "powerups" are]] 0)
		end
		if kart_booststacking.value
			ADDBOOST(3*FRACUNIT/8+extra, 3*FRACUNIT, SLIPTIDEHANDLING/2); // + 37.5% top speed, + 300% acceleration
		else
			ADDBOOST(3*FRACUNIT/8+extra, 3*FRACUNIT, SLIPTIDEHANDLING); // + 37.5% top speed, + 300% acceleration
		end
	end

	if player.rubberband --homemade rubberband
		local factor = fixdiv(player.rubberband*rubberbandstrength,FU*rubberbandtime)
		factor = $ + (player.kartstuff[k_position]-1)*rubberbandstrength/8
		ADDBOOST(factor/3,factor/2,factor/5)
	end

	if (player.kartstuff[k_growshrinktimer] > 0) // Grow
		local extra = 0
		if kart_rrpoweritems.value == 2
			extra = FU / 400 * (player.kartstuff[k_growshrinktimer] - --[[i haven't played through ring racers enough to know what most of these "powerups" are]] 0)
		end
		if kart_booststacking.value
			ADDBOOST(FRACUNIT/5,extra,SLIPTIDEHANDLING/2)
		else
			speedboost = max(speedboost, FRACUNIT/5); // + 20%
			accelboost = max($, extra)
			if kart_rrpoweritems.value
				handleboost = max($,SLIPTIDEHANDLING/2)
			end
		end
	end
	
	if player.wavedashboost
		ADDBOOST(
			ease.incubic(player.wavedashpower,0,FU*8/10),
			ease.incubic(player.wavedashpower,0,FU*4),
			sliptidehandling()*2/5)
	end

	if (player.kartstuff[k_startboost]) // Startup Boost
		ADDBOOST(FRACUNIT/4, 6*FRACUNIT); // + 25% top speed, + 600% acceleration
	end

	if (player.kartstuff[k_driftboost]) // Drift Boost
		ADDBOOST(FRACUNIT/4, 4*FRACUNIT); // + 25% top speed, + 400% acceleration
	end
	
	if (player.kartstuff[k_ringboost]) // Ring Boost
		local rb = player.kartstuff[k_ringboost] * FRACUNIT;
		ADDBOOST(
			FRACUNIT/4 + FixedMul(FRACUNIT / 1750, rb),
			4*FRACUNIT,
			ease.incubic(min(FRACUNIT, rb / (TICRATE*12)), 0, 2*SLIPTIDEHANDLING/5))
	end

	// don't average them anymore, this would make a small boost and a high boost less useful
	// just take the highest we want instead

	player.kartstuff[k_boostpower] = boostpower;

	// value smoothing
	if (speedboost > player.kartstuff[k_speedboost])
		player.kartstuff[k_speedboost] = speedboost;
	else
		player.kartstuff[k_speedboost] = $ + (speedboost - player.kartstuff[k_speedboost])/(TICRATE/2);
	end
	
	player.kartstuff[k_accelboost] = accelboost;
	player.kartstuff[k_handleboost] = handleboost;
	player.kartstuff[k_numboosts] = numboosts;
end

--port of butteredslope just because orig_friction is different
local function K_ButteredSlope(mo)
	local thrust;

	if (not mo.standingslope)
		return;
	end

	if (mo.standingslope.flags & SL_NOPHYSICS)
		return; // No physics, no butter.
	end
	
-- 	if (mo.flags & (MF_NOCLIPHEIGHT|MF_NOGRAVITY))
-- 		return; // don't slide down slopes if you can't touch them or you're not affected by gravity

	if (mo.player)
		if (abs(mo.standingslope.zdelta) < FRACUNIT/4 and not(mo.player.pflags & PF_SPINNING))
			return; // Don't slide on non-steep slopes unless spinning
		end

		if (abs(mo.standingslope.zdelta) < FRACUNIT/2 and not(mo.player.rmomx or mo.player.rmomy))
			return; // Allow the player to stand still on slopes below a certain steepness
		end
	end

	thrust = sin(mo.standingslope.zangle) * 15 / 16 * -P_MobjFlip(mo);

-- 	if (mo.player and (mo.player.pflags & PF_SPINNING)) { --karts cannot spin
-- 		fixed_t mult = 0;
-- 		if (mo.momx or mo.momy) {
-- 			angle_t angle = R_PointToAngle2(0, 0, mo.momx, mo.momy) - mo.standingslope.xydirection;

-- 			if (P_MobjFlip(mo) * mo.standingslope.zdelta < 0)
-- 				angle ^= ANGLE_180;

-- 			mult = FINECOSINE(angle >> ANGLETOFINESHIFT);
-- 		}

-- 		thrust = FixedMul(thrust, FRACUNIT*2/3 + mult/8);
-- 	}

	if (mo.momx or mo.momy) // Slightly increase thrust based on the object's speed
		thrust = FixedMul(thrust, FRACUNIT+P_AproxDistance(mo.momx, mo.momy)/16);
	end
	// This makes it harder to zigzag up steep slopes, as well as allows greater top speed when rolling down

	// Let's get the gravity strength for the object...
	thrust = FixedMul(thrust, abs(P_GetMobjGravity(mo)*8/5));

	// ... and its friction against the ground for good measure (divided by original friction to keep behaviour for normal slopes the same).
	thrust = FixedMul(thrust, FixedDiv(mo.friction, ORIG_FRICTION));

	P_Thrust(mo, mo.standingslope.xydirection, thrust);
end


local function K_RRMoveAnimation(player,pain)
	local cmd = player.kmd;
	local mo = player.mo
	local l = (leveltime%2)
	mo.spriteyoffset = 0
	// Standing frames - S_KART_STND1   S_KART_STND1_L   S_KART_STND1_R
	if player.kartdead or pain
		mo.sprite2 = SPR2_SPIN
		mo.frame = A
	elseif (player.speed == 0)
		if (player.driftturn < 0)
			mo.sprite2 = SPR2_STIR
			mo.frame = A + l
		elseif (player.driftturn > 0)
			mo.sprite2 = SPR2_STIL
			mo.frame = A + l
		elseif (player.driftturn == 0)
			mo.sprite2 = SPR2_STIN
			mo.frame = A + l
		end
	// Drifting Left - S_KART_DRIFT1_L
	elseif (player.kartstuff[k_drift] > 0)-- and P_IsObjectOnGround(mo))me%2)
		player.drawangle = $ + ANGLE_45
		if player.driftturn > 0
			mo.sprite2 = SPR2_DRLI
			mo.frame = A + (leveltime%4)
		elseif player.driftturn
			mo.sprite2 = SPR2_DRLO
			mo.frame = A + l
		else
			mo.sprite2 = SPR2_DRLN
			mo.frame = A + l
		end
	// Drifting Right - S_KART_DRIFT1_R
	elseif (player.kartstuff[k_drift] < 0)-- and P_IsObjectOnGround(mo))
		player.drawangle = $ - ANGLE_45
		if player.driftturn < 0
			mo.sprite2 = SPR2_DRRI
			mo.frame = A + (leveltime%4)
		elseif player.driftturn
			mo.sprite2 = SPR2_DRRO
			mo.frame = A + l
		else
			mo.sprite2 = SPR2_DRRN
			mo.frame = A + l
		end
	// Run frames - S_KART_RUN1   S_KART_RUN1_L   S_KART_RUN1_R
	elseif (player.speed > (20*mo.scale))
		if (player.driftturn < 0)
			mo.sprite2 = SPR2_FSTR
			mo.frame = A + l
		elseif (player.driftturn > 0)
			mo.sprite2 = SPR2_FSTL
			mo.frame = A + l
		elseif (player.driftturn == 0)
			mo.sprite2 = SPR2_FSTN
			mo.frame = A + l
		end
	// Walk frames - S_KART_WALK1   S_KART_WALK1_L   S_KART_WALK1_R
	elseif (player.speed <= (20*mo.scale))
		if (player.driftturn < 0)
			mo.sprite2 = SPR2_SLWR
			mo.frame = A + l
		elseif (player.driftturn > 0)
			mo.sprite2 = SPR2_SLWL
			mo.frame = A + l
		elseif (player.driftturn == 0)
			mo.sprite2 = SPR2_SLWN
			mo.frame = A + l
		end
	end
end

local function K_KartMoveAnimation(player,t,pain)
	local cmd = player.kmd;
	local mo = player.mo
	local l = (leveltime%2)
	mo.spriteyoffset = 0
	// Standing frames - S_KART_STND1   S_KART_STND1_L   S_KART_STND1_R
	if player.kartdead or pain
		mo.frame = Q
		if t == DAT_TAKISKART mo.frame = J end
		if t == DAT_TAKISKART_L mo.frame = Q end
	elseif (player.speed == 0)
		if (player.driftturn < 0) --r
			mo.frame = E + l
			if t == DAT_TAKISKART mo.frame = l and H or G end
		elseif (player.driftturn > 0) --l
			mo.frame = C + l
			if t == DAT_TAKISKART mo.frame = l and E or D end
		elseif (player.driftturn == 0)
			mo.frame = A + l
			if t == DAT_TAKISKART mo.frame = l and B or A end
		end
	// Drifting Left - S_KART_DRIFT1_L
	elseif (player.kartstuff[k_drift] > 0 and (P_IsObjectOnGround(mo) or kart_triangledash.value))
		mo.frame = M + l
		if t == DAT_TAKISKART mo.frame = l and K or L end
	// Drifting Right - S_KART_DRIFT1_R
	elseif (player.kartstuff[k_drift] < 0 and (P_IsObjectOnGround(mo) or kart_triangledash.value))
		mo.frame = O + l
		if t == DAT_TAKISKART mo.frame = l and M or N end
	// Run frames - S_KART_RUN1   S_KART_RUN1_L   S_KART_RUN1_R
	elseif (player.speed > (20*mo.scale))
		if (player.driftturn < 0)
			mo.frame = l and L or E
			if t == DAT_TAKISKART mo.frame = l and I or G end
		elseif (player.driftturn > 0)
			mo.frame = l and K or C
			if t == DAT_TAKISKART mo.frame = l and F or D end
		elseif (player.driftturn == 0)
			mo.frame = l and J or A
			if t == DAT_TAKISKART mo.frame = l and C or A end
		end
	// Walk frames - S_KART_WALK1   S_KART_WALK1_L   S_KART_WALK1_R
	elseif (player.speed <= (20*mo.scale))
		if (player.driftturn < 0)
			mo.frame = l and I or L
			if t == DAT_TAKISKART mo.frame = l and I or G mo.spriteyoffset = l*FU end
		elseif (player.driftturn > 0)
			mo.frame = l and H or K
			if t == DAT_TAKISKART mo.frame = l and F or D mo.spriteyoffset = l*FU end
		elseif (player.driftturn == 0)
			mo.frame = l and G or J
			if t == DAT_TAKISKART mo.frame = l and C or A mo.spriteyoffset = l*FU end
		end
	end
end

local function undoslope(mo)
	local thrust

	if (not mo.standingslope)
		return
	end

	if (mo.standingslope.flags & SL_NOPHYSICS)
		return // No physics, no butter.
	end
	
	if (mo.flags & (MF_NOCLIPHEIGHT|MF_NOGRAVITY))
		return // don't slide down slopes if you can't touch them or you're not affected by gravity
	end

	if (mo.player)
		if (abs(mo.standingslope.zdelta) < FRACUNIT/4 and not(mo.player.pflags & PF_SPINNING))
			return // Don't slide on non-steep slopes unless spinning
		end

		if (abs(mo.standingslope.zdelta) < FRACUNIT/2 and not(mo.player.rmomx or mo.player.rmomy))
			return // Allow the player to stand still on slopes below a certain steepness
		end
	end

	thrust = sin(mo.standingslope.zangle) * 3 / 2 * -P_MobjFlip(mo)

	if (mo.momx or mo.momy) // Slightly increase thrust based on the object's speed
		thrust = FixedMul(thrust, FRACUNIT+P_AproxDistance(mo.momx, mo.momy)/16)
	end
	// This makes it harder to zigzag up steep slopes, as well as allows greater top speed when rolling down

	// Let's get the gravity strength for the object...
	thrust = FixedMul(thrust, abs(P_GetMobjGravity(mo)))

	// ... and its friction against the ground for good measure (divided by original friction to keep behaviour for normal slopes the same).
-- 	thrust = FixedMul(thrust, FixedDiv(mo.friction, FU*29/32));

	P_Thrust(mo, mo.standingslope.xydirection, -thrust);
end


// Adds gravity flipping to an object relative to its master and shifts the z coordinate accordingly.
local function K_FlipFromObject(mo, master)
	mo.eflags = (mo.eflags & ~MFE_VERTICALFLIP)|(master.eflags & MFE_VERTICALFLIP);
	mo.flags2 = (mo.flags2 & ~MF2_OBJECTFLIP)|(master.flags2 & MF2_OBJECTFLIP);

	if (mo.eflags & MFE_VERTICALFLIP)
		mo.z = $ + master.height - FixedMul(master.scale, mo.height);
	end
end
rawset(_G,"K_FlipFromObject",K_FlipFromObject)

local function K_MatchGenericExtraFlags(mo, master)
	// flipping
	// handle z shifting from there too. This is here since there's no reason not to flip us if needed when we do this anyway;
	K_FlipFromObject(mo, master);

	// visibility (usually for hyudoro)
	mo.flags2 = (mo.flags2 & ~MF2_DONTDRAW)|(master.flags2 & MF2_DONTDRAW);
-- 	mo.eflags = (mo.eflags & ~MFE_DRAWONLYFORP1)|(master.eflags & MFE_DRAWONLYFORP1);
-- 	mo.eflags = (mo.eflags & ~MFE_DRAWONLYFORP2)|(master.eflags & MFE_DRAWONLYFORP2);
-- 	mo.eflags = (mo.eflags & ~MFE_DRAWONLYFORP3)|(master.eflags & MFE_DRAWONLYFORP3);
-- 	mo.eflags = (mo.eflags & ~MFE_DRAWONLYFORP4)|(master.eflags & MFE_DRAWONLYFORP4);
end
rawset(_G,"K_MatchGenericExtraFlags",K_MatchGenericExtraFlags)

local function K_DriftDustHandling(spawner)
	local anglediff;
	local spawnrange = spawner.radius>>FRACBITS;

	if (not P_IsObjectOnGround(spawner) or leveltime % 2 != 0)
		return;
	end

	if (spawner.player)
-- 		if spawner.player.kartstuff[k_drift]--(spawner.player.pflags & PF_SKIDDOWN)
-- 			anglediff = abs((spawner.angle - spawner.player.drawangle));
-- 			if (leveltime % 6 == 0)
-- 				S_StartSound(spawner, sfx_screec); // repeated here because it doesn't always happen to be within the range when this is the case
-- 			end
-- 		else
			local playerangle = spawner.angle;

			--kart
			if (spawner.player.speed < 5*mapobjectscale)--<<FRACBITS)
				return;
			end

			if (spawner.player.kmd.forwardmove < 0)
				playerangle = $ + ANGLE_180;
			end

			anglediff = abs((playerangle - R_PointToAngle2(0, 0, spawner.player.rmomx, spawner.player.rmomy)));
-- 		end
	else
		if (P_AproxDistance(spawner.momx, spawner.momy) < 5*mapobjectscale)--<<FRACBITS)
			return;
		end

		anglediff = abs((spawner.angle - R_PointToAngle2(0, 0, spawner.momx, spawner.momy)));
	end

-- 	if (anglediff > ANGLE_180)
-- 		anglediff = InvAngle(anglediff);
-- 	end

	if (anglediff > ANG10*4) // Trying to turn further than 40 degrees
		local spawnx = P_RandomRange(-spawnrange, spawnrange)<<FRACBITS;
		local spawny = P_RandomRange(-spawnrange, spawnrange)<<FRACBITS;
		local speedrange = 2;
		local dust = P_SpawnMobj(spawner.x + spawnx, spawner.y + spawny, spawner.z, MT_DUST);--MT_DRIFTDUST);
		dust.momx = FixedMul(fixdiv(spawner.momx,mapobjectscale) + (P_RandomRange(-speedrange, speedrange)<<FRACBITS), 3*(spawner.scale)/4);
		dust.momy = FixedMul(fixdiv(spawner.momy,mapobjectscale) + (P_RandomRange(-speedrange, speedrange)<<FRACBITS), 3*(spawner.scale)/4);
		dust.momz = P_MobjFlip(spawner) * (P_RandomRange(1, 4) * (spawner.scale));
		dust.state = S_DRIFTDUST1
		dust.scale = spawner.scale/2;
		dust.destscale = spawner.scale * 3;
		dust.scalespeed = spawner.scale/12;

		if (leveltime % 6 == 0)
			S_StartSound(spawner, sfx_screec);
		end

		K_MatchGenericExtraFlags(dust, spawner);
	end
end

local function K_GetKartDriftSparkValue(player)
-- 	local kartspeed = (G_BattleGametype() and player.kartstuff[k_bumper] <= 0)
-- 		and 1
-- 		or player.kartspeed;
	local kartspeed = player.kartspeed
	return (26*4 + kartspeed*2 + (9 - player.kartweight))*8;
end
rawset(_G,"K_GetKartDriftSparkValue",K_GetKartDriftSparkValue)

local function K_SpawnDriftSparks(player)
	local newx;
	local newy;
	local spark;
	local travelangle;
	local i;
	local driftturn = player.driftturn

-- 	I_Assert(player != NULL);
-- 	I_Assert(player.mo != NULL);
-- 	I_Assert(!P_MobjWasRemoved(player.mo));

	if (leveltime % 2 == 1)
		return;
	end

	--kart
-- 	if (not P_IsObjectOnGround(player.mo))
-- 		return;
-- 	end
	
	if (not player.kartstuff[k_drift] or player.kartstuff[k_driftcharge] < K_GetKartDriftSparkValue(player))
		return;
	end
	
	travelangle = player.mo.angle-(ANGLE_45/5)*player.kartstuff[k_drift];

	for i=0,1
		newx = player.mo.x + P_ReturnThrustX(player.mo, travelangle + ((i&1) and -1 or 1)*ANGLE_135, FixedMul(32*FRACUNIT, player.mo.scale));
		newy = player.mo.y + P_ReturnThrustY(player.mo, travelangle + ((i&1) and -1 or 1)*ANGLE_135, FixedMul(32*FRACUNIT, player.mo.scale));
		spark = P_SpawnMobj(newx, newy, player.mo.z, MT_THOK);--MT_DRIFTSPARK);
-- 		spark.state = S_DRIFTSPARK_B1
		spark.state = S_DRIFTSPARK_A1

		spark.target = player.mo;
		spark.angle = travelangle-(ANGLE_45/5)*player.kartstuff[k_drift];
		spark.scale = player.mo.scale;

		spark.momx = player.mo.momx/2;
		spark.momy = player.mo.momy/2;
		//spark.momz = player.mo.momz/2;

		if (player.kartstuff[k_driftcharge] >= K_GetKartDriftSparkValue(player)*4)
			spark.color = getrainbow();
		elseif (player.kartstuff[k_driftcharge] >= K_GetKartDriftSparkValue(player)*2)
			if (player.kartstuff[k_driftcharge] <= (K_GetKartDriftSparkValue(player)*2)+(24*3))
				spark.color = SKINCOLOR_RASPBERRY2; // transition
			else
				spark.color = SKINCOLOR_KETCHUP2;
			end
		else
			spark.color = SKINCOLOR_SAPPHIRE2;
		end

		if ((player.kartstuff[k_drift] > 0 and driftturn > 0) // Inward drifts
			or (player.kartstuff[k_drift] < 0 and driftturn < 0))
			if ((player.kartstuff[k_drift] < 0 and (i & 1))
				or (player.kartstuff[k_drift] > 0 and not (i & 1)))
-- 				spark.state = S_DRIFTSPARK_A1;
				spark.scale = $*5/4
			elseif ((player.kartstuff[k_drift] < 0 and not (i & 1))
				or (player.kartstuff[k_drift] > 0 and (i & 1)))
-- 				spark.state = S_DRIFTSPARK_C1;
				spark.scale = $*4/5
			end
		elseif ((player.kartstuff[k_drift] > 0 and driftturn < 0) // Outward drifts
			or (player.kartstuff[k_drift] < 0 and driftturn > 0))
			if ((player.kartstuff[k_drift] < 0 and (i & 1))
				or (player.kartstuff[k_drift] > 0 and not (i & 1)))
-- 				spark.state = S_DRIFTSPARK_C1;
				spark.scale = $*4/5
			elseif ((player.kartstuff[k_drift] < 0 and not (i & 1))
				or (player.kartstuff[k_drift] > 0 and (i & 1)))
-- 				spark.state = S_DRIFTSPARK_A1;
				spark.scale = $*5/4
			end
		end

		spark.momz = -spark.scale*4
		spark.destscale = 0
		spark.scalespeed = spark.scale/4
		K_MatchGenericExtraFlags(spark, player.mo);
	end
end

local function K_SpawnAIZDust(player)
	local newx;
	local newy;
	local spark;
	local travelangle;

-- 	I_Assert(player != NULL);
-- 	I_Assert(player.mo != NULL);
-- 	I_Assert(!P_MobjWasRemoved(player.mo));

	if (leveltime % 2 == 1)
		return;
	end

	if (not P_IsObjectOnGround(player.mo))
		return;
	end

	travelangle = R_PointToAngle2(0, 0, player.mo.momx, player.mo.momy);
	//S_StartSound(player.mo, sfx_s3k47);

	do
		newx = player.mo.x + P_ReturnThrustX(player.mo, travelangle - (player.kartstuff[k_aizdriftstrat]*ANGLE_45), FixedMul(24*FRACUNIT, player.mo.scale));
		newy = player.mo.y + P_ReturnThrustY(player.mo, travelangle - (player.kartstuff[k_aizdriftstrat]*ANGLE_45), FixedMul(24*FRACUNIT, player.mo.scale));
		spark = P_SpawnMobj(newx, newy, player.mo.z, MT_THOK);--MT_AIZDRIFTSTRAT);

		spark.state = S_KARTAIZDRIFTSTRAT;
		spark.angle = travelangle+(player.kartstuff[k_aizdriftstrat]*ANGLE_90);
		spark.scale = ((3*player.mo.scale)>>2);

		spark.momx = (6*player.mo.momx)/5;
		spark.momy = (6*player.mo.momy)/5;
		//spark.momz = player.mo.momz/2;

		K_MatchGenericExtraFlags(spark, player.mo);
	end
end

local function K_SpawnBrakeDriftSparks(player) // Be sure to update the mobj thinker case too!
	local sparks;

-- 	I_Assert(player != NULL);
-- 	I_Assert(player.mo != NULL);
-- 	I_Assert(!P_MobjWasRemoved(player.mo));

	// Position & etc are handled in its thinker, and its spawned invisible.
	// This avoids needing to dupe code if we don't need it.
	sparks = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z, MT_BRAKEDRIFT);
	sparks.target = player.mo;
	sparks.scale = player.mo.scale;
	K_MatchGenericExtraFlags(sparks, player.mo);
	sparks.flags2 = $ | MF2_DONTDRAW;
end


local MIN_WAVEDASH_CHARGE = TICRATE*11/16*9
local HIDEWAVEDASHCHARGE = 60

local function K_IsLosingWavedash(player)
	if (not player.kartstuff[k_aizdriftstrat] and player.wavedash < MIN_WAVEDASH_CHARGE)
		return true;
	end
	if (not player.kartstuff[k_aizdriftstrat] and player.kartstuff[k_drift] == 0
		and P_IsObjectOnGround(player.mo) and player.kartstuff[k_sneakertimer] == 0
		and player.kartstuff[k_driftboost] == 0)
		return true;
	end
	return false;
end

local function K_KartDrift(player, onground)
	local minspeed = (10 * player.mo.scale);
	local dsone = K_GetKartDriftSparkValue(player);
	local dstwo = dsone*2;
	local dsthree = dstwo*2;
	local driftturn = player.driftturn

	// Grown players taking yellow spring panels will go below minspeed for one tic,
	// and will then wrongdrift or have their sparks removed because of this.
	// This fixes this problem.
	if (player.kartstuff[k_pogospring] == 2 and player.mo.scale > mapobjectscale)
		minspeed = FixedMul(10<<FRACBITS, mapobjectscale);
	end

	// Drifting is actually straffing + automatic turning.
	// Holding the Jump button will enable drifting.

	// Drift Release (Moved here so you can't "chain" drifts)
	if ((player.kartstuff[k_drift] != -5 and player.kartstuff[k_drift] != 5) and (onground or kart_triangledash.value))
		// or (player.kartstuff[k_drift] >= 1 and player.kartstuff[k_turndir] != 1) or (player.kartstuff[k_drift] <= -1 and player.kartstuff[k_turndir] != -1))
		if player.kartstuff[k_driftcharge] < dsone
			--nothing
		else
			local ang = R_PointToAngle2(0,0,player.mo.momx,player.mo.momy)
			S_StartSound(player.mo, sfx_s23c);
			local factor = FU
			if kart_haste.value
				local accel = max(9-player.kartspeed-player.kartweight/2,0)
				factor = FU + accel*(FU*4/100)
			end
			//K_SpawnDashDustRelease(player);
			if player.kartstuff[k_driftcharge] >= dsone and player.kartstuff[k_driftcharge] < dstwo
				player.kartstuff[k_driftboost] = max($,fixmul(20*FU,factor)/FU);
				if kart_triangledash.value
					if not onground
						--rr gray spark thrusts speed/8
						P_Thrust(player.mo,ang,player.speed/3)
						player.mo.momz = $ - player.speed/2*P_MobjFlip(player.mo)
					end
				end
			elseif player.kartstuff[k_driftcharge] < dsthree
				player.kartstuff[k_driftboost] = max($,fixmul(50*FU,factor)/FU);
				if kart_triangledash.value
					if not onground
						P_Thrust(player.mo,ang,player.speed/2)
						player.mo.momz = $ - player.speed/2*P_MobjFlip(player.mo)
					end
				end
			elseif player.kartstuff[k_driftcharge] >= dsthree
				player.kartstuff[k_driftboost] = max($,fixmul(125*FU,factor)/FU);
				if kart_triangledash.value
					if not onground
						--rr blue spark thrusts speed
						P_Thrust(player.mo,ang,player.speed/4*5)
						player.mo.momz = $ - player.speed/2*P_MobjFlip(player.mo)
					end
				end
			end
		end
		player.kartstuff[k_driftcharge] = 0;
	end

	// Drifting: left or right?
	if ((driftturn > 0) and player.speed > minspeed and player.kartstuff[k_jmp] == 1
		and (player.kartstuff[k_drift] == 0 or player.kartstuff[k_driftend] == 1)) // and player.kartstuff[k_drift] != 1)
		// Starting left drift
		player.kartstuff[k_drift] = 1;
		player.kartstuff[k_driftend] = 0;
	elseif ((driftturn < 0) and player.speed > minspeed and player.kartstuff[k_jmp] == 1
		and (player.kartstuff[k_drift] == 0 or player.kartstuff[k_driftend] == 1)) // and player.kartstuff[k_drift] != -1)
		// Starting right drift
		player.kartstuff[k_drift] = -1;
		player.kartstuff[k_driftend] = 0;
	elseif (player.kartstuff[k_jmp] == 0) // or player.kartstuff[k_turndir] == 0)
		// drift is not being performed so if we're just finishing set driftend and decrement counters
		if (player.kartstuff[k_drift] > 0)
			player.kartstuff[k_drift] = $ - 1;
			player.kartstuff[k_driftend] = 1;
		elseif (player.kartstuff[k_drift] < 0)
			player.kartstuff[k_drift] = $ + 1;
			player.kartstuff[k_driftend] = 1;
		else
			player.kartstuff[k_driftend] = 0;
		end
	end


	// Incease/decrease the drift value to continue drifting in that direction
	if (player.kartstuff[k_spinouttimer] == 0 and player.kartstuff[k_jmp] == 1 and player.kartstuff[k_drift] != 0)
		local driftadditive = 0;
		if onground --kart
			driftadditive = 24;
			
			if (player.kartstuff[k_drift] >= 1) // Drifting to the left
				player.kartstuff[k_drift] = $ + 1;
				if (player.kartstuff[k_drift] > 5)
					player.kartstuff[k_drift] = 5;
				end

				if (driftturn > 0) // Inward
					driftadditive = $ + abs(driftturn)/100;
				end
				if (driftturn < 0) // Outward
					driftadditive = $ - abs(driftturn)/75;
				end
			elseif (player.kartstuff[k_drift] <= -1) // Drifting to the right
				player.kartstuff[k_drift] = $ - 1--;
				if (player.kartstuff[k_drift] < -5)
					player.kartstuff[k_drift] = -5;
				end

				if (driftturn < 0) // Inward
					driftadditive = $ + abs(driftturn)/100;
				end
				if (driftturn > 0) // Outward
					driftadditive = $ - abs(driftturn)/75;
				end
			end

			// Disable drift-sparks until you're going fast enough
			if (player.kartstuff[k_getsparks] == 0 or (player.kartstuff[k_offroad] and not player.kartstuff[k_invincibilitytimer] and not player.kartstuff[k_hyudorotimer] and not player.kartstuff[k_sneakertimer]))
				driftadditive = 0;
			end
			if (player.speed > minspeed*2)
				player.kartstuff[k_getsparks] = 1;
			end

			// Sound whenever you get a different tier of sparks
			if (P_IsLocalPlayer(player) // UGHGHGH...
				and ((player.kartstuff[k_driftcharge] < dsone and player.kartstuff[k_driftcharge]+driftadditive >= dsone)
				or (player.kartstuff[k_driftcharge] < dstwo and player.kartstuff[k_driftcharge]+driftadditive >= dstwo)
				or (player.kartstuff[k_driftcharge] < dsthree and player.kartstuff[k_driftcharge]+driftadditive >= dsthree)))
				//S_StartSound(player.mo, sfx_s3ka2);
				S_StartSoundAtVolume(player.mo, sfx_s3ka2, 192); // Ugh...
			end
		end
		
		// This spawns the drift sparks
		if (player.kartstuff[k_driftcharge] + driftadditive >= dsone) and (onground or kart_triangledash.value)
			K_SpawnDriftSparks(player);
		end
		
		if onground or kart_triangledash.value
			player.kartstuff[k_driftcharge] = $ + driftadditive;
			player.kartstuff[k_driftend] = 0;
		end
	end

	// Stop drifting
	if (player.kartstuff[k_spinouttimer] > 0 or player.speed < minspeed)
		player.kartstuff[k_drift], player.kartstuff[k_driftcharge] = 0,0;
		player.kartstuff[k_aizdriftstrat], player.kartstuff[k_brakedrift] = 0,0;
		player.kartstuff[k_getsparks] = 0;
	end

	local condition = player.kartstuff[k_sneakertimer]
	if kart_rrpoweritems.value
		condition = player.kartstuff[k_handleboost] >= sliptidehandling()/2
	end
	if ((not condition)
	or (not driftturn)
	or (not player.kartstuff[k_aizdriftstrat])
	or (driftturn > 0) != (player.kartstuff[k_aizdriftstrat] > 0))
		if (not player.kartstuff[k_drift])
			player.kartstuff[k_aizdriftstrat] = 0;
		else
			player.kartstuff[k_aizdriftstrat] = ((player.kartstuff[k_drift] > 0) and 1 or -1);
		end
	elseif (player.kartstuff[k_aizdriftstrat] and not player.kartstuff[k_drift])
		K_SpawnAIZDust(player);
		
		if kart_rrsliptide.value
			local ac = fixint(fixdiv(abs(player.driftturn)*FU,(KART_FULLTURN*9/10)*FU)*10)
			ac = min(10,max($,1))
			
			player.wavedash = $ + ac
		end
	end
	
	if not (player.kartstuff[k_aizdriftstrat] and not player.kartstuff[k_drift])
		if K_IsLosingWavedash(player) and player.wavedash
			--sfx
			player.wavedashdelay = $ + 1
			if player.wavedashdelay > TICRATE/2
				if player.wavedash > HIDEWAVEDASHCHARGE
					local ma = 2*FU
					local mi = FU
					local ps = ma-mi
					
					local mip = 2*1 + (9-9) --what are these formulas
					local map = 2*9 + (9-1)
					local pes = map-mip
					local pe = 2*player.kartspeed + (9-player.kartweight) - mi
					
					local pr = fixdiv(pe*FU,pes*FU)
					local p = ma - fixmul(pr,ps)
					player.wavedashboost = $ + fixint(fixmul(p,player.wavedash/10*FU))
					player.wavedashpower = min(FU*player.wavedash/MIN_WAVEDASH_CHARGE,FU)
					--sfx
				end
				player.wavedash = 0
				player.wavedashdelay = 0
			end
		end
	else
		player.wavedashdelay = 0
		--sfx
	end

	if (player.kartstuff[k_drift]
		and ((player.kmd.forwardmove<0) or not (player.kmd.forwardmove > 0))
-- 		and ((player.kmd.buttons & BT_BRAKE)
-- 		or not (player.kmd.buttons & BT_ACCELERATE))
		and P_IsObjectOnGround(player.mo))
		if (not player.kartstuff[k_brakedrift])
			K_SpawnBrakeDriftSparks(player);
		end
		player.kartstuff[k_brakedrift] = 1;
	else
		player.kartstuff[k_brakedrift] = 0;
	end
end

local function K_SpawnDashDustRelease(player)
	local newx;
	local newy;
	local dust;
	local travelangle;
	local i;

-- 	I_Assert(player != NULL);
-- 	I_Assert(player.mo != NULL);
-- 	I_Assert(!P_MobjWasRemoved(player.mo));

	if (not P_IsObjectOnGround(player.mo))
		return;
	end

	if (not player.speed and not player.kartstuff[k_startboost])
		return;
	end

	travelangle = player.mo.angle;

	if (player.kartstuff[k_drift] or player.kartstuff[k_driftend])
		travelangle = $ - (ANGLE_45/5)*player.kartstuff[k_drift];
	end

	for i=0,1
		newx = player.mo.x + P_ReturnThrustX(player.mo, travelangle + ((i&1) and -1 or 1)*ANGLE_90, FixedMul(48*FRACUNIT, player.mo.scale));
		newy = player.mo.y + P_ReturnThrustY(player.mo, travelangle + ((i&1) and -1 or 1)*ANGLE_90, FixedMul(48*FRACUNIT, player.mo.scale));
		dust = P_SpawnMobj(newx, newy, player.mo.z, MT_THOK);--FASTDUST);
		dust.state = S_FASTDUST1

		dust.target = player.mo;
		dust.angle = travelangle - ((i&1) and -1 or 1)*ANGLE_45;
		dust.scale = player.mo.scale;
-- 		P_SetScale(dust, player.mo.scale);

		dust.momx = 3*player.mo.momx/5;
		dust.momy = 3*player.mo.momy/5;
		//dust.momz = 3*player.mo.momz/5;

		K_MatchGenericExtraFlags(dust, player.mo);
	end
end
rawset(_G,"K_SpawnDashDustRelease",K_SpawnDashDustRelease)

local function K_SpawnBoostTrail(player)
	local newx;
	local newy;
	local ground;
	local flame;
	local travelangle;
	local i;
	local sh = 14*FU

-- 	assert(player != nil);
-- 	assert(player.mo != nil);
-- 	assert(player.mo.valid);

	if (not P_IsObjectOnGround(player.mo)
		or player.kartstuff[k_hyudorotimer] != 0)
-- 		or (G_BattleGametype() and player.kartstuff[k_bumper] <= 0 and player.kartstuff[k_comebacktimer]))
		return;
	end

	if (player.mo.eflags & MFE_VERTICALFLIP)
		ground = player.mo.ceilingz - FixedMul(sh, player.mo.scale);
	else
		ground = player.mo.floorz;
	end

	if (player.kartstuff[k_drift] != 0)
		travelangle = player.mo.angle;
	else
		travelangle = R_PointToAngle2(0, 0, player.rmomx, player.rmomy);
	end

	for i=0,2-1
		newx = player.mo.x + P_ReturnThrustX(player.mo, travelangle + ((i&1) and -1 or 1)*ANGLE_135, FixedMul(24*FRACUNIT, player.mo.scale));
		newy = player.mo.y + P_ReturnThrustY(player.mo, travelangle + ((i&1) and -1 or 1)*ANGLE_135, FixedMul(24*FRACUNIT, player.mo.scale));
		if (player.mo.standingslope)
			ground = P_GetZAt(player.mo.standingslope, newx, newy);
			if (player.mo.eflags & MFE_VERTICALFLIP)
				ground = $ - FixedMul(sh, player.mo.scale);
			end
		end
		flame = P_SpawnMobj(newx, newy, ground, MT_THOK);--SNEAKERTRAIL);
		flame.state = S_KARTFIRE1

		flame.target = player.mo;
		flame.angle = travelangle;
		flame.fuse = TICRATE*2;
-- 		flame.destscale = player.mo.scale;
-- 		P_SetScale(flame, player.mo.scale);
		flame.scale = player.mo.scale
		// not K_MatchGenericExtraFlags so that a stolen sneaker can be seen
		K_FlipFromObject(flame, player.mo);

		flame.momx = 8; --?
		P_XYMovement(flame);
		if (not flame.valid)
			continue;
		end

		if (player.mo.eflags & MFE_VERTICALFLIP)
			if (flame.z + flame.height < flame.ceilingz)
				P_RemoveMobj(flame);
			end
		elseif (flame.z > flame.floorz)
			P_RemoveMobj(flame);
		end
	end
end

// Engine Sounds.
local function K_UpdateEngineSounds(player, cmd)
	local numsnds = 13;

	local closedist = 160*FRACUNIT;
	local fardist = 1536*FRACUNIT;

	local dampenval = 48; // 255 * 48 = close enough to FRACUNIT/6

	local class, s, w; // engine class number

	local volume = 255;
	local volumedampen = FRACUNIT;

	local targetsnd = 0;
	local i;

	s = (player.kartspeed - 1) / 3;
	w = (player.kartweight - 1) / 3;

	s = min(max($,0),2)
	w = min(max($,0),2)
-- #define LOCKSTAT(stat) \
-- 	if (stat < 0) { stat = 0; } \
-- 	if (stat > 2) { stat = 2; }
-- 	LOCKSTAT(s);
-- 	LOCKSTAT(w);
-- #undef LOCKSTAT

	class = s + (3*w);

	if (leveltime < 8 or player.spectator or player.exiting)
		// Silence the engines, and reset sound number while we're at it.
		player.kartstuff[k_enginesnd] = 0;
		return;
	end

-- #if 0
-- 	if ((leveltime % 8) != ((player-players) % 8)) // Per-player offset, to make engines sound distinct!
-- #else
	if (leveltime % 8)
-- #endif
		// .25 seconds of wait time between each engine sound playback
		return;
	end

	if ((leveltime >= starttime-(2*TICRATE) and leveltime <= starttime) or (player.kartstuff[k_respawn] == 1))
		// Startup boosts only want to check for BT_ACCELERATE being pressed.
		targetsnd = ((cmd.forwardmove > 0) and 12 or 0);
	else
		// Average out the value of forwardmove and the speed that you're moving at.
		targetsnd = (((6 * cmd.forwardmove) / 25) + ((player.speed / mapobjectscale) / 5)) / 2;
	end

	if (targetsnd < 0)
		targetsnd = 0;
	end
	if (targetsnd > 12)
		targetsnd = 12;
	end

	if (player.kartstuff[k_enginesnd] < targetsnd)
		player.kartstuff[k_enginesnd] = $ + 1;
	end
	if (player.kartstuff[k_enginesnd] > targetsnd)
		player.kartstuff[k_enginesnd] = $ - 1;
	end

	if (player.kartstuff[k_enginesnd] < 0)
		player.kartstuff[k_enginesnd] = 0;
	end
	if (player.kartstuff[k_enginesnd] > 12)
		player.kartstuff[k_enginesnd] = 12;
	end

	// This code calculates how many players (and thus, how many engine sounds) are within ear shot,
	// and rebalances the volume of your engine sound based on how far away they are.

	// This results in multiple things:
	// - When on your own, you will hear your own engine sound extremely clearly.
	// - When you were alone but someone is gaining on you, yours will go quiet, and you can hear theirs more clearly.
	// - When around tons of people, engine sounds will try to rebalance to not be as obnoxious.

	for p in players.iterate
		local thisvol = 0;
		local dist;

		if (not p.mo)
			// This player doesn't exist.
			continue;
		end

		if (p.spectator or p.exiting)
			// This player isn't playing an engine sound.
			continue;
		end

		if (player == p or p == displayplayer)
			// Don't dampen yourself!
			continue;
		end

		dist = P_AproxDistance(
			P_AproxDistance(
				player.mo.x - p.mo.x,
				player.mo.y - p.mo.y),
				player.mo.z - p.mo.z) / 2;

		dist = FixedDiv(dist, mapobjectscale);

		if (dist > fardist)
			// ENEMY OUT OF RANGE !
			continue;
		elseif (dist < closedist)
			// engine sounds' approx. range
			thisvol = 255;
		else
			thisvol = (15 * ((closedist - dist) / FRACUNIT)) / ((fardist - closedist) >> (FRACBITS+4));
		end

		volumedampen = $ + (thisvol * dampenval);
	end

	if (volumedampen > FRACUNIT)
		volume = FixedDiv(volume * FRACUNIT, volumedampen) / FRACUNIT;
	end

	if (volume <= 0)
		// Don't need to play the sound at all.
		return;
	end
	
	S_StartSoundAtVolume(player.mo, (sfx_krta00 + player.kartstuff[k_enginesnd]) + (class * numsnds), volume);
end

--unused right now
local function K_CheckOffroadCollide(player,mo)
	local subsector = mo.subsector
	
	local flip = P_MobjFlip(mo)
	local floorpic = flip>0 and "floorpic" or "ceilingpic"
	local toppic = flip>0 and "toppic" or "bottompic"
	
	local floorheight = flip>0 and "floorheight" or "ceilingheight"
	
	local f_slope = flip>0 and "f_slope" or "c_slope"
	
	if mo.floorrover and flip>0 return mo.floorrover[toppic] end
	if mo.ceilingrover and flip<0 return mo.ceilingrover[toppic] end
	
	local floor
	
	local hectorheight = INT32_MIN*flip
	
	searchBlockmap("lines",function(mo,line)
		local x,y = P_ClosestPointOnLine(mo.x,mo.y,line)
		if inrange_dist(x,line.v1.x,line.v2.x)<=mo.radius and inrange_dist(y,line.v1.y,line.v2.y)<=mo.radius and inrange(x,mo.x-mo.radius,mo.x+mo.radius) and inrange(y,mo.y-mo.radius,mo.y+mo.radius)
			if line.frontsector
				local v = line.frontsector
				local floorz = P_GetZAt(v[f_slope],mo.x,mo.y,v[floorheight])
				if floorz*flip > hectorheight*flip
					floor = v[floorpic]
					hectorheight = floorz
				end
			end
			
			if line.backsector
				local v = line.backsector
				local floorz = P_GetZAt(v[f_slope],mo.x,mo.y,v[floorheight])
				if floorz*flip > hectorheight*flip
					floor = v[floorpic]
					hectorheight = floorz
				end
			end
		end
	end,mo,mo.x-mo.radius,mo.x+mo.radius,mo.y-mo.radius,mo.y+mo.radius)
	
-- 	if floor
-- 		print("found "..floor.." z "..hectorheight/FU)
-- 	end
	
	return floor or subsector.sector[floorpic] or "GFZFLR01"
end



--https://git.do.srb2.org/KartKrew/Kart-Public/-/blob/next/src/k_kart.c#L4652 (K_KartPlayerThink)
--https://git.do.srb2.org/KartKrew/Kart-Public/-/blob/next/src/p_user.c#L5760 (P_MovePlayer calls 3dmovement)
--https://git.do.srb2.org/KartKrew/Kart-Public/-/blob/next/src/p_user.c#L8679 (P_PlayerThink calls moveplayer and then kartplayerthink)
--https://git.do.srb2.org/KartKrew/Kart-Public/-/blob/next/src/k_kart.c#L1823 (K_GetKartBoostPower)
local function kartinit(player,mo)
	if not player.kartstuff or mo.kartangle == nil
		player.kartstuff = {}
		
		player.driftturn = 0
		player.turnheld = 0
		for i=k_position,k_kartstuffamount
			player.kartstuff[i] = 0
		end
		
		player.klastbuttons = 0
-- 		player.kartstuff[k_itemtype] = KITEM_POGOSPRING
-- 		player.kartstuff[k_itemamount] = -1
-- 	end
	
-- 	if mo.kartangle == nil --on spawn
		local pn = player == secondarydisplayplayer and 2 or 1
		mo.kartangle = mo.angle
		player.turnheld = 0
		if player == consoleplayer or player == secondarydisplayplayer
			localkartangle[pn] = mo.angle
			dlocalkartangle[pn] = 0
-- 			slocalkartangle = mo.angle
-- 			prevlocalkartangle = mo.angle
		end
		
		if mapobjectscale ~= FU
			mo.scale = mapobjectscale
		end
		
		player.wavedash = 0
		player.wavedashdelay = 0
		player.wavedashboost = 0
		player.wavedashpower = 0
		
		player.kartflashing = 0
	end
end
rawset(_G,"kartinit",kartinit)

--returns player prevcheck, player nextcheck, if applicable p prevcheck, p nextcheck
local function calculateposition(player,p,x,y,z)
	if z == nil
		x,y,z = player.mo.x,player.mo.y,player.mo.z
	end
	
	local ppcd, pncd, ipcd, incd;
	ppcd, pncd, ipcd, incd = 0, 0, 0, 0;
	local pmo, imo;
	local pc,nc = 0,0
	local pc2,nc2 = 0,0
	
	local mo = waypointcap
	while mo and mo.valid
		pmo = P_AproxDistance(P_AproxDistance(	mo.x - x,
												mo.y - y),
												mo.z - z) / FRACUNIT;

		if (mo.health == player.starpostnum and (not mo.movecount or mo.movecount == player.laps+1))
			pc = $ + pmo;
			ppcd = $ + 1;
		end
		if (mo.health == (player.starpostnum + 1) and (not mo.movecount or mo.movecount == player.laps+1))
			nc = $ + pmo;
			pncd = $ + 1;
		end
		
		if p
			imo = P_AproxDistance(P_AproxDistance(	mo.x - p.mo.x,
													mo.y - p.mo.y),
													mo.z - p.mo.z) / FRACUNIT;
			if (mo.health == p.starpostnum and (not mo.movecount or mo.movecount == p.laps+1))
				pc2 = $ + imo;
				ipcd = $ + 1;
			end
			if (mo.health == (p.starpostnum + 1) and (not mo.movecount or mo.movecount == p.laps+1))
				nc2 = $ + imo;
				incd = $ + 1;
			end
		end
		
		--kart
		mo = $.tracer
	end

	if (ppcd > 1) pc = $ / ppcd; end
	if (pncd > 1) nc = $ / pncd; end
	
	if p
		if (ipcd > 1) pc2 = $ / ipcd; end
		if (incd > 1) nc2 = $ / incd; end
	end
	
	return pc,nc,pc2,nc2
end
rawset(_G,"calculateposition",calculateposition)

local function K_KartUpdatePosition(player)
	local position = 1;
	local oldposition = player.kartstuff[k_position];
-- 	local ppcd, pncd, ipcd, incd;
-- 	local pmo, imo;
-- 	local mo;

	if (player.spectator or not player.mo)
		return;
	end

	for p in players.iterate
		if (not p.valid or p.spectator or not p.mo or not p.kart or not p.kartstuff)
			continue;
		end

		if true--(G_RaceGametype())
			if ((((p.starpostnum) + (numstarposts + 1) * p.laps) >
				((player.starpostnum) + (numstarposts + 1) * player.laps)))
				position = $ + 1;
			elseif (((p.starpostnum) + (numstarposts+1)*p.laps) ==
				((player.starpostnum) + (numstarposts+1)*player.laps))
				
				player.kartstuff[k_prevcheck], player.kartstuff[k_nextcheck],
					p.kartstuff[k_prevcheck], p.kartstuff[k_nextcheck] =
					calculateposition(player,p)

				if ((p.kartstuff[k_nextcheck] > 0 or player.kartstuff[k_nextcheck] > 0) and not player.exiting)
					if ((p.kartstuff[k_nextcheck] - p.kartstuff[k_prevcheck]) <
						(player.kartstuff[k_nextcheck] - player.kartstuff[k_prevcheck]))
						position = $ + 1;
					end
				elseif (not player.exiting)
					if (p.kartstuff[k_prevcheck] > player.kartstuff[k_prevcheck])
						position = $ + 1;
					end
				else
					if (p.starposttime < player.starposttime)
						position = $ + 1;
					end
				end
			end
-- 		elseif (G_BattleGametype())
-- 			if (player.exiting) // End of match standings
-- 				if (p.marescore > player.marescore) // Only score matters
-- 					position = $ + 1;
-- 				end
-- 			else
-- 				if (p.kartstuff[k_bumper] == player.kartstuff[k_bumper] and p.marescore > player.marescore)
-- 					position = $ + 1;
-- 				elseif (p.kartstuff[k_bumper] > player.kartstuff[k_bumper])
-- 					position = $ + 1;
-- 				end
-- 			end
		end
	end

	if (leveltime < starttime or oldposition == 0)
		oldposition = position;
	end

	if (oldposition != position) // Changed places?
		player.kartstuff[k_positiondelay] = 10; // Position number growth
	end

	player.kartstuff[k_position] = position;
end


local function kart_on(player,node)
	if player and (player == server or IsPlayerAdmin(player)) and tonumber(node) ~= nil
		node = tonumber($)
		if node >= 0 and node <= 31 and players[node]
			player = players[node]
		end
	end
	
	if player and player.mo and data[player.mo.skin]
		local dat = data[player.mo.skin]
		if P_IsValidSprite2(player.mo,dat.spr2)
			player.kart = not $
			if player.kart
				kartinit(player,player.mo)
			end
		else
			CONS_Printf(player,"No kart sprites?!")
		end
	else
		CONS_Printf(player,"No kart data or player")
	end
end

COM_AddCommand("kart_on",kart_on)

local function kart_restat(player,speed,weight)
	if player and player.mo
		if player.kart
			if not weight
				CONS_Printf(player,"kart_restat <speed> <weight>: Change the statistics of your kart. Will persist through characters, but not through disabling karts.")
				return
			end
			speed = tonumber($)
			weight = tonumber($)
			
			if speed ~= nil and weight ~= nil
				player.kartspeed = speed
				player.kartweight = weight
				player.restat = true
				CONS_Printf(player,"Speed is now "..speed..", weight is now "..weight)
			else
				CONS_Printf(player,"Please provide a valid speed/weight (1-9 each).")
			end
		else
			CONS_Printf(player,"You must be in a kart to use this.")
		end
	end
end
COM_AddCommand("kart_restat",kart_restat)

local BT_DRIFT = BT_SPIN--|BT_CUSTOM3
local BT_STOMP = BT_CUSTOM1

local function anim(player)
	local mo = player.mo
	local dat = data[mo.skin]
	
	if dat.t ~= DAT_STAND
		mo.frame = A
		mo.tics = -1
		mo.state = S_PLAY_STND
		mo.sprite2 = dat.spr2
		if player.followmobj
			player.followmobj.alpha = 0
		end
		if mo.radius ~= fixmul(dat.radius or 24*FU,mo.scale)
			mo.radius = fixmul(dat.radius or 24*FU,mo.scale)
		end
	end
	mo.translation = dat.translation and dat.translation.."_"..R_GetNameByColor(mo.color) or nil
	if player.kmd
		mo.spriteyoffset = 0
		local pain = player.kartstuff[k_spinouttimer] > 0
		local function DoRoll()
			if player.kartstuff[k_drift] > 0
				player.drawangle = $ + ANGLE_45
			elseif player.kartstuff[k_drift] < 0
				player.drawangle = $ - ANGLE_45
			end
			
			local target = K_GetKartTurnValue(player, player.driftturn)
			if player.kartstuff[k_drift]
				target = $ + player.kartstuff[k_drift]*200
			end
			mo.spriteroll = ease.linear(FU/6, mo.kart_spriteroll or 0, fixangle(target*FU/64))
			mo.kart_spriteroll = mo.spriteroll
		end
		
		if dat.t == DAT_STAND
			player.runspeed = fixdiv(K_GetKartSpeed(player),mo.scale)/5*3
			DoRoll()
			if player.kartstuff[k_drift]
				if mo.state ~= S_PLAY_ROLL
					mo.state = S_PLAY_ROLL
				end
			elseif mo.state == S_PLAY_ROLL
				mo.state = S_PLAY_STND
			end
		elseif dat.t == DAT_RINGRACERS
			K_RRMoveAnimation(player, pain)
		elseif dat.t == DAT_RUSHCHARS then
			local l = (leveltime%2)
			mo.sprite2 = SPR2_JSKI
			DoRoll()
			if (player.speed == 0)
				mo.frame = A + l
-- 				if (player.driftturn < 0) --r
-- 					mo.frame = E + l
-- 				elseif (player.driftturn > 0) --l
-- 					mo.frame = C + l
-- 				elseif (player.driftturn == 0)
-- 				end
			// Run frames - S_KART_RUN1   S_KART_RUN1_L   S_KART_RUN1_R
			elseif (player.speed > (20*mo.scale))
				mo.frame = A
				mo.spriteyoffset = l*FU / 2
			// Walk frames - S_KART_WALK1   S_KART_WALK1_L   S_KART_WALK1_R
			elseif (player.speed <= (20*mo.scale))
				mo.frame = A
				mo.spriteyoffset = l*FU
			end
		else
			K_KartMoveAnimation(player, dat.t, pain)
		end
	end
end

local function K_InitWavedashIndicator(player)
	local new;

	if (player.wavedashIndicator and player.wavedashIndicator.valid)
		P_RemoveMobj(player.wavedashIndicator);
	end

	new = P_SpawnMobjFromMobj(player.mo, 0, 0, 0, MT_THOK);--WAVEDASH);
	new.sprite = SPR_SLPT
	new.frame = A
	new.tics = -1

	player.wavedashIndicator = new;
	new.target = player.mo;
	new.alpha = 0;
end

local function K_UpdateWavedashIndicator(player)
	local mobj = nil;

	if (player.wavedashIndicator == nil or not player.wavedashIndicator.valid)
		K_InitWavedashIndicator(player);
		return;
	end

	mobj = player.wavedashIndicator;
	local momentumAngle = R_PointToAngle2(0,0,player.mo.momx,player.mo.momy);

	P_MoveOrigin(mobj, player.mo.x - FixedMul(40*mapobjectscale, cos(momentumAngle)),
		player.mo.y - FixedMul(40*mapobjectscale, sin(momentumAngle)),
		player.mo.z + (player.mo.height / 2));
	mobj.angle = momentumAngle + ANGLE_90;
-- 	P_SetScale(mobj, 3 * player.mo.scale / 2);
	mobj.scale = player.mo.scale

	// No stored boost (or negligible enough that it might be a mistake)
	if (player.wavedash <= HIDEWAVEDASHCHARGE)
		mobj.alpha = 0;
		mobj.spritexscale = 0
		mobj.spriteyscale = 0
-- 		mobj.frame = 7;
		return;
	end

	mobj.alpha = FU;

	local chargeFrame = 7 - min(7, (player.wavedash) / 100);
	local decayFrame = min(7, (player.wavedashdelay) / 2);
	local s = 7-(mobj.spritexscale*7/FU)
	if (max(chargeFrame, decayFrame) > s)
-- 		mobj.frame = $ + 1;
		mobj.spritexscale = max($ - FU/7,0)
	elseif (max(chargeFrame, decayFrame) < s)
-- 		mobj.frame = $ - 1;
		mobj.spritexscale = min($ + FU/7,FU)
	end
	mobj.spriteyscale = mobj.spritexscale

-- 	mobj.renderflags = $ & ~RF_TRANSMASK;
	mobj.alpha = FU
	mobj.renderflags = $ | RF_PAPERSPRITE;

	if (player.wavedash < MIN_WAVEDASH_CHARGE)
		mobj.alpha = FU/2;
	end

	if (K_IsLosingWavedash(player))
		// Decay timer's ticking
		mobj.rollangle = $ + 3*ANG30/4;
		if (leveltime % 2 == 0)
			mobj.alpha = FU/2;
		end
	else
		// Storing boost
		mobj.rollangle = $ + 3*ANG15/4;
	end
end

local function K_RespawnChecker(player)
	local cmd = player.kmd;

	if (player.spectator)
		return;
	end

	if (player.kartstuff[k_respawn] > 1)
		player.kartstuff[k_respawn] = $ - 1;
		player.mo.momz = 0;
		player.kartflashing = 2;
		player.powers[pw_nocontrol] = 2;
		if (leveltime % 8 == 0)
			if (not mapreset)
				S_StartSound(player.mo, sfx_s3kcas);
			end

			for i=0,8-1
				local mo;
				local newangle;
				local newx, newy, newz;

				newangle = FixedAngle(((360/8)*i)*FRACUNIT);
				newx = player.mo.x + P_ReturnThrustX(player.mo, newangle, 31<<FRACBITS); // does NOT use scale, since this effect doesn't scale properly
				newy = player.mo.y + P_ReturnThrustY(player.mo, newangle, 31<<FRACBITS);
				if (player.mo.eflags & MFE_VERTICALFLIP)
					newz = player.mo.z + player.mo.height;
				else
					newz = player.mo.z;
				end

				mo = P_SpawnMobj(newx, newy, newz, MT_THOK);--DEZLASER);
				if (mo)
					mo.state = S_DEZLASER
					if (player.mo.eflags & MFE_VERTICALFLIP)
						mo.eflags = $ | MFE_VERTICALFLIP;
					end
					mo.target = player.mo;
					mo.angle = newangle+ANGLE_90;
					mo.momz = (8<<FRACBITS) * P_MobjFlip(player.mo);
					--P_SetScale(mo, (mo.destscale = FRACUNIT));
				end
			end
		end
	elseif (player.kartstuff[k_respawn] == 1)
		if (player.kartstuff[k_growshrinktimer] < 0)
			player.mo.scalespeed = mapobjectscale/TICRATE;
			player.mo.destscale = (6*mapobjectscale)/8;
-- 			if (cv_kartdebugshrink.value and not modeattacking and not player.bot)
-- 				player.mo.destscale = (6*player.mo.destscale)/8;
-- 			end
		end

		if (not P_IsObjectOnGround(player.mo) and not mapreset)
			player.kartflashing = K_GetKartFlashing(player);

			// Sal: The old behavior was stupid and prone to accidental usage.
			// Let's rip off Mania instead, and turn this into a Drop Dash!

			if (cmd.forwardmove >= 25)--buttons & BT_ACCELERATE)
				player.kartstuff[k_dropdash] = $ + 1;
			else
				player.kartstuff[k_dropdash] = 0;
			end

			if (player.kartstuff[k_dropdash] == TICRATE/4)
				S_StartSound(player.mo, sfx_ddash);
			end

			if ((player.kartstuff[k_dropdash] >= TICRATE/4)
				and (player.kartstuff[k_dropdash] & 1))
				player.mo.colorized = true;
			else
				player.mo.colorized = false;
			end
		else
			if ((cmd.forwardmove >= 25--[[buttons & BT_ACCELERATE]]) and (player.kartstuff[k_dropdash] >= TICRATE/4))
				S_StartSound(player.mo, sfx_s23c);
				player.kartstuff[k_startboost] = 50;
				K_SpawnDashDustRelease(player);
			end
			player.mo.colorized = false;
			player.kartstuff[k_dropdash] = 0;
			player.kartstuff[k_respawn] = 0;
		end
	end
end


--disable this hook for feet sonic
addHook("PostThinkFrame",do
	for player in players.iterate
		if player and player.kart and player.mo and player.mo.valid and player.mo.health
			anim(player)
			
			K_MoveHeldObjects(player)
			K_UpdateWavedashIndicator(player)
		end
	end
end)

addHook("PlayerThink",function(player)
-- 	player.kart = false
	if player and player.mo and player.mo.valid and player.mo.kartpointangle == nil --hak2
		player.mo.kartpointx,player.mo.kartpointy,player.mo.kartpointz,player.mo.kartpointangle = player.mo.x,player.mo.y,player.mo.z,player.mo.angle
	end
	
	if player and player.mo and (player.kart or gametype == GT_RACE or mapheaderinfo[gamemap].forcekarts) and data[player.mo.skin]
		local dat = data[player.mo.skin]
		if P_IsValidSprite2(player.mo,dat.spr2)
			local mo = player.mo
			player.kart = true
			kartinit(player,mo)
			mo.kartangle = player.cmd.angleturn*FU
			
			player.pflags = ($ | PF_JUMPSTASIS) & ~(PF_ANALOGMODE|PF_DIRECTIONCHAR|PF_SPINNING)
			
			mo.friction = ORIG_FRICTION--FU
			
			--floor friction fix
			if mo.kmovefactor ~= FU
				local km = fixmul(FU,fixdiv(FU*29/32,ORIG_FRICTION))
				mo.momx,mo.momy = fixdiv($1,km),fixdiv($2,km)
			end
			mo.angle = mo.kartangle
-- 			player.powers[pw_flashing] = 200
			
			if not player.restat
				player.kartspeed = dat.kartspeed
				player.kartweight = dat.kartweight
			end
			player.thrustfactor = 0
			player.acceleration = 0
			player.accelstart = 0
			player.normalspeed = 0
			player.marine = {}
			player.charability = CA_NONE
			player.charability2 = CA2_NONE
			player.charflags = SF_NOSKID|SF_NOJUMPSPIN|SF_NOJUMPDAMAGE
			player.powers[pw_underwater] = 0
			player.powers[pw_spacetime] = 0
			player.powers[pw_strong] = STR_PUNCH
			player.runspeed = 14*FU --for water running
			
			if (mo.eflags & MFE_JUSTHITFLOOR) and not P_GetPlayerControlDirection(player) and kart_keeplandspeed.value
				mo.momx,mo.momy = $1*2,$2*2
			end
			
			if (mo.eflags & MFE_SPRUNG)
				mo.momz = $*26/20 --approximate difference of srb2kart/srb2 springs
				mo.momx = $*26/20 --approximate difference of srb2kart/srb2 springs
				mo.momy = $*26/20 --approximate difference of srb2kart/srb2 springs
-- 				player.kartstuff[k_pogospring] = 1
			end
			
			local onground = P_IsObjectOnGround(mo)
			
			anim(player)
			
			
			if not player.kmd return end --wait for a prethinkframe before using kmd
			K_UpdateEngineSounds(player, player.kmd)
			
			--homemade rubberbanding with a vague idea of how ring racers does it
			player.rubberband = max(($ or 0)-(player.kartstuff[k_position] == 1 and 1 or 1),0)
			if player.bot and player.kartstuff[k_position] > 1
				for p in players.iterate
					if p and p.kart and not p.bot and p.mo and p.kartstuff[k_position] == 1
						player.rubberband = min($ + 2,rubberbandtime)
						break
					end
				end
			end
			
			if not P_IsObjectOnGround(mo) then
				if not mo.kart_stomping
				and (player.kmd.buttons & BT_STOMP) and not (player.klastbuttons & BT_STOMP) then
					mo.momz = $ * P_MobjFlip(mo)
					mo.momz = min($, -mo.scale * 16)
					mo.momz = $ * P_MobjFlip(mo)
					
					mo.kart_stomping = true
				end
				
				if mo.kart_stomping then
					mo.momz = $ * P_MobjFlip(mo)
					mo.momz = $ - mo.scale * 2
					mo.momz = $ * P_MobjFlip(mo)
				end
			else
				mo.kart_stomping = nil
			end
			
			player.lookback = ($ or 1) - 1
			if player.kmd.buttons & BT_CUSTOM2
				if player.lookback < 3-1
					player.awayviewtics = 0
				end
				player.lookback = 3
			elseif player.lookback == 3-1
				player.awayviewtics = 0
			end
			
			player.kartstuff[k_throwdir] = (player.kmd.buttons & BT_CAMLEFT and 1 or (player.kmd.buttons & BT_CAMRIGHT and -1 or 0))
			
			if (onground and player.kartstuff[k_pogospring])
				if (P_MobjFlip(mo)*mo.momz <= 0)
					player.kartstuff[k_pogospring] = 0;
				end
			end
			
			if not onground
				mo.momz = $ - P_GetMobjGravity(mo) + P_GetMobjGravity(mo)*8/5
			end
			
			player.frameangle = $ or 0
			
			if player.kartdead
				P_SetObjectMomZ(mo,-2*FU/3+P_GetMobjGravity(mo),true)
				mo.momx,mo.momy = 0,0
				player.frameangle = $ - ANGLE_22h
				player.drawangle = player.frameangle
				mo.z = $ + mo.momz
				player.kartdead = $ - 1
				if not player.kartdead
					mo.flags = mo.info.flags
					player.kartstuff[k_respawn] = 48
					local x,y,z,a = player.starpostx*FU,player.starposty*FU,player.starpostz*FU,player.starpostangle
					if not player.starpostnum and mo.kartpointangle ~= nil --hak
						x,y,z,a = mo.kartpointx,mo.kartpointy,mo.kartpointz,mo.kartpointangle
					end
					mo.angle = a
					mo.kartangle = a
					P_SetOrigin(mo,x,y,z+128*mapobjectscale)
					mo.momx,mo.momy,mo.momz = 0,0,0
					player.awayviewtics = 0
				end
				return
			elseif (player.kmd.buttons & BT_CUSTOM2) and kart_debuggeneral.value
				P_DamageMobj(mo,nil,nil,1,DMG_INSTAKILL)
			end
			
			if (player.kartstuff[k_pogospring])
				player.frameangle = $ + ANGLE_22h;
				
				mo.momz = $ - P_GetMobjGravity(mo) + P_GetMobjGravity(mo)*5/2
			elseif player.kartstuff[k_spinouttimer]
				local speed = max(1, min(8, player.kartstuff[k_spinouttimer]/8))
				if speed == 1 and abs(mo.angle-player.frameangle) < ANGLE_22h
					player.frameangle = mo.angle
				else
					player.frameangle = $ - (ANGLE_11hh*speed)
				end
			else
				player.frameangle = player.mo.angle;
			end
			
			player.drawangle = player.frameangle
			
			if player.powers[pw_justlaunched] and mo.momz*P_MobjFlip(mo) > 0 --higher slope launches
				mo.momz = $ * 2
			end
			
-- 			player.lives = 1
			K_GetKartBoostPower(player)
			
			// Speed lines
			if ((player.kartstuff[k_sneakertimer] or player.kartstuff[k_ringboost] or player.kartstuff[k_driftboost] or player.kartstuff[k_startboost] or player.wavedashboost) and player.speed > 0)
				local fast = P_SpawnMobj(mo.x + (P_RandomRange(-36,36) * mo.scale),
					mo.y + (P_RandomRange(-36,36) * mo.scale),
					mo.z + (mo.height/2) + (P_RandomRange(-20,20) * mo.scale),
					MT_THOK);--FASTLINE);
				fast.state = S_FASTLINE1
-- 				fast.color = SKINCOLOR_BLUEBELL
				fast.color = mo.color --colored linespeeds!!
				fast.scale = mapobjectscale
				fast.angle = R_PointToAngle2(0, 0, mo.momx, mo.momy);
				fast.momx = 3*mo.momx/4;
				fast.momy = 3*mo.momy/4;
				fast.momz = 3*mo.momz/4;
				fast.target = mo; // easier lua access
				K_MatchGenericExtraFlags(fast, mo);
			end
			
			local sector = mo.subsector.sector
			local appliedoffroad = false
-- 			local function GetSpecSecial(i)
-- 				return ()
			if onground
				if mo.floorrover
					sector = mo.floorrover.master.frontsector
				end
				
-- 				if mo.lastsector ~= sector
				--sd 2 = offroad 50%
				--sd 3 = harder offroad?
				--sd 5 = hardest offroad?!
				--sp 1 = sneaker panel
				--sp 2 = checkpoint
-- 				print("sp:"..sector.special..", msf:"..sector.flags..", ssf:"..sector.specialflags..", sd:"..sector.damagetype)
-- 				print(P_PlayerTouchingSectorSpecial(player,4,6))
				--https://git.do.srb2.org/KartKrew/Kart-Public/-/blob/next/src/p_spec.c#L4072
				if P_PlayerTouchingSectorSpecial(player,4,6) or (sector.specialflags & SSF_SUPERTRANSFORM)-- and (mo.lastsector ~= sector or not kart_booststacking.value)--P_PlayerTouchingSectorSpecial(player,4,6)
					if not player.kartstuff[k_floorboost] --makes sense without boost snacking
						player.kartstuff[k_floorboost] = 3
					else
						player.kartstuff[k_floorboost] = 2
					end
						
					K_DoSneaker(player,0)
				end
				
				if P_PlayerTouchingSectorSpecial(player,4,7) or (sector.specialflags & SSF_FORCESPIN)--sector.special & SSF_SPINOUT --srb2
					K_SpinPlayer(player,nil,0,nil,nil)
				end
				
				if sector.damagetype <= 5 and sector.damagetype >= 2--special & SSF_ORMASK --for now
					local offroad = sector.damagetype-1--(sector.special & SSF_ORMASK)>>3
					if not player.kartstuff[k_offroad]
						player.kartstuff[k_offroad] = TICRATE/2
					end
					
					if player.kartstuff[k_offroad] --no way
						player.kartstuff[k_offroad] = $ + (offroad*FU)/(TICRATE/2)
					end
					
					if player.kartstuff[k_offroad] > offroad*FU
						player.kartstuff[k_offroad] = offroad*FU
					end
					appliedoffroad = true
				end
				
				if P_PlayerTouchingSectorSpecial(player,4,1)--sector.special & SSF_STARPOST
					local post = P_GetObjectTypeInSectorNum(MT_STARPOST2,sector)
					if post
						P_TouchSpecialThing(post,mo,false)
					end
				end
				
				if P_PlayerTouchingSectorSpecial(player,3,1) or P_PlayerTouchingSectorSpecial(player,3,3)
					mo.z = $ + P_MobjFlip(mo)
					
					player.kartstuff[k_pogospring] = 1
					K_DoPogoSpring(mo,0,1)
					onground = false
				end
				
				mo.lastsector = sector
-- 				end
			else
				mo.lastsector = nil
			end
			
			if not appliedoffroad --hack mini
				player.kartstuff[k_offroad] = 0
			end
			
			mo.colorized = false
			mo.color = player.skincolor
			if player.kartstuff[k_invincibilitytimer]
				mo.colorized = true
				if kart_rrpoweritems.value
					local flicker = 2
					local leveltime = kart_rrpoweritems.value == 2 and player.kartstuff[k_invincibilitytimer] or leveltime
					if player.kartstuff[k_invincibilitytimer] > itemtime+(2*TICRATE)
						mo.color = getrainbow(leveltime)
					else
						mo.color = player.skincolor
						mo.colorized = false
						flicker = $ + ((itemtime+(2*TICRATE))-player.kartstuff[k_invincibilitytimer])/TICRATE/2
					end
					
					if not (leveltime%flicker)
						mo.color = SKINCOLOR_INVINCFLASH
						mo.colorized = true
					end
				else
					mo.color = getrainbow()--#skincolors-1-47)))
				end
				local ghost = P_SpawnGhostMobj(mo)
				ghost.fuse = 4
				ghost.frame = $ | FF_FULLBRIGHT
			end
			
			if player.kartstuff[k_growshrinktimer] > 0 and (not player.kartstuff[k_invincibilitytimer] or kart_rrpoweritems.value == 2)
				local flicker = 5
				if kart_rrpoweritems.value == 2
					flicker = $ + ((itemtime+(2*TICRATE))-player.kartstuff[k_growshrinktimer])/TICRATE/2
				end
				if player.kartstuff[k_growshrinktimer] % max(flicker,2) == 0
					mo.colorized = true
					mo.color = (player.kartstuff[k_growshrinktimer] < 0 and SKINCOLOR_CREAMSICLE or SKINCOLOR_PERIWINKLE2)
				end
			end
			
			if (player.kartstuff[k_ringboost] or (rubberbandstrength and player.rubberband > rubberbandtime/3)) and (leveltime & 1) // ring boosting
				mo.colorized = true
			end
			
			K_RespawnChecker(player)
			
			if (player.kmd.buttons & BT_DRIFT)
				player.kartstuff[k_jmp] = 1
			else
				player.kartstuff[k_jmp] = 0
			end
			
			if (player.kartstuff[k_rings] > 20)
				player.kartstuff[k_rings] = 20;
			elseif (player.kartstuff[k_rings] < -20)
				player.kartstuff[k_rings] = -20;
			end

			if (player.kartstuff[k_ringdelay])
				player.kartstuff[k_ringdelay] = $ - 1;
			end
			
			// Make ABSOLUTELY SURE that your flashing tics don't get set WHILE you're still in hit animations.
			if player.kartflashing player.kartflashing = $ - 1 end
			if (player.kartstuff[k_spinouttimer] != 0
				or player.kartstuff[k_wipeoutslow] != 0
				or player.kartstuff[k_squishedtimer] != 0)
				player.kartflashing = K_GetKartFlashing(player);
			elseif (player.kartflashing >= K_GetKartFlashing(player))
				player.kartflashing = $ - 1;
			end
			
			if not player.kartstuff[k_hyudorotimer] and player.kartstuff[k_growshrinktimer] <= 0 and
			not player.kartstuff[k_respawn] and leveltime >= (starttime or 0) and
			player.kartflashing and player.kartflashing < K_GetKartFlashing(player) and (leveltime & 1)
				mo.alpha = 0
			else
				mo.alpha = FU
			end
			
			if (player.kartstuff[k_spinouttimer])
				if ((P_IsObjectOnGround(player.mo) or ((player.kartstuff[k_spinouttype]+1)/2 == 1)) // spinouttype 1 and 2 - explosion and spb
					and (player.kartstuff[k_sneakertimer] == 0))
					player.kartstuff[k_spinouttimer] = $ - 1;
					if (player.kartstuff[k_wipeoutslow] > 1)
						player.kartstuff[k_wipeoutslow] = $ - 1;
					end
					if (player.kartstuff[k_spinouttimer] == 0)
						player.kartstuff[k_spinouttype] = 0; // Reset type
					end
				end
			else
				if (player.kartstuff[k_wipeoutslow] == 1)
					player.mo.friction = ORIG_FRICTION;
				end
				player.kartstuff[k_wipeoutslow] = 0;
				if (not comeback)
					player.kartstuff[k_comebacktimer] = comebacktime;
				elseif (player.kartstuff[k_comebacktimer])
					player.kartstuff[k_comebacktimer] = $ - 1;
					if (P_IsLocalPlayer(player) and player.kartstuff[k_bumper] <= 0 and player.kartstuff[k_comebacktimer] <= 0)
						comebackshowninfo = true; // client has already seen the message
					end
				end
			end
			
			
			if (player.kartstuff[k_ringboost])
				if not player.kartstuff[k_superring]
					local roller = TICRATE*2;
					roller = $ + 4*(8-player.kartspeed);
					
					player.kartstuff[k_ringboost] = $ - max((player.kartstuff[k_ringboost] / roller), 1);
				else
					player.kartstuff[k_ringboost] = $ - 1;
				end
			end
			
			if player.kartstuff[k_sneakertimer]
				player.kartstuff[k_sneakertimer] = $ - 1
				if (player.kartstuff[k_wipeoutslow] > 0 and player.kartstuff[k_wipeoutslow] < wipeoutslowtime+1)
					player.kartstuff[k_wipeoutslow] = wipeoutslowtime+1
				end
			end
			
			--boost stacking
			if not player.kartstuff[k_sneakertimer]
				player.kartstuff[k_numsneakers] = 0
			end
			
			--water skipping
			if P_IsObjectOnGround(mo)
				player.kartstuff[k_waterskip] = 0
			end
			
			if mo.momz*P_MobjFlip(mo) < 0
				if mo.eflags & MFE_UNDERWATER
					if player.kartstuff[k_waterskip] < 2 and (player.speed/3 > abs(mo.momz) or (player.speed > K_GetKartSpeed(player)/3 and player.kartstuff[k_waterskip]))
					and ((P_MobjFlip(mo)>0 and mo.z+mo.height-mo.momz>mo.watertop) or (P_MobjFlip(mo)<0 and mo.z-mo.momz<mo.waterbottom))
						local min = 6*FU
						mo.momx = $/2
						mo.momy = $/2
						mo.momz = -$/2
						
						if P_MobjFlip(mo)>0 and mo.momz<fixmul(min,mo.scale)
							mo.momz = fixmul(min,mo.scale)
						elseif P_MobjFlip(mo)<0 and mo.momz<fixmul(-min,mo.scale)
							mo.momz = fixmul(-min,mo.scale)
						end
						
						player.kartstuff[k_waterskip] = $ + 1
					end
				end
			end
			
			if player.kartstuff[k_floorboost]
				player.kartstuff[k_floorboost] = $ - 1 end
			
			if player.kartstuff[k_driftboost]
				player.kartstuff[k_driftboost] = $ - 1 end
			
			if player.kartstuff[k_startboost]
				player.kartstuff[k_startboost] = $ - 1 end
			
			if player.kartstuff[k_invincibilitytimer] and (onground or not kart_rrpoweritems.value)
				player.kartstuff[k_invincibilitytimer] = $ - 1
				if not player.kartstuff[k_invincibilitytimer]
					P_RestoreMusic(player)
				end
			end
			
			if not player.kartstuff[k_respawn] and player.kartstuff[k_growshrinktimer] and (onground or not kart_rrpoweritems.value)
				if (player.kartstuff[k_growshrinktimer] > 0)
					player.kartstuff[k_growshrinktimer] = $ - 1
				end
				if (player.kartstuff[k_growshrinktimer] < 0)
					player.kartstuff[k_growshrinktimer] = $ + 1
				end

				// Back to normal
				if (player.kartstuff[k_growshrinktimer] == 0)
	 				K_RemoveGrowShrink(player);
				end
			end
			
			--rings (2.3 based)
			if (player.kartstuff[k_superring])
				local ringrate = 3 - min(2, player.kartstuff[k_superring] / 20); // Used to consume fat stacks of cash faster.
				if (player.kartstuff[k_superring] % ringrate == 0)
					local ring = P_SpawnMobj(mo.x, mo.y, mo.z, MT_RING);
					ring.scale = mapobjectscale
					ring.extravalue1 = 1; // Ring collect animation timer
					ring.angle = mo.angle; // animation angle
					ring.target = mo; // toucher for thinker
					if (player.kartstuff[k_superring] <= 3)
						ring.cvmem = 1; // play caching when collected
					end
				end
				player.kartstuff[k_superring] = $ - 1;
			end
			
			--sliptiding
			if player.wavedashboost and onground
				player.wavedashboost = $ - 1
			end
			
			if not player.kartstuff[k_stealingtimer] and not player.kartstuff[k_stolentimer] and player.kartstuff[k_rocketsneakertimer]
				player.kartstuff[k_rocketsneakertimer] = $ - 1 end
			
			if player.kartstuff[k_hyudorotimer]
				player.kartstuff[k_hyudorotimer] = $ - 1 end
			
			if player.kartstuff[k_sadtimer]
				player.kartstuff[k_sadtimer] = $ - 1 end
			
			if player.kartstuff[k_stealingtimer]
				player.kartstuff[k_stealingtimer] = $ - 1 end
			
			if player.kartstuff[k_stolentimer]
				player.kartstuff[k_stolentimer] = $ - 1 end
			
			if player.kartstuff[k_squishedtimer]
				player.kartstuff[k_squishedtimer] = $ - 1 end
			
			if player.kartstuff[k_justbumped]
				player.kartstuff[k_justbumped] = $ - 1 end
			
			
			if player.kartstuff[k_positiondelay]
				player.kartstuff[k_positiondelay] = $ - 1 end
			
			// This doesn't go in HUD update because it has potential gameplay ramifications
			if (player.kartstuff[k_itemblink])
				player.kartstuff[k_itemblink] = $ - 1
				if player.kartstuff[k_itemblink] <= 0
					player.kartstuff[k_itemblinkmode] = 0;
					player.kartstuff[k_itemblink] = 0;
				end
			end
			
			
			mo.justbouncedwall = ($ and $-1 or 0)
			
			K_KartUpdatePosition(player)
			UpdateItem(player, onground)
			K_KartDrift(player, onground)
			
			if player.kartstuff[k_sneakertimer] and onground and (leveltime%2)
				K_SpawnBoostTrail(player)
			end
			
			if player.kartstuff[k_invincibilitytimer]
				K_SpawnSparkleTrail(mo)
			end
			
			if player.kartstuff[k_wipeoutslow] > 1 and (leveltime%2)
				K_SpawnWipeoutTrail(mo, false)
			end
			
			K_DriftDustHandling(mo)
			
-- 			if (player.kmd.buttons & BT_CUSTOM2) and not (player.klastbuttons & BT_CUSTOM2)
	-- 			K_DoSneaker(player,1)
-- 			end
			
			if (player.kmd.buttons & BT_CUSTOM1) and not (player.klastbuttons & BT_CUSTOM1) and kart_debuggeneral.value
				S_StartSound(mo,sfx_kc2e)
				player.kartstuff[k_itemroulette] = 1;
				player.kartstuff[k_roulettetype] = 0;
			end
			
			if player.kartstuff[k_numboosts] and kart_booststacking.value--booating
				local ghost = P_SpawnGhostMobj(mo)
				ghost.extravalue1 = player.kartstuff[k_numboosts]+1
				ghost.extravalue2 = (leveltime%ghost.extravalue1)
				ghost.fuse = ghost.extravalue1
				ghost.frame = $ | FF_FULLBRIGHT
				ghost.colorized = true
				if (leveltime%2)
					ghost.alpha = 0
				end
			end
			
			// DKR style camera for boosting
			if (player.kartstuff[k_boostcam] != 0 or player.kartstuff[k_destboostcam] != 0)
				if (player.kartstuff[k_boostcam] < player.kartstuff[k_destboostcam]
					and player.kartstuff[k_destboostcam] != 0)
					player.kartstuff[k_boostcam] = $ + FRACUNIT/(TICRATE/4);
					if (player.kartstuff[k_boostcam] >= player.kartstuff[k_destboostcam])
						player.kartstuff[k_destboostcam] = 0;
					end
				else
					player.kartstuff[k_boostcam] = $ - FRACUNIT/TICRATE;
					if (player.kartstuff[k_boostcam] < player.kartstuff[k_destboostcam])
						player.kartstuff[k_boostcam], player.kartstuff[k_destboostcam] = 0,0;
					end
				end
				//CONS_Printf("cam: %d, dest: %d\n", player->kartstuff[k_boostcam], player->kartstuff[k_destboostcam]);
			end
			
	-- 		player.camerascale = FU - fixmul(FU*11/16,player.kartstuff[k_boostcam])
			
			
			// Drifting sound
			// Start looping the sound now.
			if (leveltime % 50 == 0 and onground and player.kartstuff[k_drift] != 0)
				S_StartSound(mo, sfx_drift);
			// Leveltime being 50 might take a while at times. We'll start it up once, isntantly.
			elseif (not S_SoundPlaying(mo, sfx_drift) and onground and player.kartstuff[k_drift] != 0)
				S_StartSound(mo, sfx_drift);
			// Ok, we'll stop now.
			elseif (player.kartstuff[k_drift] == 0)
				S_StopSoundByID(mo, sfx_drift);
			end
			
			K_KartItemRoulette(player, player.kmd)
			
			P_3dMovement(player)
			
			K_ButteredSlope(mo)
			undoslope(mo)
			
			// "Blur" a bit when you have speed shoes and are going fast enough
			if not kart_booststacking.value and ((player.powers[pw_super] or player.powers[pw_sneakers]
				or player.kartstuff[k_driftboost] or player.kartstuff[k_ringboost] or player.kartstuff[k_sneakertimer] or player.kartstuff[k_startboost]) and not player.kartstuff[k_invincibilitytimer] // SRB2kart
				and (player.speed + abs(mo.momz)) > FixedMul(20*FRACUNIT,mo.scale))
				local i;
				local gmobj = P_SpawnGhostMobj(player.mo);
				
				gmobj.fuse = 2;
				if (leveltime & 1)
					gmobj.frame = $ & ~FF_TRANSMASK;
					gmobj.frame = $ | tr_trans70<<FF_TRANSSHIFT;
				end

				// Hide the mobj from our sights if we're the displayplayer and chasecam is off.
				// Why not just not spawn the mobj?  Well, I'd rather only flirt with
				// consistency so much...
				gmobj.dontdrawforviewmobj = mo
			end
			
	-- 		if P_IsObjectOnGround(mo) mo.flags = $|MF_NOGRAVITY else mo.flags = $&~MF_NOGRAVITY end
			
			player.klastbuttons = player.kmd.buttons
			mo.kartangle = mo.angle --in case kartangle is modified
			
			--powers[pw_carry] = CR_GENERIC
		else
			player.kart = nil
		end
	else
		player.kart = nil
	end
	
	if not player.kart and player.kartstuff
		player.kartstuff = nil
		player.restat = nil
		player.realmo.translation = nil
		player.realmo.colorized = false --for ringboosting
		player.realmo.spriteyoffset = 0 --for takis kart animations
		
		player.realmo.kartangle = nil
		player.thrustfactor = skins[player.skin].thrustfactor
		player.acceleration = skins[player.skin].acceleration
		player.accelstart = skins[player.skin].accelstart
		player.normalspeed = skins[player.skin].normalspeed
		player.charability = skins[player.skin].ability
		player.charability2 = skins[player.skin].ability2
		player.charflags = skins[player.skin].flags
		player.runspeed = skins[player.skin].runspeed
		player.realmo.radius = fixmul(skins[player.skin].radius,player.realmo.scale)
		player.realmo.state = S_PLAY_STND
		
		if player == consoleplayer
			hud.enable("score")
			hud.enable("time")
			hud.enable("rings")
			hud.enable("lives")
			hud.enable("textspectator")
		end
		
		if player.followmobj and player.followmobj.valid
			player.followmobj.alpha = FU
		end
	end
end)

// countersteer is how strong the controls are telling us we are turning
// turndir is the direction the controls are telling us to turn, -1 if turning right and 1 if turning left
local function K_GetKartDriftValue(player, countersteer)
	local basedrift, driftangle;
	local driftweight = player.kartweight*14; // 12

	// If they aren't drifting or on the ground this doesn't apply
	if (player.kartstuff[k_drift] == 0 or not P_IsObjectOnGround(player.mo))
		return 0;
	end

	if (player.kartstuff[k_driftend] != 0)
		return -266*player.kartstuff[k_drift]; // Drift has ended and we are tweaking their angle back a bit
	end

	//basedrift = 90*player.kartstuff[k_drift]; // 450
	//basedrift = 93*player.kartstuff[k_drift] - driftweight*3*player->kartstuff[k_drift]/10; // 447 - 303
	basedrift = 83*player.kartstuff[k_drift] - (driftweight - 14)*player.kartstuff[k_drift]/5; // 415 - 303
	driftangle = abs((252 - driftweight)*player.kartstuff[k_drift]/5);

	return basedrift + FixedMul(driftangle, countersteer);
end


local function K_GetKartTurnValue(player, turnvalue, delay)
	local p_topspeed = K_GetKartSpeed(player, false);
	local p_curspeed = min(player.speed + (delay and K_GetKartAccel(player) or 0), p_topspeed * 2);
	local p_maxspeed = p_topspeed * 3;
	local adjustangle = FixedDiv((p_maxspeed>>16) - (p_curspeed>>16), (p_maxspeed>>16) + (player.kartweight or 0));

	if (player.spectator)
		return turnvalue;
	end

	if (player.kartstuff[k_drift] != 0 and P_IsObjectOnGround(player.mo))
		// If we're drifting we have a completely different turning value
		if (player.kartstuff[k_driftend] == 0)
			// 800 is the max set in g_game.c with angleturn
			local countersteer = -FixedDiv(turnvalue*FRACUNIT, 800*FRACUNIT);
			turnvalue = -K_GetKartDriftValue(player, countersteer);
		else
			turnvalue = (turnvalue + -K_GetKartDriftValue(player, FRACUNIT));
		end

		return turnvalue;
	end

	turnvalue = FixedMul(turnvalue, adjustangle); // Weight has a small effect on turning

-- 	if (player.kartstuff[k_invincibilitytimer] or player.kartstuff[k_sneakertimer] or player.kartstuff[k_growshrinktimer] > 0)
-- 		turnvalue = FixedMul(turnvalue, FixedDiv(5*FRACUNIT, 4*FRACUNIT));
-- 	end
	local hb = player.kartstuff[k_handleboost]
	
	if kart_rrsliptide.value and player.kartstuff[k_aizdriftstrat] and not player.kartstuff[k_drift]
		hb = fixmul(sliptidehandling()*3/4,fixdiv(player.speed,p_topspeed))
	end
	
	turnvalue = FixedMul($, hb+FU)

	return turnvalue;
end
rawset(_G,"K_GetKartTurnValue",K_GetKartTurnValue)


-- local angleturn = {KART_FULLTURN/2, KART_FULLTURN, KART_FULLTURN/4} // + slow turn
local desynctics = 0
addHook("PreThinkFrame",do
	gamespeed = gs.value
	rubberbandstrength = kart_rubberband.value
	franticitems = kart_franticitems.value
	
	for player in players.iterate
-- 			print(player.mo.movefactor)
-- 			player.mo.kmovefactor = player.mo.movefactor
-- 			player.mo.movefactor = FU
-- 			player.mo.friction = player.mo.kmovefactor*29/32--ORIG_FRICTION
		if player and player.mo and player.kart
			local mo = player.mo
-- 			local pn = player == secondarydisplayplayer and 2 or 1
-- 			local desynced = player == consoleplayer and slocalkartangle ~= mo.kartangle
			player.powers[pw_justsprung] = 0
			player.mo.kmovefactor = player.mo.movefactor
			player.mo.movefactor = FU
-- 			print(player.mo.friction)
			player.mo.friction = ORIG_FRICTION
			
			local tspeed = KART_FULLTURN/2 --kart_turneasing is not usable here
			if abs(player.cmd.sidemove) >= 30 player.turnheld = $ + 1 else player.turnheld = 0 end
			if player.turnheld < SLOWTURNTICS
				tspeed = KART_FULLTURN/4
			else
				tspeed = KART_FULLTURN
			end
			
			if player.kartstuff and player.kartstuff[k_sneakertimer]
				player.cmd.forwardmove = 50
			end
			
-- 			if player.cmd.sidemove == 35
-- 				player.cmd.sidemove = 50
-- 			elseif player.cmd.sidemove == -36
-- 				player.cmd.sidemove = -50
-- 			end
			
-- 			player.cmd.aiming = 0 --also disabled
			player.driftturn = -tspeed * (player.cmd.sidemove>0 and 1 or (player.cmd.sidemove<0 and -1 or 0))
-- 			if player.speed
-- 				mo.kartangle = $ - K_GetKartTurnValue(player, -player.driftturn)*FU-- * (player.cmd.sidemove>0 and 1 or (player.cmd.sidemove<0 and -1 or 0))
-- 			end
-- 			player.kartangle
			
-- 			player.cmd.buttons = $ | ~(BT_JUMP)
-- 			if not player.kartdead
-- 				player.cmd.angleturn = mo.kartangle/FU
-- 			end
-- 			mo.angle = 10*FU
-- 			if consoleplayer==player camera.angle = player.kartangle end
			
			player.kmd = {sidemove = player.cmd.sidemove,forwardmove=player.cmd.forwardmove,buttons=player.cmd.buttons,
				latency=player.cmd.latency,angleturn=player.cmd.angleturn,aiming=player.cmd.aiming}
			player.cmd.sidemove = 0
			player.cmd.buttons = 0
			if IsMario and IsMario(player.mo)
				player.mariopressjump = 0
				player.mariojumpbuffer = 0
				player.mariopressspin = 0
				player.mariopressdown = 0
				player.mariopresscustom = 0
				player.mariopressfire = 0
				player.mariopressfirenormal = 0
				player.mariopressdirection = 0
				player.mariocustomspin = 0
				player.mariodidcircle = 0
				player.marioprevinput = {}
				player.marioinputangle = player.drawangle
			end
		end
	end
end)

--the function responsible for adding a minimum speed to bumps
local function P_PlayerHitBounceLine(slidemo,ld)
	local side;
	local lineangle;
	local movelen;

	side = P_PointOnLineSide(slidemo.x, slidemo.y, ld);
	lineangle = R_PointToAngle2(0, 0, ld.dx, ld.dy)-ANGLE_90;

	if (side == 1)
		lineangle = $ + ANGLE_180;
	end

	movelen = P_AproxDistance(slidemo.momx, slidemo.momy);

	if (slidemo.player and movelen < (15*mapobjectscale)) and not kart_retrocore.value
		movelen = (15*mapobjectscale);
	end

	slidemo.momx = $ + FixedMul(movelen, cos(lineangle));
	slidemo.momy = $ + FixedMul(movelen, sin(lineangle));
end

--bumps
local function K_GetMobjWeight(mobj, against)
	local weight = 5<<FRACBITS;

	local t = mobj.type
	if t == MT_PLAYER
		if (mobj.player and mobj.player.kart)
			if (against.player and against.player.kart and not against.player.kartstuff[k_spinouttimer] and mobj.player.kartstuff[k_spinouttimer])
				weight = 0; // Do not bump
			else
				weight = (mobj.player.kartweight)<<FRACBITS;
				if (mobj.player.speed > K_GetKartSpeed(mobj.player, false))
					weight = $ + (mobj.player.speed - K_GetKartSpeed(mobj.player, false))/8;
				end
			end
		end
	elseif t == MT_FALLINGROCK
		if (against.player and against.player.kart)
			if (against.player.kartstuff[k_invincibilitytimer]
				or against.player.kartstuff[k_growshrinktimer] > 0)
				weight = 0;
			else
				weight = (against.player.kartweight)<<FRACBITS;
			end
		end
	elseif t == MT_ORBINAUT
	or t == MT_ORBINAUT_SHIELD
		if (against.player and against.player.kart)
			weight = (against.player.kartweight)<<FRACBITS;
		end
	elseif t == MT_JAWZ
	or t == MT_JAWZ_DUD
	or t == MT_JAWZ_SHIELD
		if (against.player and against.player.kart)
			weight = (against.player.kartweight+3)<<FRACBITS;
		else
			weight = 8<<FRACBITS;
		end
	end

	return weight;
end
rawset(_G,"K_GetMobjWeight",K_GetMobjWeight)

local function K_KartBouncing(mobj1,mobj2,bounce,solid)
	local fx;
	local momdifx, momdify;
	local distx, disty;
	local dot, force;
	local mass1, mass2;

	if (not mobj1 or not mobj2)
		return;
	end

	// Don't bump when you're being reborn
	if ((mobj1.player and mobj1.player.playerstate != PST_LIVE)
		or (mobj2.player and mobj2.player.playerstate != PST_LIVE))
		return;
	end

	if ((mobj1.player and mobj1.player.kart and mobj1.player.kartstuff[k_respawn])
		or (mobj2.player and mobj2.player.kart and mobj2.player.kartstuff[k_respawn]))
		return;
	end

	// Don't bump if you're flashing
	local flash;

	flash = K_GetKartFlashing(mobj1.player);
	if (mobj1.player and mobj1.player.powers[pw_flashing] > 0 and mobj1.player.powers[pw_flashing] < flash)
		if (mobj1.player.powers[pw_flashing] < flash-1)
			mobj1.player.powers[pw_flashing] = $ + 1;
		end
		return;
	end

	flash = K_GetKartFlashing(mobj2.player);
	if (mobj2.player and mobj2.player.powers[pw_flashing] > 0 and mobj2.player.powers[pw_flashing] < flash)
		if (mobj2.player.powers[pw_flashing] < flash-1)
			mobj2.player.powers[pw_flashing] = $ + 1;
		end
		return;
	end

	// Don't bump if you've recently bumped
	if (mobj1.player and mobj1.player.kartstuff[k_justbumped])
		mobj1.player.kartstuff[k_justbumped] = bumptime;
		return;
	end

	if (mobj2.player and mobj2.player.kartstuff[k_justbumped])
		mobj2.player.kartstuff[k_justbumped] = bumptime;
		return;
	end

	mass1 = K_GetMobjWeight(mobj1, mobj2);

	if (solid == true and mass1 > 0)
		mass2 = mass1;
	else
		mass2 = K_GetMobjWeight(mobj2, mobj1);
	end

	momdifx = mobj1.momx - mobj2.momx;
	momdify = mobj1.momy - mobj2.momy;

	// Adds the OTHER player's momentum times a bunch, for the best chance of getting the correct direction
	distx = (mobj1.x + mobj2.momx*3) - (mobj2.x + mobj1.momx*3);
	disty = (mobj1.y + mobj2.momy*3) - (mobj2.y + mobj1.momy*3);

	if (distx == 0 and disty == 0)
		// if there's no distance between the 2, they're directly on top of each other, don't run this
		return;
	end

	// Normalize distance to the sum of the two objects' radii, since in a perfect world that would be the distance at the point of collision...
	local dist = P_AproxDistance(distx, disty);
	local nx = FixedDiv(distx, dist);
	local ny = FixedDiv(disty, dist);

	dist = dist and dist or 1;
	distx = FixedMul(mobj1.radius+mobj2.radius, nx);
	disty = FixedMul(mobj1.radius+mobj2.radius, ny);

	if (momdifx == 0 and momdify == 0)
		// If there's no momentum difference, they're moving at exactly the same rate. Pretend they moved into each other.
		momdifx = -nx;
		momdify = -ny;
	end

	// if the speed difference is less than this let's assume they're going proportionately faster from each other
	if (P_AproxDistance(momdifx, momdify) < (25*mapobjectscale))
		local momdiflength = P_AproxDistance(momdifx, momdify);
		local normalisedx = FixedDiv(momdifx, momdiflength);
		local normalisedy = FixedDiv(momdify, momdiflength);
		momdifx = FixedMul((25*mapobjectscale), normalisedx);
		momdify = FixedMul((25*mapobjectscale), normalisedy);
	end

	dot = FixedMul(momdifx, distx) + FixedMul(momdify, disty);

	if (dot >= 0)
		// They're moving away from each other
		return;
	end

	force = FixedDiv(dot, FixedMul(distx, distx)+FixedMul(disty, disty));

	if (bounce == true and mass2 > 0) // Perform a Goomba Bounce.
		mobj1.momz = -mobj1.momz;
	else
		local newz = mobj1.momz;
		if (mass2 > 0)
			mobj1.momz = mobj2.momz;
		end
		if (mass1 > 0 and solid == false)
			mobj2.momz = newz;
		end
	end

	if (mass2 > 0)
		mobj1.momx = mobj1.momx - FixedMul(FixedMul(FixedDiv(2*mass2, mass1 + mass2), force), distx);
		mobj1.momy = mobj1.momy - FixedMul(FixedMul(FixedDiv(2*mass2, mass1 + mass2), force), disty);
	end

	if (mass1 > 0 and solid == false)
		mobj2.momx = mobj2.momx - FixedMul(FixedMul(FixedDiv(2*mass1, mass1 + mass2), force), -distx);
		mobj2.momy = mobj2.momy - FixedMul(FixedMul(FixedDiv(2*mass1, mass1 + mass2), force), -disty);
	end

	// Do the bump fx when we've CONFIRMED we can bump.
	if not kart_retrocore.value
		S_StartSound(mobj1, sfx_s3k49);

		fx = P_SpawnMobj(mobj1.x/2 + mobj2.x/2, mobj1.y/2 + mobj2.y/2, mobj1.z/2 + mobj2.z/2, MT_THOK);--BUMP);
		fx.state = S_BUMP1
		if (mobj1.eflags & MFE_VERTICALFLIP)
			fx.eflags = $ | MFE_VERTICALFLIP;
		else
			fx.eflags = $ & ~MFE_VERTICALFLIP;
		end
	-- 	P_SetScale(fx, mobj1.scale);
		fx.scale = mobj1.scale
	end

	// Because this is done during collision now, rmomx and rmomy need to be recalculated
	// so that friction doesn't immediately decide to stop the player if they're at a standstill
	// Also set justbumped here
	if (mobj1.player)
		mobj1.player.rmomx = mobj1.momx - mobj1.player.cmomx;
		mobj1.player.rmomy = mobj1.momy - mobj1.player.cmomy;
		mobj1.player.kartstuff[k_justbumped] = bumptime;
		if (mobj1.player.kartstuff[k_spinouttimer])
			mobj1.player.kartstuff[k_wipeoutslow] = wipeoutslowtime+1;
			mobj1.player.kartstuff[k_spinouttimer] = max(wipeoutslowtime+1, mobj1.player.kartstuff[k_spinouttimer]);
		end
	end

	if (mobj2.player)
		mobj2.player.rmomx = mobj2.momx - mobj2.player.cmomx;
		mobj2.player.rmomy = mobj2.momy - mobj2.player.cmomy;
		mobj2.player.kartstuff[k_justbumped] = bumptime;
		if (mobj2.player.kartstuff[k_spinouttimer])
			mobj2.player.kartstuff[k_wipeoutslow] = wipeoutslowtime+1;
			mobj2.player.kartstuff[k_spinouttimer] = max(wipeoutslowtime+1, mobj2.player.kartstuff[k_spinouttimer]);
		end
	end
end

local function bump(mo,thing,line)
	if not mo.player or (mo.player and mo.player.kart)
-- 		mo.z = $ + P_MobjFlip(mo)
-- 		mo.flags = $&~MF_NOGRAVITY
-- 		if line
-- 			local side = P_PointOnLineSide(mo.x,mo.y,line)
-- 			local sector = (line.backsector and not side) and line.backsector or line.frontsector
-- 			local fl = P_GetZAt(P_MobjFlip(mo)<0 and sector.c_slope or sector.f_slope,mo.x,mo.y,P_MobjFlip(mo)<0 and sector.ceilingheight or sector.floorheight)
-- 			local ce = P_GetZAt(P_MobjFlip(mo)>0 and sector.c_slope or sector.f_slope,mo.x,mo.y,P_MobjFlip(mo)>0 and sector.ceilingheight or sector.floorheight)
-- 			local hcheck = not line.backsector or fl>=(mo.z)--+mo.height)
-- 			hcheck = $ or (not P_CheckSkyHit(mo,line) and ce<=mo.z)
-- 			if not hcheck
-- 				for fof in sector.ffloors()
-- 					if (fof.flags & FF_EXISTS) and (fof.flags & FF_BLOCKPLAYER)
-- 					and inrange(mo.z,P_GetZAt(fof.b_slope,mo.x,mo.y,fof.bottomheight)+P_MobjFlip(mo),P_GetZAt(fof.t_slope,mo.x,mo.y,fof.topheight)-P_MobjFlip(mo))
-- 						hcheck=true break
-- 					end
-- 				end
-- 			end
			
-- 			if not hcheck
-- 				return
-- 			end
-- 		end
		
		if thing
			K_KartBouncing(mo,thing,thing.type == MT_PLAYER,thing.type ~= MT_PLAYER)
			return
		end
		
		if not line
			return
		end
		
		--wall transfer hack.. borrowed from takis kart
		if mo.standingslope
			local z1 = P_GetZAt(mo.standingslope,mo.x,mo.y,mo.z)
			local z2 = P_GetZAt(mo.standingslope,mo.x+mo.momx,mo.y+mo.momy,mo.z+mo.momz)
			local flip = P_MobjFlip(mo)
			if z1*flip > mo.z*flip or z2*flip > mo.z*flip
				mo.momz = $*3/2
				return
			end
		end
		
		if mo.player and not kart_preservebumps.value
			mo.player.kartstuff[k_drift] = 0
			mo.player.kartstuff[k_driftcharge] = 0
			mo.player.kartstuff[k_pogospring] = 0
		end
		
		if not mo.player or not mo.justbouncedwall
			P_BounceMove(mo)
			if not kart_retrocore.value
				mo.momx = fixmul($, (FRACUNIT - (FRACUNIT>>2) - (FRACUNIT>>3)))
				mo.momy = fixmul($, (FRACUNIT - (FRACUNIT>>2) - (FRACUNIT>>3)))
				
				local fx = P_SpawnMobj(mo.x, mo.y, mo.z, MT_THOK);--MT_BUMP);
				fx.state = S_BUMP1
				if (mo.eflags & MFE_VERTICALFLIP)
					fx.eflags = $ | MFE_VERTICALFLIP;
				else
					fx.eflags = $ & ~MFE_VERTICALFLIP;
				end
				fx.scale = mo.scale;
				
				S_StartSound(mo, sfx_s3k49);
			end
		else
			P_SlideMove(mo)
		end
				
		
		if line and mo.player
			P_PlayerHitBounceLine(mo,line)
		end
		
		mo.justbouncedwall = 2
		
		if mo.player
			mo.player.rmomx = mo.momx-mo.player.cmomx
			mo.player.rmomy = mo.momy-mo.player.cmomy
		end
		
		if mo.type == MT_ORBINAUT
			if mo.health > 1
				S_StartSound(mo,mo.info.attacksound)
				mo.health = $ - 1
				mo.threshold = 0
			elseif mo.health == 1
				S_StartSound(mo,mo.info.deathsound)
				P_SetObjectMomZ(mo,8*FU,false)
				P_InstaThrust(mo,R_PointToAngle2(0,0,mo.momx,mo.momy)+ANGLE_90,16*FU)
				
				P_KillMobj(mo)
				mo.flags = $ & ~MF_NOGRAVITY
			end
		end
-- 		local fx = P_SpawnMobjFromMobj(mo, 0, 0, 0, MT_BUMP);
		return true
	end
end
addHook("MobjMoveBlocked",bump,MT_PLAYER)
addHook("MobjMoveBlocked",bump,MT_ORBINAUT)

addHook("MobjThinker",function(mobj)
	if mobj and mobj.valid
		if ((not mobj.target or not mobj.target.health or not mobj.target.player or not P_IsObjectOnGround(mobj.target))
			or not mobj.target.player.kartstuff[k_drift] or not mobj.target.player.kartstuff[k_brakedrift]
			or not ((mobj.target.player.kmd.forwardmove < 0)
			or not (mobj.target.player.kmd.forwardmove))) // Letting go of accel functions about the same as brake-drifting
			P_RemoveMobj(mobj);
			return;
		else
			local newx, newy;
			local travelangle;

			travelangle = mobj.target.angle - ((ANGLE_45/5)*mobj.target.player.kartstuff[k_drift]);

			newx = mobj.target.x + P_ReturnThrustX(mobj.target, travelangle+ANGLE_180, 24*mobj.target.scale);
			newy = mobj.target.y + P_ReturnThrustY(mobj.target, travelangle+ANGLE_180, 24*mobj.target.scale);
			P_MoveOrigin(mobj, newx, newy, mobj.target.z);

			mobj.angle = travelangle - ((ANGLE_90/5)*mobj.target.player.kartstuff[k_drift]);
			mobj.scale = mobj.target.scale;

			if (mobj.target.player.kartstuff[k_driftcharge] >= K_GetKartDriftSparkValue(mobj.target.player)*4)
				mobj.color = getrainbow();
			elseif (mobj.target.player.kartstuff[k_driftcharge] >= K_GetKartDriftSparkValue(mobj.target.player)*2)
				mobj.color = SKINCOLOR_KETCHUP2;
			elseif (mobj.target.player.kartstuff[k_driftcharge] >= K_GetKartDriftSparkValue(mobj.target.player))
				mobj.color = SKINCOLOR_SAPPHIRE2;
			else
				mobj.color = SKINCOLOR_SILVER;
			end

			if (not S_SoundPlaying(mobj, sfx_cdfm17))
				S_StartSound(mobj, sfx_cdfm17);
			end

			K_MatchGenericExtraFlags(mobj, mobj.target);
			if (leveltime & 1)
				mobj.flags2 = $ | MF2_DONTDRAW;
			end
		end
	end
end,MT_BRAKEDRIFT)

local function nough(ring,mo)
	if mo.player and mo.player.kart
		if not ring.extravalue1-- and mo.player.kartstuff[k_rings] < 20
			ring.extravalue1 = 1; // Ring collect animation timer
			ring.angle = mo.angle; // animation angle
			ring.target = mo; // toucher for thinker
-- 			if (mo.player.kartstuff[k_superring] <= 3)
-- 				ring.cvmem = 1; // play caching when collected
-- 			end
		end
		return true
	end
end
addHook("TouchSpecial",nough,MT_RING)
addHook("TouchSpecial",nough,MT_FLINGRING)

freeslot("MT_RANDOMITEM", "SPR_RNDM", "S_RANDOMITEM1", "SPR_RPOP", "S_RANDOMITEMPOP1", "S_RANDOMITEMPOP2")
mobjinfo[MT_SMASHINGSPIKEBALL].doomednum = -1
states[S_RANDOMITEM1] = {SPR_RNDM, FF_FULLBRIGHT|FF_ANIMATE, -1, nil, 23, 3, S_RANDOMITEM1}
states[S_RANDOMITEMPOP1] = {SPR_RPOP, FF_FULLBRIGHT|FF_ANIMATE, 5*3, nil, 3-1, 5, S_RANDOMITEMPOP2} --actually spr_bom1 with the first frame trimmed off: i have little to no idea what is going on behind the scenes
states[S_RANDOMITEMPOP2] = {SPR_NULL, 0, TICRATE*3/2, nil, 0, 0, S_RANDOMITEM1}
mobjinfo[MT_RANDOMITEM] = {
	doomednum = 2000,
	spawnstate = S_RANDOMITEM1,
	deathstate = S_RANDOMITEM1,
	radius = 48*FU,
	height = 48*FU,
	flags = MF_SLIDEME|MF_SPECIAL|MF_NOGRAVITY|MF_NOCLIPHEIGHT
}

addHook("TouchSpecial",function(ring,mo)
	if mo.player and mo.player.kart
		local player = mo.player
-- 		if player.kartflashing or player.kartstuff[k_spinouttimer]
-- 		or player.kartstuff[k_squishedtimer]
-- 		or ((player.kartstuff[k_invincibilitytimer] or player.kartstuff[k_growshrinktimer] > 0) and not kart_rrpoweritems.value)
-- 		or player.kartstuff[k_hyudorotimer] or player.kartstuff[k_roulettetype] == 2
-- 		or player.kartstuff[k_eggmanexplode]
-- 			return true
-- 		end
		if player.kartstuff[k_stealingtimer] or player.kartstuff[k_stolentimer]
		or (player.kartstuff[k_growshrinktimer] > 0 and not kart_rrpoweritems.value)
		or player.kartstuff[k_rocketsneakertimer] or player.kartstuff[k_eggmanexplode]
			return true
		end
		
		if not player.kartstuff[k_itemroulette] and not player.kartstuff[k_itemtype] and not player.kartstuff[k_itemheld]
		and ring.state == ring.info.spawnstate
			S_StartSound(ring,sfx_kc2e)
			ring.state = S_RANDOMITEMPOP1
			player.kartstuff[k_itemroulette] = 1;
			player.kartstuff[k_roulettetype] = 0;
		end
		return true
	end
end,MT_RANDOMITEM)

addHook("ShouldDamage",function(mo, enemy, source, dmg, damagetype)
	if mo and mo.valid and mo.player and mo.player.kart
		if (damagetype & DMG_DEATHMASK) and not mo.player.kartdead
			mo.momx,mo.momy,mo.momz = 0,0,0
			mo.flags = $ | MF_NOCLIPHEIGHT|MF_NOTHINK

-- 			if (target->player && target->player->pflags & PF_TIMEOVER)
-- 				break;
-- 			end

-- 			target->fuse = TICRATE*3; // timer before mobj disappears from view (even if not an actual player)
			if damagetype ~= DMG_DROWNED--(not (source and source.type == MT_NULL and source->threshold == 42)) // Don't jump up when drowning
				P_SetObjectMomZ(mo, 14*FRACUNIT, false);
			end

			if damagetype == DMG_DROWNED--(source && source->type == MT_NULL && source->threshold == 42) // drowned
				S_StartSound(mo, sfx_drown);
			elseif damagetype == DMG_SPIKE--(source && (source->type == MT_SPIKE || (source->type == MT_NULL && source->threshold == 43))) // Spikes
				S_StartSound(mo, sfx_spkdth);
			else
				P_PlayDeathSound(mo);
			end

			mo.player.kartdead = TICRATE--*3 --add a kart table
		end
		return false
	end
end,MT_PLAYER)

local _P_GivePlayerRings = P_GivePlayerRings
rawset(_G,"P_GivePlayerRings",function(player,num_rings)
	if not player or not player.kart
		_P_GivePlayerRings(player,num_rings)
		return
	end
	
-- 	if (G_BattleGametype()) // No rings in Battle Mode
-- 		return;
-- 	end
	
	player.kartstuff[k_rings] = $ + num_rings;
	//player.totalring = $ + num_rings; // Used for GP lives later
	
	if (player.kartstuff[k_rings] > 20)
		player.kartstuff[k_rings] = 20; // Caps at 20 rings, sorry!
		return false
	elseif (player.kartstuff[k_rings] < -20)
		player.kartstuff[k_rings] = -20; // Chaotix ring debt!
		return false
	end
	
	return true
end)

local function K_GetKartRingPower(player, boosted)
	local ringPower = ((9 - player.kartspeed) + (9 - player.kartweight)) * (FRACUNIT/2);

	if (boosted == true)
		ringPower = FixedMul(ringPower, FU);--K_RingDurationBoost(player));
	end

	return max(ringPower / FRACUNIT, 1);
end


addHook("MobjThinker",function(mo)
	local actor = mo
	if (actor.extravalue1) // SRB2Kart
		if (not actor.target or not actor.target.valid or not actor.target.player)
			P_RemoveMobj(actor);
			return;
		end

		if (actor.extravalue2) // Using for ring boost
			if (actor.extravalue1 >= 21)
				// Base add is 3 tics for 9,9, adds 1.5 tics for each point closer to the 1,1 end
				actor.target.player.kartstuff[k_ringboost] = $ + K_GetKartRingPower(actor.target.player, true) + 3;
				S_StartSound(actor.target, sfx_itemup);
				actor.momx = (3*actor.target.momx)/4;
				actor.momy = (3*actor.target.momy)/4;
				actor.momz = (3*actor.target.momz)/4;
-- 				P_KillMobj(actor, actor.target, actor.target);
				P_RemoveMobj(actor);
				return;
			else
				local offz = FixedMul(80*actor.target.scale, sin(FixedAngle((90 - (9 * abs(10 - actor.extravalue1))) << FRACBITS)));
				//P_SetScale(actor, (actor.destscale = actor.target.scale));
				P_MoveOrigin(actor, actor.target.x, actor.target.y, actor.target.z + actor.target.height + offz);
				actor.extravalue1 = $ + 1;
			end
		else // Collecting
			if (actor.extravalue1 >= 16)
				if not P_GivePlayerRings(actor.target.player, 1)
					actor.target.player.kartstuff[k_ringboost] = $ + K_GetKartRingPower(actor.target.player, true) + 3;
				end
				if (actor.cvmem) // caching
					S_StartSound(actor.target, sfx_s1c5);
				else
					S_StartSound(actor.target, sfx_s227);
				end
				P_RemoveMobj(actor);
				return;
			else
				local dist = (actor.target.radius/4) * (16 - actor.extravalue1);

				actor.scale = actor.target.scale - ((actor.target.scale/14) * actor.extravalue1)
				P_MoveOrigin(actor,
					actor.target.x + FixedMul(dist, cos(actor.angle)),
					actor.target.y + FixedMul(dist, sin(actor.angle)),
					actor.target.z + (24 * actor.target.scale));

				actor.angle = $ + ANG30;
				actor.extravalue1 = $ + 1;
			end
		end
	end
end,MT_RING)

local function K_IsPlayerLosing(player)
	local winningpos = 1;
	local i, pcount = 0, 0;

	if (player.kartstuff[k_position] == 1)
		return false;
	end

	for p in players.iterate
		if (not p.valid or p.spectator or not p.kartstuff)
			continue;
		end
		if (p.kartstuff[k_position] > pcount)
			pcount = p.kartstuff[k_position];
		end
	end

	if (pcount <= 1)
		return false;
	end

	winningpos = pcount/2;
	if (pcount % 2) // any remainder?
		winningpos = $ + 1;
	end

	return (player.kartstuff[k_position] > winningpos);
end
rawset(_G,"K_IsPlayerLosing",K_IsPlayerLosing)

--waypoints
rawset(_G,"waypointcap",0)
rawset(_G,"numstarposts",0)
rawset(_G,"sphealth",{})
addHook("NetVars",function(net)
	waypointcap = net($)
	numstarposts = net($)
	sphealth = net($)
	gamespeed = net($)
	
	rubberbandstrength = net($)
-- 	rubberbandtime = net($)
end)

addHook("MapChange",function(gamemap)
	waypointcap = 0
	numstarposts = 0
	sphealth = {}
	mapobjectscale = mapheaderinfo[gamemap].mobjscale and tofixed(mapheaderinfo[gamemap].mobjscale) or FU
end)

--move to globals latel
rawset(_G, "SSF_SNEAKERPANEL", 1<<0)
rawset(_G, "SSF_STARPOST", 1<<1)
rawset(_G, "SSF_SPINOUT", 1<<2)

rawset(_G, "SSF_ORMASK", (1<<3)|(1<<4)|(1<<5))
rawset(_G, "SSF_OFFROAD1", 1<<3)
rawset(_G, "SSF_OFFROAD2", 2<<3)
rawset(_G, "SSF_OFFROAD3", 3<<3)
rawset(_G, "SSF_OFFROAD4", 4<<3)

--1<<6

addHook("MapLoad",function()
	if gametype == GT_RACE or kart_debuggeneral.value
		for sector in sectors.iterate
			--sector.special is practically a free field now, which can be used to disable specials (through other fields) and replace their logic
			--on the contrary i should totally move to a global table
			if sector.damagetype ~= SD_DEATHPITTILT and sector.damagetype ~= SD_DEATHPITNOTILT
				sector.flags = $ & ~(MSF_FLIPSPECIAL_FLOOR|MSF_FLIPSPECIAL_CEILING|MSF_FLIPSPECIAL_BOTH)
			end
-- 			sector.special = 0
-- 			if sector.specialflags & SSF_SUPERTRANSFORM --sneakerpanel
-- 				sector.specialflags = $ & ~SSF_SUPERTRANSFORM
-- 				sector.special = $ | SSF_SNEAKERPANEL
-- 			end
			
-- 			if sector.specialflags & SSF_STARPOSTACTIVATOR --starpost
-- 				sector.specialflags = $ & ~SSF_STARPOSTACTIVATOR
-- 				sector.special = $ | SSF_STARPOST
-- 			end
			
-- 			if sector.specialflags & SSF_FORCESPIN --oil
-- 				sector.specialflags = $ & ~SSF_FORCESPIN
-- 				sector.special = $ | SSF_SPINOUT
-- 			end
			
-- 			if sector.damagetype == 2 --offroad
-- 				sector.damagetype = 0
-- 				sector.special = $ | SSF_OFFROAD1
-- 			elseif sector.damagetype == 3 --offroad+
-- 				sector.damagetype = 0
-- 				sector.special = $ | SSF_OFFROAD2
-- 			elseif sector.damagetype == 4 --offroad+ ce
-- 				sector.damagetype = 0
-- 				sector.special = $ | SSF_OFFROAD3
-- 			elseif sector.damagetype == 5 --offroad promax
-- 				sector.damagetype = 0
-- 				sector.special = $ | SSF_OFFROAD4
-- 			end
		end
	end
end)

local function P_GetObjectTypeInSectorNum(type,sector)
	for thing in sector.thinglist()
		if thing.type == type
			return thing
		end
	end
end
rawset(_G,"P_GetObjectTypeInSectorNum",P_GetObjectTypeInSectorNum)

addHook("MapThingSpawn",function(mo,thing)
	mo.health = thing.angle
	mo.movecount = thing.extrainfo
	mo.tracer = waypointcap or $
	waypointcap = mo
end,MT_BOSS3WAYPOINT)

freeslot("MT_STARPOST2")
mobjinfo[MT_STARPOST2] = {
	-1,            // doomednum
	S_INVISIBLE, // spawnstate
	1,              // spawnhealth
	S_INVISIBLE, // seestate
	sfx_None,       // seesound
	8,              // reactiontime
	sfx_None,       // attacksound
	S_INVISIBLE, // painstate
	0,              // painchance
	sfx_strpst,     // painsound
	S_NULL,         // meleestate
	S_NULL,         // missilestate
	S_NULL,         // deathstate
	S_NULL,         // xdeathstate
	sfx_None,       // deathsound
	8,              // speed
	64*FRACUNIT,    // radius
	128*FRACUNIT,   // height
	0,              // display offset
	4,              // mass
	0,              // damage
	sfx_None,       // activesound
	MF_SPECIAL,     // flags
	S_NULL          // raisestate
}
addHook("MapThingSpawn",function(mo,thing)
	--more efficient than looping through all the objects
	local h = thing.args[0] + 1
	if not sphealth[h]
		numstarposts = $ + 1
		sphealth[h] = true
	end
	if gametype == GT_RACE or kart_debuggeneral.value
		mo.alpha = 0
		mo.state = S_INVISIBLE
-- 		mo.flags = $ & ~MF_SPECIAL
	end
end,MT_STARPOST)

--agh
addHook("MobjThinker",function(mo)
	if mo and mo.valid and (gametype == GT_RACE or kart_debuggeneral.value)
		mo.type = MT_STARPOST2 --genial
	end
end,MT_STARPOST)

addHook("TouchSpecial",function(special,mo)
	if mo.player and mo.player.kart
		local player = mo.player
-- 		if player.bot return true end
		if player.exiting
			player.kartstuff[k_starpostwp] = player.kartstuff[k_waypoint]
			return true
		end
		
		if special.health >= numstarposts/2 + player.starpostnum
			if not player.tossdelay
				S_StartSound(mo,sfx_s3kb2)
				--antigrief WOULD go here
			end
			player.tossdelay = 3
			return true
		end
		
		if player.starpostnum >= special.health
			return true
		end
		
		player.starposttime = player.realtime
		player.starpostx = mo.x/FU
		player.starposty = mo.y/FU
		player.starpostz = mo.z/FU
		player.starpostangle = special.angle
		player.starpostnum = special.health
		player.kartstuff[k_starpostflip] = special.spawnpoint.options & MTF_OBJECTFLIP
-- 		player.grieftime = 0
		
		return true
	end
end,MT_STARPOST2)

--player setup fix; this is here because of the data table

--[[hud.add(function(v, player, x, y, scale, skin, sprite2, frame, rotation, color, time, paused)
	local dat = data[skin]
	--print(skin, dat)

	if dat and not skins[skin].sprites[SPR2_WALK].numframes then
		v.drawScaled(x, y, scale, v.getSprite2Patch(skin, dat.spr2, false, A, 5, 0), 0, v.getColormap(skin, color))
		
		return true
	end
end, "playersetup")]]