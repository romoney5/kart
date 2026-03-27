rawset(_G,"KITEM_SAD", -1)
rawset(_G,"KITEM_NONE", 0) 
rawset(_G,"KITEM_SNEAKER", 1) 
rawset(_G,"KITEM_ROCKETSNEAKER", 2) 
rawset(_G,"KITEM_INVINCIBILITY", 3) 
rawset(_G,"KITEM_BANANA", 4) 
rawset(_G,"KITEM_EGGMAN", 5) 
rawset(_G,"KITEM_ORBINAUT", 6) 
rawset(_G,"KITEM_JAWZ", 7) 
rawset(_G,"KITEM_MINE", 8) 
rawset(_G,"KITEM_BALLHOG", 9) 
rawset(_G,"KITEM_SPB", 10) 
rawset(_G,"KITEM_GROW", 11) 
rawset(_G,"KITEM_SHRINK", 12) 
rawset(_G,"KITEM_THUNDERSHIELD", 13) 
rawset(_G,"KITEM_HYUDORO", 14) 
rawset(_G,"KITEM_POGOSPRING", 15) 
rawset(_G,"KITEM_KITCHENSINK", 16)

rawset(_G,"NUMKARTITEMS", 17) 

rawset(_G,"KRITEM_TRIPLESNEAKER", 17) 
rawset(_G,"KRITEM_TRIPLEBANANA", 18) 
rawset(_G,"KRITEM_TENFOLDBANANA", 19) 
rawset(_G,"KRITEM_TRIPLEORBINAUT", 20) 
rawset(_G,"KRITEM_QUADORBINAUT", 21) 
rawset(_G,"KRITEM_DUALJAWZ", 22) 

rawset(_G,"NUMKARTRESULTS", 23)
rawset(_G,"KITEM_SUPERRING", 24)

-- rawset(_G,"ITEM_X", 5)
-- rawset(_G,"ITEM_Y", 5)-- + 50)
rawset(_G,"ITEM_X", BASEVIDWIDTH-60)
rawset(_G,"ITEM_Y", 5)-- + 50)

-- rawset(_G,"TIME_X", BASEVIDWIDTH-148)
-- rawset(_G,"TIME_Y", 9)
rawset(_G,"TIME_X", 9)
rawset(_G,"TIME_Y", 9)

rawset(_G,"LAPS_X", 9)
rawset(_G,"LAPS_Y", BASEVIDHEIGHT-29)
rawset(_G,"cv_numlaps", CV_FindVar("numlaps"))

rawset(_G,"POSI_X", BASEVIDWIDTH  - 9)
rawset(_G,"POSI_Y", BASEVIDHEIGHT - 9)

rawset(_G,"stealtime", TICRATE/2)
rawset(_G,"sneakertime", TICRATE + (TICRATE/3))
rawset(_G,"itemtime", 8*TICRATE)

rawset(_G,"rubberbandtime", TICRATE*6)
rawset(_G,"rubberbandstrength", FU)

// Basic gameplay things
rawset(_G,"k_position", 0) 			// Used for Kart positions, mostly for deterministic stuff
rawset(_G,"k_oldposition", 1) 		// Used for taunting when you pass someone
rawset(_G,"k_positiondelay", 2) 	// Used for position number, so it can grow when passing/being passed
rawset(_G,"k_prevcheck", 3) 		// Previous checkpoint distance; for p_user.c (was "pw_pcd")
rawset(_G,"k_nextcheck", 4) 		// Next checkpoint distance; for p_user.c (was "pw_ncd")
rawset(_G,"k_waypoint", 5) 			// Waypoints.
rawset(_G,"k_starpostwp", 6) 		// Temporarily stores player waypoint for... some reason. Used when respawning and finishing.
rawset(_G,"k_starpostflip", 7) 		// the last starpost we hit requires flipping?
rawset(_G,"k_respawn", 8) 			// Timer for the DEZ laser respawn effect
rawset(_G,"k_dropdash", 9) 			// Charge up for respawn Drop Dash

rawset(_G,"k_throwdir", 10) 		// Held dir of controls; 1 = forward, 0 = none, -1 = backward (was "player->heldDir")
rawset(_G,"k_lapanimation", 11) 	// Used to show the lap start wing logo animation
rawset(_G,"k_laphand", 12) 			// Lap hand gfx to use; 0 = none, 1 = :ok_hand:, 2 = :thumbs_up:, 3 = :thumps_down:
rawset(_G,"k_cardanimation", 13) 	// Used to determine the position of some full-screen Battle Mode graphics
rawset(_G,"k_voices", 14) 			// Used to stop the player saying more voices than it should
rawset(_G,"k_tauntvoices", 15) 		// Used to specifically stop taunt voice spam
rawset(_G,"k_instashield", 16) 		// Instashield no-damage animation timer
rawset(_G,"k_enginesnd", 17) 		// Engine sound number you're on.

rawset(_G,"k_floorboost", 18) 		// Prevents Sneaker sounds for a breif duration when triggered by a floor panel
rawset(_G,"k_spinouttype", 19) 		// Determines whether to thrust forward or not while spinning out; 0 = move forwards, 1 = stay still

rawset(_G,"k_drift", 20) 			// Drifting Left or Right, plus a bigger counter = sharper turn
rawset(_G,"k_driftend", 21) 		// Drift has ended, used to adjust character angle after drift
rawset(_G,"k_driftcharge", 22) 		// Charge your drift so you can release a burst of speed
rawset(_G,"k_driftboost", 23) 		// Boost you get from drifting
rawset(_G,"k_boostcharge", 24) 		// Charge-up for boosting at the start of the race
rawset(_G,"k_startboost", 25) 		// Boost you get from start of race or respawn drop dash
rawset(_G,"k_jmp", 26) 				// In Mario Kart, letting go of the jump button stops the drift
rawset(_G,"k_offroad", 27) 			// In Super Mario Kart, going offroad has lee-way of about 1 second before you start losing speed
rawset(_G,"k_pogospring", 28) 		// Pogo spring bounce effect
rawset(_G,"k_brakestop", 29) 		// Wait until you've made a complete stop for a few tics before letting brake go in reverse.
rawset(_G,"k_waterskip", 30) 		// Water skipping counter
rawset(_G,"k_dashpadcooldown", 31) 	// Separate the vanilla SA-style dash pads from using pw_flashing
rawset(_G,"k_boostpower", 32) 		// Base boost value, for offroad
rawset(_G,"k_speedboost", 33) 		// Boost value smoothing for max speed
rawset(_G,"k_accelboost", 34) 		// Boost value smoothing for acceleration
rawset(_G,"k_boostangle", 35) 		// angle set when not spun out OR boosted to determine what direction you should keep going at if you're spun out and boosted.
rawset(_G,"k_boostcam", 36) 		// Camera push forward on boost
rawset(_G,"k_destboostcam", 37) 	//
rawset(_G,"k_timeovercam", 38) 		// Camera timer for leaving behind or not
rawset(_G,"k_aizdriftstrat", 39) 	// Let go of your drift while boosting? Helper for the SICK STRATZ you have just unlocked
rawset(_G,"k_brakedrift", 40) 		// Helper for brake-drift spark spawning

rawset(_G,"k_itemroulette", 41) 	// Used for the roulette when deciding what item to give you (was "pw_kartitem")
rawset(_G,"k_roulettetype", 42) 	// Used for the roulette, for deciding type (currently only used for Battle, to give you better items from Karma items)

// Item held stuff
rawset(_G,"k_itemtype", 43) 		// KITEM_ constant for item number
rawset(_G,"k_itemamount", 44) 		// Amount of said item
rawset(_G,"k_itemheld", 45) 		// Are you holding an item?

// Some items use timers for their duration or effects
//k_thunderanim,					// Duration of Thunder Shield's use animation
rawset(_G,"k_curshield", 46) 		// 0 = no shield, 1 = thunder shield
rawset(_G,"k_hyudorotimer", 47) 	// Duration of the Hyudoro offroad effect itself
rawset(_G,"k_stealingtimer", 48) 	// You are stealing an item, this is your timer
rawset(_G,"k_stolentimer", 49) 		// You are being stolen from, this is your timer
rawset(_G,"k_sneakertimer", 50) 	// Duration of the Sneaker Boost itself
rawset(_G,"k_growshrinktimer", 51) 	// > 0 = Big, < 0 = small
rawset(_G,"k_squishedtimer", 52) 	// Squished frame timer
rawset(_G,"k_rocketsneakertimer",53)// Rocket Sneaker duration timer
rawset(_G,"k_invincibilitytimer",54)// Invincibility timer
rawset(_G,"k_eggmanheld", 55) 		// Eggman monitor held, separate from k_itemheld so it doesn't stop you from getting items
rawset(_G,"k_eggmanexplode", 56) 	// Fake item recieved, explode in a few seconds
rawset(_G,"k_eggmanblame", 57) 		// Fake item recieved, who set this fake
rawset(_G,"k_lastjawztarget", 58) 	// Last person you target with jawz, for playing the target switch sfx
rawset(_G,"k_bananadrag", 59) 		// After a second of holding a banana behind you, you start to slow down
rawset(_G,"k_spinouttimer", 60) 	// Spin-out from a banana peel or oil slick (was "pw_bananacam")
rawset(_G,"k_wipeoutslow", 61) 		// Timer before you slowdown when getting wiped out
rawset(_G,"k_justbumped", 62) 		// Prevent players from endlessly bumping into each other
rawset(_G,"k_comebacktimer", 63) 	// Battle mode, how long before you become a bomb after death
rawset(_G,"k_sadtimer", 64) 		// How long you've been sad

// Battle Mode vars
rawset(_G,"k_bumper", 65) 			// Number of bumpers left
rawset(_G,"k_comebackpoints", 66) 	// Number of times you've bombed or gave an item to someone; once it's 3 it gets set back to 0 and you're given a bumper
rawset(_G,"k_comebackmode", 67) 	// 0 = bomb, 1 = item
rawset(_G,"k_wanted", 68) 			// Timer for determining WANTED status, lowers when hitting people, prevents the game turning into Camp Lazlo
rawset(_G,"k_yougotem", 69) 		// "You Got Em" gfx when hitting someone as a karma player via a method that gets you back in the game instantly

// v1.0.2+ vars
rawset(_G,"k_itemblink", 70) 		// Item flashing after roulette, prevents Hyudoro stealing AND serves as a mashing indicator
rawset(_G,"k_itemblinkmode", 71) 	// Type of flashing: 0 = white (normal), 1 = red (mashing), 2 = rainbow (enhanced items)
rawset(_G,"k_getsparks", 72) 		// Disable drift sparks at low speed, JUST enough to give acceleration the actual headstart above speed
rawset(_G,"k_jawztargetdelay", 73) 	// Delay for Jawz target switching, to make it less twitchy
rawset(_G,"k_spectatewait", 74) 	// How long have you been waiting as a spectator
rawset(_G,"k_growcancel", 75) 		// Hold the item button down to cancel Grow

--https://git.do.srb2.org/KartKrew/RingRacers/-/commit/129268121dc574142d8d5d7ab6d0bd531525a5a0
--https://git.do.srb2.org/KartKrew/RingRacers/-/commit/25c3774dc1eaf00f8b06e4aea9decd088d01ddd2 boost stacking
rawset(_G,"k_rings", 76)			// Number of held rings
rawset(_G,"k_ringdelay", 77)		// 3 tic delay between every ring usage
rawset(_G,"k_ringboost", 78)		// Ring boost timer
rawset(_G,"k_superring", 79)		// Spawn rings on top of you every tic!

rawset(_G,"k_numsneakers", 80)		// Number of stacked sneaker effects
rawset(_G,"k_handleboost",81)
rawset(_G,"k_numboosts",82)

rawset(_G,"k_driftspeed",83) --speed multiplier for drift boosts, homemade ring racers version

rawset(_G,"k_kartstuffamount", k_driftspeed)