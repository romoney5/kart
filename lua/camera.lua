--f.d.t. camera adapted

local localangle,localaiming = 0,0
local camobj
local enabled = CV_RegisterVar{name = "kart_camera", defaultvalue = "On", PossibleValue = CV_OnOff}
--renamed due to new camera prediction system
local sync = CV_RegisterVar{name = "kart_camerapredict", defaultvalue = "On", PossibleValue = CV_OnOff}
local cam_speed = FU/2

--hud.add(function(v,player,cam)
--end,"game")

local function G_ClipAimingPitch(aiming)
	local limitangle = ANGLE_90-1
	if aiming > limitangle
		aiming = limitangle
	elseif aiming < -limitangle
		aiming = -limitangle
	end
	
	return aiming-->>16
end

local cv_exitmove = CV_FindVar("exitmove")
local cv_cam_rotate = CV_FindVar("cam_rotate")
local cv_cam_speed = CV_FindVar("cam_speed")
local cv_cam_still = CV_FindVar("cam_still")
local cv_cam_orbit = CV_FindVar("cam_orbit")
local cv_cam_rotate = CV_FindVar("cam_rotate")
local cv_cam_dist = CV_FindVar("cam_dist")
local cv_cam_height = CV_FindVar("cam_height")
local cv_analog = CV_FindVar("configanalog")
local cv_cam_rotspeed = CV_FindVar("cam_rotspeed")
local cv_cam_shiftfacing = CV_FindVar("cam_shiftfacing")
local cv_cam_adjust = CV_FindVar("cam_adjust")
local cv_glshearing = CV_FindVar("gr_shearing")
--local cv_cam_speed = CV_FindVar("cv_cam_speed")
--local cv_cam_speed = CV_FindVar("cv_cam_speed")
--local cv_cam_speed = CV_FindVar("cv_cam_speed")
local CS_LEGACY = 0
local CS_LMAOGALOG = 1
local CS_STANDARD = 2
local CS_SIMPLE = CS_LMAOGALOG|CS_STANDARD
local function P_ControlStyle(player)
	return (((player.pflags & PF_ANALOGMODE) and CS_LMAOGALOG or 0) | ((player.pflags & PF_DIRECTIONCHAR) and CS_STANDARD or 0))
end

local function G_ControlStyle(ssplayer)
	return P_ControlStyle(players[ssplayer-1])
end

local KART_FULLTURN = 800
local SLOWTURNTICS = 6
rawset(_G,"localkartangle", {0,0}) --should not be synced with the network
rawset(_G,"dlocalkartangle", {0,0}) --drift additive for high delay
rawset(_G,"turnheld", {0,0})

rawset(_G,"kart_turneasing", CV_RegisterVar{name = "kart_turneasing", defaultvalue = "6", PossibleValue = {MIN = 0, MAX = 16}})
rawset(_G,"kart_cameraspeed", CV_RegisterVar{name = "kart_cameraspeed", defaultvalue = ".4", PossibleValue = {MIN = 0, MAX = FU}, flags = CV_FLOAT}) --.4 for ring racers
rawset(_G,"kart_cameradist", CV_RegisterVar{name = "kart_cameradist", defaultvalue = "160", PossibleValue = {MIN = 0, MAX = INT32_MAX}, flags = CV_FLOAT}) --190 (210?) for ring racers
rawset(_G,"kart_cameraheight", CV_RegisterVar{name = "kart_cameraheight", defaultvalue = "50", PossibleValue = {MIN = 0, MAX = INT32_MAX}, flags = CV_FLOAT}) --95 for ring racers

--rebind controls!
--there's already a playercmd hook so might as well put it here for now
--TODO: allow a control to be bound to multiple buttons
local kart_controlremapping = CV_RegisterVar{name = "kart_controlremapping", defaultvalue = "On", PossibleValue = CV_OnOff}
local control = {
	None = GC_NULL,
	Jump = GC_JUMP, Spin = GC_SPIN,
	Custom1 = GC_CUSTOM1, Custom2 = GC_CUSTOM2, Custom3 = GC_CUSTOM3,
	Fire = GC_FIRE, FireNormal = GC_FIRENORMAL,
	TossFlag = GC_TOSSFLAG,
	LookUp = GC_LOOKUP, LookDown = GC_LOOKDOWN,
	WeaponNext = GC_WEAPONNEXT, WeaponPrev = GC_WEAPONPREV,
	Weapon1 = GC_WEPSLOT1, Weapon2 = GC_WEPSLOT2, Weapon3 = GC_WEPSLOT3,
	Weapon4 = GC_WEPSLOT4, Weapon5 = GC_WEPSLOT5, Weapon6 = GC_WEPSLOT6,
	Weapon7 = GC_WEPSLOT7,
	--pretty sure these won't work at all on gamepad but i don't feel like testing again
-- 	Forward = GC_FORWARD, Backward = GC_BACKWARD,
}

--{default control name, button that it will be remapped to internally}
local defaults = {
	drift = {"Spin", BT_SPIN},
	item = {"Custom3", BT_CUSTOM3},
	lookback = {"Custom2", BT_CUSTOM3},
	
	aimup = {"LookUp", BT_CAMLEFT},
	aimdown = {"LookDown", BT_CAMRIGHT},
}

local vars = {}

for name, default in pairs(defaults) do
	table.insert(vars, {control = name, cvar = CV_RegisterVar{name = "kart_control_"..name, defaultvalue = default[1], PossibleValue = control}})
end

--lag compensation & more
addHook("PlayerCmd", function(player, cmd)
	if not player.kart or not player.kartstuff or player.bot return end
	
	if kart_controlremapping.value then
		local buttons = 0
		for i, var in ipairs(vars) do
			if input.gameControlDown(control[var.cvar.string]) then
				buttons = $ | defaults[var.control][2]
			end
		end
		
		cmd.buttons = buttons
	end
	
	local pn = player == secondarydisplayplayer and 2 or 1
	local SLOWTURNTICS = kart_turneasing.value
	local tspeed = KART_FULLTURN/2
	if abs(cmd.sidemove) >= 30 turnheld[pn] = $ + 1 else turnheld[pn] = 0 end
	if turnheld[pn] < SLOWTURNTICS
		tspeed = KART_FULLTURN/4
	else
		tspeed = KART_FULLTURN
	end
	
	--normalize forward/side inputs
	local xf,yf = cmd.sidemove*FU/50,cmd.forwardmove*FU/50
	if xf and yf
		local d = fixhypot(xf,yf)
		local dd = max(abs(xf),abs(yf))
		--98% of magnitude is not a big difference
		cmd.sidemove = max(min(fixdiv(fixmul(xf,d),dd)*51/FU,50),-50)
		cmd.forwardmove = max(min(fixdiv(fixmul(yf,d),dd)*51/FU,50),-50)
		if abs(cmd.sidemove) <= 15 --deadzone
			cmd.sidemove = 0
		end
	end
	
	local driftturn = -tspeed * (cmd.sidemove>0 and 1 or (cmd.sidemove<0 and -1 or 0))
	
	if player.speed or cmd.forwardmove or player.kartstuff[k_respawn]
		local turn = K_GetKartTurnValue(player, -driftturn, player.cmd.latency > 2)*FU
		localkartangle[pn] = $ - turn-- * (player.kmd.sidemove>0 and 1 or (player.kmd.sidemove<0 and -1 or 0))
	end
	
	local drift = max(min(-player.kartstuff[k_drift],1),-1)
	dlocalkartangle[pn] = ease.linear(FU/3,$,drift*ANG1*min(player.cmd.latency,11))
	cmd.angleturn = localkartangle[pn]/FU
-- 	cmd.aiming = 0
end)

local function P_MoveChaseCamera(player, thiscam, resetcalled)
	local angle, focusangle, focusaiming = 0,0,0;
	local x, y, z, dist, distxy, distz, checkdist, viewpointx, viewpointy, camspeed, camdist, camheight, pviewheight, slopez, pan, xpan, ypan = 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
	local camrotate;
	local camstill, cameranoclip, camorbit;
	local mo, sign = nil;
	local newsubsec;
	local f1, f2;

	local camsideshift = {0, 0};
	local shiftx, shifty = 0,0;
	
	local gl = true --rendermode == render_opengl

	// We probably shouldn't move the camera if there is no player or player mobj somehow
	if (not player or not player.mo)
		return true;
	end

	mo = player.mo;

	if (player.playerstate == PST_REBORN)
--		P_CalcChasePostImg(player, thiscam);
		return true;
	end

	if (player.exiting)
		if (mo.target and mo.target.type == MT_SIGN and mo.target.spawnpoint
		and not ((gametyperules & GTR_FRIENDLY) and (netgame or multiplayer) and cv_exitmove.value)
		and not (twodlevel or (mo.flags2 & MF2_TWOD)))
			sign = mo.target;
--		else if (player.powers[pw_carry] == CR_NIGHTSMODE and not P_IsPlayerInNightsTransformationState(player))
--			P_CalcChasePostImg(player, thiscam);
--			return true;
		end
	end

	cameranoclip = true--(sign or player.powers[pw_carry] == CR_NIGHTSMODE or player.pflags & PF_NOCLIP) or (mo.flags & (MF_NOCLIP|MF_NOCLIPHEIGHT)); // Noclipping player camera noclips too!!

	if (not (player.climbing or (player.powers[pw_carry] == CR_NIGHTSMODE) or player.playerstate == PST_DEAD or tutorialmode))
		if (player.spectator or not thiscam.chase)
			// set the values to the player's values so they can still be used
--			thiscam.x = player.mo.x;
--			thiscam.y = player.mo.y;
--			thiscam.z = player.viewz;
			P_SetOrigin(thiscam,player.mo.x,player.mo.y,player.viewz)
			thiscam.momx = player.mo.momx;
			thiscam.momy = player.mo.momy;
			thiscam.momz = player.mo.momz;

--			if (thiscam == &camera)
				// when not spectating, use local angles
				if (displayplayer == consoleplayer)
					thiscam.angle = localangle;
					thiscam.aiming = anglefix(localaiming);
				else
					thiscam.angle = displayplayer.cmd.angleturn << 16;
					thiscam.aiming = anglefix(displayplayer.cmd.aiming << 16);
				end
--			} 
--			else if (thiscam == &camera2)
--			{
--				// i dont think secondarydisplayplayer changes, so we should be fine.
--				thiscam.angle = localangle2;
--				thiscam.aiming = localaiming2;
--			}

--			thiscam.subsector = player.mo.subsector;
--			thiscam.floorz = player.mo.floorz;
--			thiscam.ceilingz = player.mo.ceilingz;
			return true;
		end
	end

	if (not thiscam.chase and not resetcalled)
		if (player == consoleplayer)
			focusangle = localangle;
		elseif (player == secondarydisplayplayer)
			focusangle = localangle2;
		else
			focusangle = mo.angle;
		end
--		if (thiscam == &camera)
			camrotate = cv_cam_rotate.value;
--		else if (thiscam == &camera2)
--			camrotate = cv_cam2_rotate.value;
--		else
--			camrotate = 0;
		thiscam.angle = focusangle + FixedAngle(camrotate*FRACUNIT);
--		P_ResetCamera(player, thiscam); --in lua, but probably affects the default camera
		return true;
	end
	

	--kart
-- 	thiscam.radius = FixedMul(20*FRACUNIT, mo.scale);
-- 	thiscam.height = FixedMul(16*FRACUNIT, mo.scale);

	// Don't run while respawning from a starpost
	// Inu 4/8/13 Why not?!
//	if (leveltime > 0 and timeinmap <= 0)
//		return true;

	if (player.powers[pw_carry] == CR_NIGHTSMODE)
		focusangle = mo.angle;
		focusaiming = 0;
	elseif (sign)
		focusangle = FixedAngle(sign.spawnpoint.angle << FRACBITS) + ANGLE_180;
		focusaiming = 0;
	elseif (player == consoleplayer)
		focusangle = localangle;
		focusaiming = localaiming;
	elseif (player == secondarydisplayplayer)
		focusangle = localangle2;
		focusaiming = localaiming2;
	else
		focusangle = player.cmd.angleturn << 16;
		focusaiming = player.aiming;
	end

--	if (P_CameraThinker(player, thiscam, resetcalled))
--		return true;

--	if (thiscam == &camera)
--	{
-- 		camspeed = cv_cam_speed.value;
		camspeed = kart_cameraspeed.value--FU*4/10
		camstill = cv_cam_still.value;
		camorbit = cv_cam_orbit.value--false;
		camrotate = cv_cam_rotate.value;
-- 		camdist = FixedMul(cv_cam_dist.value, mo.scale);
		camdist = FixedMul(kart_cameradist.value,mapobjectscale)--mapobjectscale*160--mo.scale*160
-- 		camheight = FixedMul(cv_cam_height.value, mo.scale);
		camheight = FixedMul(kart_cameraheight.value, mapobjectscale);
--	}
--	else // Camera 2
--	{
--		camspeed = cv_cam2_speed.value;
--		camstill = cv_cam2_still.value;
--		camorbit = cv_cam2_orbit.value;
--		camrotate = cv_cam2_rotate.value;
--		camdist = FixedMul(cv_cam2_dist.value, mo.scale);
--		camheight = FixedMul(cv_cam2_height.value, mo.scale);
--	}

	if (not (twodlevel or (mo.flags2 & MF2_TWOD)) and not (player.powers[pw_carry] == CR_NIGHTSMODE))
		camheight = FixedMul(camheight, player.camerascale);
	end

--#ifdef REDSANALOG
--	if (P_ControlStyle(player) == CS_LMAOGALOG and (player.cmd.buttons & (BT_CAMLEFT|BT_CAMRIGHT)) == (BT_CAMLEFT|BT_CAMRIGHT)) {
--		camstill = true;
--
--		if (camspeed < 4*FRACUNIT/5)
--			camspeed = 4*FRACUNIT/5;
--	}
--#endif // REDSANALOG

	--kart
	if player.exiting or (player.kartdead and player.kartdead <= TICRATE/5) --hacky because all the code in srb2kart is tangled up and git.do search shows like 5 lines per result
		camstill = true
	elseif player.lookback
		camspeed = FU
		if player.lookback >= 3
			camrotate = $ + 180
		end
	end

	if (mo.eflags & MFE_VERTICALFLIP)
		camheight = $ + thiscam.height;
	end

	if (twodlevel or (mo.flags2 & MF2_TWOD))
		angle = ANGLE_90;
	elseif (camstill or resetcalled or player.playerstate == PST_DEAD or player.kartdead)
		angle = thiscam.angle;
	elseif (player.powers[pw_carry] == CR_NIGHTSMODE) // NiGHTS Level
		if ((player.pflags & PF_TRANSFERTOCLOSEST) and player.axis1 and player.axis2)
			angle = R_PointToAngle2(player.axis1.x, player.axis1.y, player.axis2.x, player.axis2.y);
			angle = $ + ANGLE_90;
		elseif (mo.target)
			if (mo.target.flags2 & MF2_AMBUSH)
				angle = R_PointToAngle2(mo.target.x, mo.target.y, mo.x, mo.y);
			else
				angle = R_PointToAngle2(mo.x, mo.y, mo.target.x, mo.target.y);
			end
		end
-- 	elseif (P_ControlStyle(player) == CS_LMAOGALOG and not sign) // Analog --kart
-- 		angle = R_PointToAngle2(thiscam.x, thiscam.y, mo.x, mo.y);
--	elseif (demoplayback)
--		angle = focusangle;
--		focusangle = R_PointToAngle2(thiscam.x, thiscam.y, mo.x, mo.y);
--		if (player == consoleplayer)
--			if (focusangle >= localangle)
--				P_ForceLocalAngle(player, localangle + (abs((signed)(focusangle - localangle))>>5));
--			else
--				P_ForceLocalAngle(player, localangle - (abs((signed)(focusangle - localangle))>>5));
--			end
--		end
	else
-- 		angle = focusangle + FixedAngle(camrotate*FRACUNIT);
		--kart
		if (camspeed == FRACUNIT)
			angle = focusangle + FixedAngle(camrotate<<FRACBITS);
		else
			local input = anglefix(focusangle + FixedAngle(camrotate<<FRACBITS) - thiscam.angle);
-- 			local invert = (input > ANGLE_180);
			if (input > FU*180)
				input = $ - FU*360;
			elseif (input < FU*-180)
				input = $ + FU*360;
			end

			input = FixedAngle(FixedMul(input, camspeed));
-- 			if (invert)
-- 				input = InvAngle(input);
-- 			end

			angle = thiscam.angle + input;
		end
	end

	--kart
-- 	if (not resetcalled and (cv_analog.value or demoplayback) and ((--[[thiscam == &camera and ]]t_cam_rotate != -42)))-- or (thiscam == &camera2
-- 		--and t_cam2_rotate != -42)))
-- 		angle = FixedAngle(camrotate*FRACUNIT);
-- 		thiscam.angle = angle;
-- 	end

	if (((--[[(thiscam == &camera) and ]]cv_analog.value) or --[[((thiscam != &camera) and cv_analog[1].value) or ]]demoplayback) and not sign and not objectplacing and not (twodlevel or (mo.flags2 & MF2_TWOD)) and (player.powers[pw_carry] != CR_NIGHTSMODE) and displayplayer == consoleplayer)
--#ifdef REDSANALOG
--		if ((player.cmd.buttons & (BT_CAMLEFT|BT_CAMRIGHT)) == (BT_CAMLEFT|BT_CAMRIGHT)); else
--#endif
		if (player.cmd.buttons & BT_CAMRIGHT)
--			if (thiscam == &camera)
				angle = $ - FixedAngle(cv_cam_rotspeed.value*FRACUNIT);
--			else
--				angle -= FixedAngle(cv_cam2_rotspeed.value*FRACUNIT);
--			end
		elseif (player.cmd.buttons & BT_CAMLEFT)
--			if (thiscam == &camera)
				angle = $ + FixedAngle(cv_cam_rotspeed.value*FRACUNIT);
--			else
--				angle += FixedAngle(cv_cam2_rotspeed.value*FRACUNIT);
--			end
		end
	end

	--kart
-- 	if (G_ControlStyle(--[[(thiscam == &camera) ? 1 : 2]]1) == CS_SIMPLE and not sign)
-- 		// Shift the camera slightly to the sides depending on the player facing direction
-- 		local forplayer = --[[(thiscam == &camera) ? 0 : 1]]0;
-- 		local shift = FixedMul(sin(player.mo.angle - angle), cv_cam_shiftfacing.value);

-- 		if (player.powers[pw_carry] == CR_NIGHTSMODE)
-- 			local ccos = cos(player.flyangle * ANG1);
-- 			shift = FixedMul(shift, min(FRACUNIT, player.speed*abs(ccos)/6000));
-- 			shift = $ + FixedMul(camsideshift[forplayer] - shift, FRACUNIT-(camspeed>>2));
-- 		elseif (ticcmd_centerviewdown[--[[(thiscam == &camera) ? 0 : 1]]0])
-- 			shift = FixedMul(camsideshift[forplayer], FRACUNIT-camspeed);
-- 		else
-- 			shift = $ + FixedMul(camsideshift[forplayer] - shift, FRACUNIT-(camspeed>>3));
-- 		end
-- 		camsideshift[forplayer] = shift;

-- 		shift = FixedMul(shift, camdist);
-- 		shiftx = -FixedMul(sin(angle), shift);
-- 		shifty = FixedMul(cos(angle), shift);
-- 	end

	// sets ideal cam pos
-- 	if (twodlevel or (mo.flags2 & MF2_TWOD))
-- 		dist = 480<<FRACBITS;
-- 	elseif (player.powers[pw_carry] == CR_NIGHTSMODE
-- 		or ((maptol & TOL_NIGHTS) and player.capsule and player.capsule.reactiontime > 0 and player == players[player.capsule.reactiontime]))
-- 		dist = 320<<FRACBITS;
-- 	else
		dist = camdist;
-- 		if (sign) // signpost camera has specific placement
-- 			camheight = mo.scale << 7;
-- 			camspeed = FRACUNIT/12;
-- 		elseif (P_ControlStyle(player) == CS_LMAOGALOG) // x1.2 dist for analog
-- 			dist = FixedMul(dist, 6*FRACUNIT/5);
-- 			camheight = FixedMul(camheight, 6*FRACUNIT/5);
-- 		end

	if (player.climbing --[[or player.exiting]] or player.playerstate == PST_DEAD or (player.powers[pw_carry] == CR_ROPEHANG or player.powers[pw_carry] == CR_GENERIC or player.powers[pw_carry] == CR_MACESPIN))
		dist = $ << 1;
	end
-- 	end

	if (not sign and not (twodlevel or (mo.flags2 & MF2_TWOD)) and not (player.powers[pw_carry] == CR_NIGHTSMODE))
		dist = FixedMul(dist, player.camerascale);
	end

	checkdist = dist;

	if (checkdist < 128*FRACUNIT)
		checkdist = 128*FRACUNIT;
	end

	--kart
-- 	if (not (twodlevel or (mo.flags2 & MF2_TWOD)) and not (player.powers[pw_carry] == CR_NIGHTSMODE)) // This block here is like 90% Lach's work, thanks bud
-- 		if (not resetcalled and cv_cam_adjust.value--[[((thiscam == &camera and cv_cam_adjust.value) or (thiscam == &camera2 and cv_cam2_adjust.value))]])
-- 			if (not (mo.eflags & MFE_JUSTHITFLOOR) and (P_IsObjectOnGround(mo)) // Check that player is grounded
-- 			and thiscam.ceilingz - thiscam.floorz >= P_GetPlayerHeight(player)) // Check that camera's sector is large enough for the player to fit into, at least
-- 				if (mo.eflags & MFE_VERTICALFLIP) // if player is upside-down
-- 					//z = min(z, thiscam.ceilingz); // solution 1: change new z coordinate to be at LEAST its ground height
-- 					slopez = $ + min(thiscam.ceilingz - mo.z, 0); // solution 2: change new z coordinate by the difference between camera's ground and top of player
-- 				else // player is not upside-down
-- 					//z = max(z, thiscam.floorz); // solution 1: change new z coordinate to be at LEAST its ground height
-- 					slopez = $ + max(thiscam.floorz - mo.z - mo.height, 0); // solution 2: change new z coordinate by the difference between camera's ground and top of player
-- 				end
-- 			end
-- 		end
-- 	end

	if (player.speed > K_GetKartSpeed(player, false))
		dist = $ + 4*(player.speed - K_GetKartSpeed(player, false));
	end
	dist = $ + abs(thiscam.momz)/4;

	if (player.kartstuff[k_boostcam])
		dist = $ - FixedMul(11*dist/16, player.kartstuff[k_boostcam]);
	end

	if (camorbit) //Sev here, I'm guessing this is where orbital cam lives
--#ifdef HWRENDER
		if (gl and not cv_glshearing.value)
			distxy = FixedMul(dist, cos(focusaiming));
		else
--#endif
			distxy = dist;
		end
		distz = -FixedMul(dist, sin(focusaiming)) + slopez;
	else
		distxy = dist;
		distz = slopez;
	end
	
	if (sign)
		x = sign.x - FixedMul(cos(angle), distxy);
		y = sign.y - FixedMul(sin(angle), distxy);
	else
		x = mo.x - FixedMul(cos(angle), distxy);
		y = mo.y - FixedMul(sin(angle), distxy);
	end

	--kart
	// sets ideal cam pos

-- 	x = mo->x - FixedMul(FINECOSINE((angle>>ANGLETOFINESHIFT) & FINEMASK), dist);
-- 	y = mo->y - FixedMul(FINESINE((angle>>ANGLETOFINESHIFT) & FINEMASK), dist);

	// SRB2Kart: set camera panning
	if (camstill or resetcalled or player.playerstate == PST_DEAD or player.kartdead)
		pan, xpan, ypan = 0, 0, 0;
	else
		if (player.kartstuff[k_drift] != 0)
			local panmax = (dist/5);
			pan = FixedDiv(FixedMul(min(player.kartstuff[k_driftcharge], K_GetKartDriftSparkValue(player)), panmax), K_GetKartDriftSparkValue(player));
			if (pan > panmax)
				pan = panmax;
			end
			if (player.kartstuff[k_drift] < 0)
				pan = $ * -1;
			end
		else
			pan = 0;
		end

		pan = thiscam.pan + FixedMul(pan - thiscam.pan, camspeed/4);

		xpan = FixedMul(cos(((angle+ANGLE_90))), pan);
		ypan = FixedMul(sin(((angle+ANGLE_90))), pan);

		x = $ + xpan;
		y = $ + ypan;
	end

	pviewheight = FixedMul(41*player.height/48, mapobjectscale);

	if (sign)
		if (sign.eflags & MFE_VERTICALFLIP)
			z = sign.ceilingz - pviewheight - camheight;
		else
			z = sign.floorz + pviewheight + camheight;
		end
	else
		if (mo.eflags & MFE_VERTICALFLIP)
			z = mo.z + mo.height - pviewheight - camheight + distz;
		else
			z = mo.z + pviewheight + camheight + distz;
		end
	end

	// move camera down to move under lower ceilings
-- 	newsubsec = R_PointInSubsectorOrNil(((mo.x>>FRACBITS) + (thiscam.x>>FRACBITS))<<(FRACBITS-1), ((mo.y>>FRACBITS) + (thiscam.y>>FRACBITS))<<(FRACBITS-1));

-- 	if (not newsubsec)
-- 		newsubsec = thiscam.subsector;
-- 	end

-- 	if (newsubsec)
-- 		local myfloorz, myceilingz = thiscam.floorz,thiscam.ceilingz;
-- 		local midz = thiscam.z + (thiscam.z - mo.z)/2;
-- 		local midx = ((mo.x>>FRACBITS) + (thiscam.x>>FRACBITS))<<(FRACBITS-1);
-- 		local midy = ((mo.y>>FRACBITS) + (thiscam.y>>FRACBITS))<<(FRACBITS-1);

-- 		// Cameras use the heightsec's heights rather then the actual sector heights.
-- 		// If you can see through it, why not move the camera through it too?
-- 	end

-- 	if (mo.type == MT_EGGTRAP)
-- 		z = mo.z + 128*FRACUNIT + pviewheight + camheight;
-- 	end

-- 	if (thiscam.z < thiscam.floorz and not cameranoclip) --kart
-- 		thiscam.z = thiscam.floorz;
-- 	end

	// point viewed by the camera
	// this point is just 64 unit forward the player
	dist = FixedMul(64 << FRACBITS, mo.scale);
-- 	if (sign)
-- 		viewpointx = sign.x + FixedMul(cos(angle), dist);
-- 		viewpointy = sign.y + FixedMul(sin(angle), dist);
-- 	else
	--kart
	viewpointx = mo.x--[[ + shiftx]] + FixedMul(cos(angle), dist) + xpan;
	viewpointy = mo.y--[[ + shifty]] + FixedMul(sin(angle), dist) + ypan;
-- 	end
	
	if (not camstill and not resetcalled and not paused)
		thiscam.angle = R_PointToAngle2(thiscam.x, thiscam.y, viewpointx, viewpointy);
	end

/*
	if (twodlevel or (mo.flags2 & MF2_TWOD))
		thiscam.angle = angle;
	end
*/
	// follow the player
	/*if (player.playerstate != PST_DEAD and (camspeed) != 0)
	{
		if (P_AproxDistance(mo.x - thiscam.x, mo.y - thiscam.y) > (checkdist + P_AproxDistance(mo.momx, mo.momy)) * 4
			or abs(mo.z - thiscam.z) > checkdist * 3)
		{
			if (not resetcalled)
				P_ResetCamera(player, thiscam);
			return true;
		}
	}*/

	--kart
	if player.exiting or player.kartdead
		thiscam.momx = 0
		thiscam.momy = 0
		thiscam.momz = 0
-- 	if (twodlevel or (mo.flags2 & MF2_TWOD))
	elseif leveltime < 0--starttime
		thiscam.momx = (x-thiscam.x)/4;
		thiscam.momy = (y-thiscam.y)/4;
		thiscam.momz = (z-thiscam.z)/4;
	else
		--kart
		thiscam.momx = x - thiscam.x--FixedMul(x - thiscam.x, camspeed);
		thiscam.momy = y - thiscam.y--FixedMul(y - thiscam.y, camspeed);

-- 		if (thiscam.subsector.sector.damagetype == SD_DEATHPITTILT
-- 			and thiscam.z < thiscam.subsector.sector.floorheight + 256*FRACUNIT
-- 			and FixedMul(z - thiscam.z, camspeed) < 0)
-- 			thiscam.momz = 0; // Don't go down a death pit
-- 		else
			thiscam.momz = FixedMul(z - thiscam.z, camspeed/2); --kart
-- 		end

-- 		thiscam.momx = $ + FixedMul(shiftx, camspeed);
-- 		thiscam.momy = $ + FixedMul(shifty, camspeed);
	end
	
	thiscam.pan = pan --kart

	// compute aming to look the viewed point
	f1 = viewpointx-thiscam.x;
	f2 = viewpointy-thiscam.y;
	dist = FixedHypot(f1, f2);
	
	if (mo.eflags & MFE_VERTICALFLIP)
		angle = R_PointToAngle2(0, thiscam.z + thiscam.height, dist, (sign and sign.ceilingz or mo.z + mo.height) - P_GetPlayerHeight(player));
	else
		angle = R_PointToAngle2(0, thiscam.z, dist, (sign and sign.floorz or mo.z) + P_GetPlayerHeight(player));
	end
	if (player.playerstate != PST_DEAD and not player.kartdead)
		angle = $ + (focusaiming < ANGLE_180 and focusaiming/2 or InvAngle(InvAngle(focusaiming)/2)); // overcomplicated version of '((signed)focusaiming)/2;'
	end

	if (twodlevel or (mo.flags2 & MF2_TWOD) or not camstill) // Keep the view still...
		angle = anglefix(G_ClipAimingPitch(angle));
		dist = thiscam.aiming - angle;
		if dist>180*FU thiscam.aiming=$-360*FU elseif dist<-180*FU thiscam.aiming=$+360*FU end
		dist = thiscam.aiming - angle;
		thiscam.aiming = $ - (dist/8);
	end

	// Make player translucent if camera is too close (only in single player).
--	if (not (multiplayer or netgame) and not splitscreen)
--	{
--		fixed_t vx = thiscam.x, vy = thiscam.y;
--		fixed_t vz = thiscam.z + thiscam.height / 2;
--		if (player.awayviewtics and player.awayviewmobj != NULL and not P_MobjWasRemoved(player.awayviewmobj))		// Camera must obviously exist
--		{
--			vx = player.awayviewmobj.x;
--			vy = player.awayviewmobj.y;
--			vz = player.awayviewmobj.z + player.awayviewmobj.height / 2;
--		}
--
--		/* check z distance too for orbital camera */
--		if (P_AproxDistance(P_AproxDistance(vx - mo.x, vy - mo.y),
--					vz - ( mo.z + mo.height / 2 )) < FixedMul(48*FRACUNIT, mo.scale))
--			mo.flags2 |= MF2_SHADOW;
--		else
--			mo.flags2 &= ~MF2_SHADOW;
--	}
--	else
--		mo.flags2 &= ~MF2_SHADOW;

/*	if (not resetcalled and (player.powers[pw_carry] == CR_NIGHTSMODE and player.exiting))
	{
		// Don't let the camera match your movement.
		thiscam.momz = 0;

		// Only let the camera go a little bit upwards.
		if (mo.eflags & MFE_VERTICALFLIP and thiscam.aiming < FU*315 and thiscam.aiming > FU*180)
			thiscam.aiming = FU*315;
		else if (not (mo.eflags & MFE_VERTICALFLIP) and thiscam.aiming > FU*45 and thiscam.aiming < FU*180)
			thiscam.aiming = FU*45;
	}
	else */if (not resetcalled and (player.playerstate == PST_DEAD or player.playerstate == PST_REBORN))
		// Don't let the camera match your movement.
		thiscam.momz = 0;

		// Only let the camera go a little bit downwards.
		if (not (mo.eflags & MFE_VERTICALFLIP) and thiscam.aiming < FU*337+FU/2 and thiscam.aiming > FU*180)
			thiscam.aiming = FU*337+FU/2;
		elseif (mo.eflags & MFE_VERTICALFLIP and thiscam.aiming > FU*22+FU/2 and thiscam.aiming < FU*180)
			thiscam.aiming = FU*22+FU/2;
		end
	end
	
	--"kart"
	if resetcalled
		P_MoveOrigin(thiscam,x,y,z)
	end
	
	return x == thiscam.x, y == thiscam.y, z == thiscam.z, angle == thiscam.aiming;

end

addHook("PostThinkFrame",do
	if displayplayer and gamestate == GS_LEVEL
		if camobj and camobj.valid and not displayplayer.awayviewtics
			P_RemoveMobj(camobj)
		end
--		print(displayplayer.height/FU)
		if not enabled.value or not displayplayer.kart
--			print(anglefix(camera.aiming),anglefix(displayplayer.aiming)/FU)
--			print(camera.height/FU)
--			print(camera.z/FU)
--			print(camera.angle/ANG1)
			return
		end
		
		local player = displayplayer
		local mo = player.mo
		local pn = player == secondarydisplayplayer and 2 or 1
		
		if not (camobj and camobj.valid) and mo and mo.valid
			camobj = P_SpawnMobj(0,0,0,MT_RAY)
			camobj.state = S_INVISIBLE
			camobj.flags = MF_NOBLOCKMAP|MF_NOSECTOR|MF_NOCLIP|MF_NOCLIPHEIGHT|MF_NOCLIPTHING|MF_NOGRAVITY|MF_SCENERY|MF_NOTHINK
			camobj.radius = 0
			camobj.height = 12*FU
-- 			print("spawning camobj")
			local ox,oy,oz = mo.x,mo.y,mo.z
			P_MoveOrigin(camobj,ox,oy,oz)
			camobj.aiming = 0
			--kart
			camobj.pan = 0
			camobj.angle = mo.angle
			localangle = mo.angle
			localkartangle[pn] = mo.angle
-- 			localaiming = player.aiming
			camobj.chase = camera.chase
			for i=1,TICRATE
				P_MoveChaseCamera(player, camobj, true)
			end
			camobj.z = $-camobj.height
		end
		if mo and mo.valid and camobj and camobj.valid
			player.awayviewmobj = camobj
			player.awayviewtics = 2
--			local ox,oy,oz = mo.x,mo.y,mo.z
--			print("enabled is "..tostring(enabled.value))
			camobj.chase = camera.chase
			localangle = localkartangle[pn]+dlocalkartangle[pn]--mo.angle
			if player.cmd.latency <= 1 or not sync.value --camera "syncing" disabled
				localangle = mo.kartangle
			end
-- 			localaiming = player.aiming
			if P_MobjFlip(mo)>0
				camobj.z = $+20*FU-4*mo.scale
			else
				camobj.z = $+24*FU
			end
			P_SetOrigin(camobj,camobj.x+camobj.momx,camobj.y+camobj.momy,camobj.z+camobj.momz)
			P_TeleportCameraMove(camera,mo.x,mo.y,mo.floorz+mo.height) --minimize camera snapping bug
			P_MoveChaseCamera(player, camobj, resetcalled)
			
--			local rad = 196*FU
--			angle,aiming = mo.angle,player.aiming
--			x = ox - fixmul(fixmul(cos(angle),rad),cos(aiming))
--			y = oy - fixmul(fixmul(sin(angle),rad),cos(aiming))
--			z = oz - fixmul(rad,sin(aiming)) + player.height*3/2 - 12*mo.scale
			
--			cam.momx,cam.momy,cam.momz = 0,0,0
--			P_TeleportCameraMove(cam,x,y,z)
--			if mo.health
--			print(camobj.momz)
			if P_MobjFlip(mo)>0
				camobj.z = $-20*FU+4*mo.scale
			else
				camobj.z = $-24*FU
			end
--			print(camobj.angle/ANG1)
--			end
			
--			local dist = -48*mo.scale
--			local shiftx,shifty = 0,0
--			local vx = mo.x + shiftx + fixmul(cos(angle),dist)
--			local vy = mo.y + shifty + fixmul(sin(angle),dist)
--			local f1,f2 = vx-x,vy-y
--			local aiming2 = R_PointToAngle2(0,z,fixhypot(f1,f2),mo.z+P_GetPlayerHeight(player))
--			aiming2 = $ + (aiming < ANGLE_180 and aiming/2 or InvAngle(InvAngle(aiming)/2))
--			aiming2 = G_ClipAimingPitch(aiming2)
--			aiming = $ + (aiming - aiming2)>>3
--			if aiming > 0 aiming = $ - ANGLE_45 end
--			print(aiming2/ANG1,aiming/ANG1)
--			print(anglefix(aiming)/FU,anglefix(player.aiming)/FU)
--			aiming = R_PointToAngle2(0,z,fixhypot(f1,f2),mo.z+P_GetPlayerHeight(player))
--			camobj.angle = ease.linear(cam_speed,angle)
			player.awayviewaiming = fixangle(camobj.aiming)--ease.linear(cam_speed,G_ClipAimingPitch(aiming))---ANG1*58/10)
--			print(z/FU)
--			camobj.momz = FU
--			cam.z = z
--			cam.angle = angle
--			cam.aiming = aiming
--			cam.radius = 0
--			cam.height = 0
		end
--		camera.angle = angle
--		camera.aiming = aiming
--		P_TeleportCameraMove(camera,x,y,z)
	end
end)