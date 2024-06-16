#define SERVER_ONLY
#include "Booty.as";
#include "ShipsCommon.as";
#include "MakeBlock.as";
#include "SoftBans.as";

const u8 STATION_BOOTY = 5;

void onInit(CRules@ this)
{
	Reset(this);
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void Reset(CRules@ this)
{
	this.set_u8("endCount", 0);
	
	setStartingBooty(this);
	server_resetTotalBooty(this);
	
	this.SetGlobalMessage("");
	this.SetCurrentState(WARMUP);
}

void onTick(CRules@ this)
{
	const u32 gameTime = getGameTime();
	
	//check for minimum resources on captains
	if (gameTime % 150 == 0 && !this.get_bool("whirlpool"))
	{
		const u16 minBooty = this.get_u16("bootyRefillLimit");
		ShipDictionary@ ShipSet = getShipSet(this);
		CBlob@[] cores;
		getBlobsByTag("mothership", @cores);
		
		const u8 coresLength = cores.length;
		for (u8 i = 0; i < coresLength; i++)
		{
			const int coreCol = cores[i].getShape().getVars().customData;
			if (coreCol <= 0) continue;
			
			Ship@ ship = ShipSet.getShip(coreCol);
			if (ship is null || ship.owner.isEmpty() || ship.owner == "*") continue;
			
			const u16 captainBooty = server_getPlayerBooty(ship.owner);
			if (captainBooty < minBooty)
			{
				CPlayer@ player = getPlayerByUsername(ship.owner);
				if (player is null) continue;
				
				//consider blocks to propellers ratio
				u16 propellers = 1;
				u16 couplings = 0;
				const u16 blocksLength = ship.blocks.length;
				for (u16 q = 0; q < blocksLength; ++q)
				{
					CBlob@ b = getBlobByNetworkID(ship.blocks[q].blobID);
					if (b !is null)
					{
						if (b.hasTag("engine"))
							propellers++;
						else if (b.hasTag("coupling"))
							couplings++;
					}
				}

				if (((blocksLength - propellers - couplings)/propellers > 3) || this.isWarmup())
				{
					CBlob@ pBlob = player.getBlob();
					u16[] blocks;
					if (pBlob !is null && pBlob.get("blocks", blocks) && blocks.size() == 0)
						server_addPlayerBooty(ship.owner, Maths::Min(15, minBooty - captainBooty));
				}
			}
		}
		
		//give booty to teams with captured stations
		const u8 plyCount = getPlayersCount();
		for (u8 i = 0; i < plyCount; ++i)
		{
			CPlayer@ player = getPlayer(i);
			if (player is null)	continue;
			
			const u8 pteam = player.getTeamNum();
			u8 pStationCount = 0;
			CBlob@[] stations;
			getBlobsByTag("booty_station", @stations);
			const u8 stationsLength = stations.length;
			for (u8 u = 0; u < stationsLength; u++)
			{
				if (stations[u].getTeamNum() == pteam)
					pStationCount++;
			}
			
			CBlob@ pBlob = player.getBlob();
			if (pBlob !is null)
			{
				server_addPlayerBooty(player.getUsername(), (STATION_BOOTY * pStationCount));
				server_updateTotalBooty(pteam, (STATION_BOOTY * pStationCount));
			}
		}
	}
	
	//after some secs, balance starting booty for teams with less players than the average
	if (gameTime == 500)
	{
		CBlob@[] cores;
		getBlobsByTag("mothership", @cores);
		const u8 teams = cores.length;
		const u16 initBooty = Maths::Round(getRules().get_u16("starting_booty") * 0.75f);
		const u8 players = getPlayersCount();
		const u8 median = teams <= 0 ? 1 : Maths::Round(players/teams);
		
		//player per team
		const u8 teamsNum = this.getTeamsNum();
		u8[] teamPlayers(teamsNum);
		
		for (u8 p = 0; p < players; p++)
		{
			u8 team = getPlayer(p).getTeamNum();
			if (team < teamsNum)
				teamPlayers[team]++;
		}
		
		print("** Balancing booty: median = " + median + " for " + players + " players in " + teams + " teams");
		//balance booty
		for (u8 p = 0; p < players; p++)
		{
			CPlayer@ player = getPlayer(p);
			const u8 team = player.getTeamNum();
			if (team >= teamsNum) continue;
				
			const f32 compensate = median/teamPlayers[team];
			if (compensate > 1)
			{
				const u16 balance = Maths::Round(initBooty * compensate/teamPlayers[team] - initBooty);
				string name = player.getUsername();
				server_setPlayerBooty(name, balance);
			}
		}
	}
	
	//check game states
	if (gameTime % 30 == 0)
	{
		//end warmup time
		if (this.isWarmup() && (gameTime > this.get_u16("warmup_time") || this.get_bool("freebuild")))
		{
			this.SetCurrentState(GAME);
		}
		
		//check if the game has ended
		CBlob@[] cores;
		getBlobsByTag("mothership", cores);
		
		const u8 coresLength = cores.length;
		
		const bool oneTeamLeft = coresLength <= 1;
		const u8 endCount = this.get_u8("endCount");
		
		if (oneTeamLeft && endCount == 0)//start endmatch countdown
			this.set_u8("endCount", 15);
		
		if (endCount != 0)
		{
			this.set_u8("endCount", Maths::Max(endCount - 1, 1));
			if (endCount == 11)
			{
				u8 teamWithPlayers = 0;
				if (!this.isGameOver())
				{
					const u8 plyCount = getPlayerCount();
					for (u8 coreIt = 0; coreIt < coresLength; coreIt++)
					{
						for (u8 i = 0; i < plyCount; i++)
						{
							CPlayer@ player = getPlayer(i);
							if (player.getBlob() !is null)
								teamWithPlayers = player.getTeamNum();
						}
					}
				}
				u8 coresAlive = 0;
				for (u8 i = 0; i < coresLength; i++)
				{
					if (!cores[i].hasTag("critical"))
					coresAlive++;
				}

				if (coresAlive > 0)
				{
					string captain = "";
					CBlob@ mShip = getMothership(teamWithPlayers);
					if (mShip !is null)
					{
						Ship@ ship = getShipSet(this).getShip(mShip.getShape().getVars().customData);
						if (ship !is null && !ship.owner.isEmpty() && ship.owner != "*")
						{
							const string lastChar = ship.owner.substr(ship.owner.length() -1);
							captain = ship.owner + (lastChar == "s" ? "' " : "'s ");
						}
						this.SetGlobalMessage(captain + this.getTeam(mShip.getTeamNum()).getName() + " Wins!");
					}
				}
				else
					this.SetGlobalMessage("Game Over! "+ getTranslatedString("It's a tie!"));
				
				this.SetCurrentState(GAME_OVER);
			}
        }
	}
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	const string pName = player.getUsername();
	const u16 pBooty = server_getPlayerBooty(pName);
	const u16 minBooty = Maths::Round(this.get_u16("bootyRefillLimit") / 2);
	
	if (sv_test)
		server_setPlayerBooty(pName, 9999);
	else if (pBooty > minBooty)
	{
		this.set_u16("booty" + pName, pBooty);
		this.Sync("booty" + pName, true);
	}
	else
		server_setPlayerBooty(pName, !this.isWarmup() ? minBooty : this.get_u16("starting_booty"));
}

bool onServerProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	if (player is null) return true;

	//for testing
	if (sv_test || player.isMod() || true)
	{
		if (text_in.substr(0,1) == "!")
		{
			string[]@ tokens = text_in.split(" ");
			const u8 tokensLength = tokens.length;
			if (tokensLength > 1)
			{
				if (tokens[0] == "!kick") //force kick player of choice by username or player ID
				{
					CPlayer@ kickedPly = getPlayerByUsername(tokens[1]);
					if (kickedPly is null)
						@kickedPly = getPlayerByNetworkId(parseInt(tokens[1]));
					if (kickedPly !is null)
					{
						error(">> "+player.getUsername()+" kicked player "+kickedPly.getUsername()+" <<");
						getNet().server_SendMsg(">> Kicking Player "+kickedPly.getUsername()+" <<");
						KickPlayer(kickedPly);
						return true;
					}
					warn("!kick:: Player "+tokens[1]+" does not exist!");
					return true;
				}
				else if (tokens[0] == "!ban" && tokensLength > 2) //soft ban someone
				{
					const s32 ban_time = parseInt(tokens[2]) > -1 ? parseInt(tokens[2])*60 : -1;
					const string description = "banned by moderator: "+player.getUsername()+(tokensLength > 3 ? ", "+tokens[3] : "");
					
					server_SoftBan(tokens[1], ban_time, description);
					return true;
				}
				else if (tokens[0] == "!freeze")
				{
					CPlayer@ ply = getPlayerByUsername(tokens[1]);
					if (ply !is null)
					{
						ply.freeze = !ply.freeze;
						if (!ply.freeze)
						{
							CBlob@ b = ply.getBlob();
							if (b !is null) b.server_Die();
						}
						return true;
					}
					
					warn("!freeze:: player "+tokens[1]+" not found!");
					return false;
				}
				else if (tokens[0] == "!addbot") //add a bot to the server. Supports names & teams
				{
					if (tokensLength > 2)
						AddBot(tokens[1], parseInt(tokens[2]), 0);
					else
						AddBot(tokens[1]);
					
					return true;
				}
				else if (tokens[0] == "!hash") //gives encoded hash for the word you input
				{
					const string word = text_in.replace("!hash ", "");
					print(word.getHash() + " : "+ word, color_white);
					
					return false;
				}
				else if (tokens[0] == "!crit") //kill defined mothership
				{
					CBlob@ mothership = getMothership(parseInt(tokens[1]));
					if (mothership !is null)
						mothership.server_Hit(mothership, mothership.getPosition(), Vec2f_zero, 50.0f, 0, true);
				}
				else if (tokens[0] == "!playsound") //play a sound (only works localhost)
				{
					Sound::Play(tokens[1]);
					return false;
				}
				
				CBlob@ pBlob = player.getBlob();
				if (pBlob is null) return false;
				
				if (tokens[0] == "!team") //change your team or another player's team
				{
					if (tokensLength > 2)
					{
						CPlayer@ nameplayer = getPlayerByUsername(tokens[1]);
						if (nameplayer !is null)
						{
							nameplayer.server_setTeamNum(parseInt(tokens[2]));
							if (nameplayer.getBlob() !is null)
								nameplayer.getBlob().server_Die();
						}
					}
					else
					{
						player.server_setTeamNum(parseInt(tokens[1]));
						pBlob.server_Die();
					}
					
					return false;
				}
				else if (tokens[0] == "!tp") //teleport to player, uses playername or playerID
				{
					//this command also has support to teleport other players to our player. E.g "!tp (player) here"
					const string word = text_in.replace("!tp ", "").replace(" here", "");
					CPlayer@ ply = getPlayerByUsername(word);
					if (ply is null)
						@ply = getPlayerByNetworkId(parseInt(tokens[1]));
					if (ply is null) 
					{
						warn("!tp:: Player not found: "+ tokens[1]);
						return false;
					}
					
					CBlob@ b = ply.getBlob();
					if (b is null) return false;
					
					if (text_in.find(" here") >= 0)
					{
						print("Teleported "+ply.getUsername()+" to "+player.getUsername()+" ("+ply.getNetworkID()+")", color_white);
						b.setPosition(pBlob.getPosition()); //teleport to player!
					}
					else
					{
						print("Teleported "+player.getUsername()+" to "+ply.getUsername()+" ("+b.getNetworkID()+")", color_white);
						pBlob.setPosition(b.getPosition()); //teleport player here!
					}
					
					return false;
				}
				else if (tokens[0] == "!class") //change your player blob (shark etc)
				{
					CBlob@ b = server_CreateBlob(tokens[1], pBlob.getTeamNum(), pBlob.getPosition());
					if (b !is null)
					{
						b.server_SetPlayer(player);
						pBlob.server_Die();
						print("Setting "+player.getUsername()+" to "+tokens[1], color_white);
					}
					return false;
				}
				else if (tokens[0] == "!teambooty" && tokens.length > 2) //change a team's total booty
				{
					if (this.exists("bootyTeam_total" + tokens[1]))
						this.set_u16("bootyTeam_total" + tokens[1], parseInt(tokens[2]));
					return false;
				}
				else if (tokens[0] == "!booty") //give or take defined amount of booty
				{
					error(player.getUsername()+" cheating for "+parseInt(tokens[1])+" booty, bad!");
					server_addPlayerBooty(player.getUsername(), parseInt(tokens[1]));
					return false;
				}
				else if (tokens[0] == "!teamchange") //change your player blobs team without dying
				{
					player.server_setTeamNum(parseInt(tokens[1]));
					pBlob.server_setTeamNum(parseInt(tokens[1]));
				}
				else if (tokens[0] == "!saveship") //all players can save their ship
				{
					ConfigFile cfg;
					
					Vec2f playerPos = pBlob.getPosition();
					Ship@ ship = getOverlappingShip(pBlob);
					if (ship is null)
					{
						warn("!saveship:: No ship found!");
						return false;
					}
					const u16 numBlocks = ship.blocks.length;
					cfg.add_u16("total blocks", numBlocks);
					for (u16 i = 0; i < numBlocks; ++i)
					{
						ShipBlock@ ship_block = ship.blocks[i];
						if (ship_block is null) continue;

						CBlob@ block = getBlobByNetworkID(ship_block.blobID);
						if (block is null) continue;
						
						cfg.add_string("block" + i + "type", block.getName());
						cfg.add_f32("block" + i + "positionX", (block.getPosition().x - playerPos.x));
						cfg.add_f32("block" + i + "positionY", (block.getPosition().y - playerPos.y));
						cfg.add_f32("block" + i + "angle", block.getAngleDegrees());
					}
					cfg.saveFile("Shiprekt/SHIP_" + tokens[1] + ".cfg");
					print("Saved ship as: "+tokens[1], color_white);
				}
				else if (tokens[0] == "!loadship") //load in a ship from a cfg name
				{
					ConfigFile cfg;
					
					if (!cfg.loadFile("../Cache/Shiprekt/SHIP_" + tokens[1] + ".cfg"))
					{
						warn("Failed to load ship "+tokens[1]);
						return false;
					}
					
					Vec2f playerPos = pBlob.getPosition();
				
					const u16 numBlocks = cfg.read_u16("total blocks");
					for (u16 i = 0; i < numBlocks; ++i)
					{	
						string blockType = cfg.read_string("block" + i + "type");
						f32 blockPosX = cfg.read_f32("block" + i + "positionX");
						f32 blockPosY = cfg.read_f32("block" + i + "positionY");
						f32 blockAngle = cfg.read_f32("block" + i + "angle");
						
						makeBlock(playerPos + Vec2f(blockPosX, blockPosY), blockAngle, blockType, pBlob.getTeamNum());
					}
					print(player.getUsername()+" Generated ship "+tokens[1], color_white);
				}
			}
			else
			{
				if (tokens[0] == "!deleteship") //kill a ship
				{
					CBlob@ pBlob = player.getBlob();
					if (pBlob is null) return false;
					
					Ship@ ship = getOverlappingShip(player.getBlob());
					if (ship !is null)
					{
						const u16 numBlocks = ship.blocks.length;
						for (u16 i = 0; i < numBlocks; ++i)
						{
							ShipBlock@ ship_block = ship.blocks[i];
							if (ship_block is null) continue;

							CBlob@ block = getBlobByNetworkID(ship_block.blobID);
							if (block is null) continue;
							
							if (!block.hasTag("mothership") || numBlocks == 1)
								block.server_Die();
						}
						print(player.getUsername()+" destroyed "+numBlocks+" blocks", color_white);
					}
				}
				else if (tokens[0] == "!clearmap") //destroys all the blocks
				{
					CBlob@[] blocks;
					if (getBlobsByTag("block", @blocks))
					{
						const u16 blocksLength = blocks.length;
						for (u16 i = 0; i < blocksLength; ++i)
						{
							CBlob@ block = blocks[i];
							if (block is null) continue;
							
							if (!block.hasTag("mothership"))
								block.server_Die();
						}
						print("Clearing "+blocksLength+" blocks", color_white);
					}
					return false;
				}
				else if (tokens[0] == "!debugship") //print ship infos
				{
					CBlob@ pBlob = player.getBlob();
					if (pBlob is null) return false;
					
					Ship@ ship = getOverlappingShip(pBlob);
					if (ship is null)
					{
						warn("!debugship:: no ship found");
						return false;
					}
					
					string shipType = !ship.owner.isEmpty() ? "Miniship" : "";
					if (ship.isMothership) shipType = "Mothership";
					if (ship.isSecondaryCore) shipType += (shipType.length > 0 ? ", " : "")+"Secondary Core";
					if (ship.isStation) shipType += (shipType.length > 0 ? ", " : "")+"Station";
					
					//RGB cause cool
					print("---- SHIP "+ship.id+" ----", color_white);
					print("Type: "+shipType, SColor(255, 235, 30, 30));
					print("Owner: "+ship.owner, SColor(255, 255, 165, 0));
					print("Speed: "+ship.vel.LengthSquared(), SColor(255, 235, 235, 0));
					print("Angle Vel: "+ship.angle_vel, SColor(255, 30, 220, 30));
					print("Angle: "+ship.angle, SColor(255, 173, 216, 200));
					print("Mass: "+ship.mass, SColor(255, 77, 100, 195));
					print("Blocks: "+ship.blocks.length, SColor(255, 168, 50, 168));
					
					return false;
				}
				else if (tokens[0] == "!list") //print all available shiprekt commands
				{
					print("\n      >>    Tankrekt COMMANDS LIST    <<\n"+
						  "\n !kick [playername] : kick the specified player."+
						  "\n !ban [playername OR IP address] [minutes] [reason] : soft ban the specified player. -1 for perm."+
						  "\n !freeze [playername] : freeze or unfreeze player. works mechanically better than F2/F3 freeze method."+
						  "\n !addbot [botname] [team] : add a bot to the server. [team] is optional."+
						  "\n !hash [string] : print the hashcode of a string. originally used for debugging purposes."+
						  "\n !tp [playername OR playerID] ['here'] : teleport to a player, add the token 'here' to do the opposite."+
						  "\n !class [blobname] : change your player's blob. mostly useful for changing between human and shark."+
						  "\n !teambooty [team] [amount] : change booty of the selected team."+
						  "\n !booty [amount] : give booty to your player. use negative integers to remove booty instead."+
						  "\n !teamchange [teamnum] : change your player's team without dying."+
						  "\n !crit [teamnum] : instantly kill a team's mothership core."+
						  "\n !spawnmothership [teamnum] : spawn a new starter mothership for the specified team. see !dirty."+
						  "\n !ds [deltasmoothness] : set the delta smoothness. ignore the parameter to print the current ds."+
						  "\n !playsound [soundname] : play specified sound. only works on localhost."+
						  "\n !saveship [shipname] : save a ship to your cache for later use."+
						  "\n !loadship [shipname] : load a previously saved ship to be used again. see !dirty."+
						  "\n !dirty : activate loaded ships."+
						  "\n !deleteship : kills the ship your player is on."+
						  "\n !clearmap : removes all the blocks on the map."+
						  "\n !candy : toggle shiprekt debug mode on/off, very cool for modders!"+
						  "\n !debugship : prints information about the ship your player is on."+
						  "\n !bc : prints the amount of blocks on the server."+
						  "\n !props : activates all propeller engines on the server."+
						  "\n !freebuild : toggle free-build mode on or off."+
						  "\n !sd : spawn a whirlpool in the center of the map."+
						  "\n !pinball : fun."+
						  "\n !lego : loosen it up."+
						  "\n !list : this! \n", color_white);
					return false;
				}
				else if (tokens[0] == "!bc") //print block count
				{
					CBlob@[] blocks;
					getBlobsByTag("block", @blocks);
					print("Server block count: "+blocks.length, color_white);
					return false;
				}
				else if (tokens[0] == "!dirty") //activate dirty ships 
				{
					this.set_bool("dirty ships", true);
					return false;
				}
				else if (tokens[0] == "!props") //activate all propellers
				{
					CBlob@[] blocks;
					getBlobsByTag("engine", @blocks);
					const u32 gameTime = getGameTime();
					const u16 blocksLength = blocks.length;
					print("Turning on "+blocksLength+" propellers", color_white);
					for (u16 i = 0; i < blocksLength; ++i)
					{
						CBlob@ prop = blocks[i];
						prop.set_f32("power", -1.0f);
						prop.set_u32("onTime", gameTime);
					}
					return false;
				}
				else if (tokens[0] == "!freebuild") //toggle freebuild mode
				{
					getNet().server_SendMsg("*** "+player.getUsername()+" set freebuild mode "+ (this.get_bool("freebuild") ? "off" : "on") +" ***");
					CBitStream params;
					params.write_string("freebuild");
					params.write_bool(!this.get_bool("freebuild"));
					this.SendCommand(this.getCommandID("sync bool"), params);
					return false;
				}
				else if (tokens[0] == "!sd") //spawn a whirlpool
				{
					const Vec2f mapCenter = getMap().getMapDimensions()/2;
					server_CreateBlob("whirlpool", 0, mapCenter);
				}
				else if (tokens[0] == "!pinball") //pinball machine
				{
					//commence pain
					ShipDictionary@ ShipSet = getShipSet(this);
					Ship@[] ships = ShipSet.getShips();
					
					const u16 shipsLength = ships.length;
					for (u16 i = 0; i < shipsLength; ++i)
					{
						Ship@ ship = ships[i];
						if (ship is null) continue;
						
						ship.angle_vel += (180 + XORRandom(180)) * (XORRandom(2) == 0 ? 1 : -1);
						ship.vel += Vec2f(XORRandom(50) * (XORRandom(2) == 0 ? 1 : -1), XORRandom(50)* (XORRandom(2) == 0 ? 1 : -1));
					}
				}
				else if (tokens[0] == "!lego") //loosen the bolts
				{
					//commence pain
					CBlob@[] blocks;
					getBlobsByTag("block", @blocks);
					
					const u16 blobsLength = blocks.length;
					for (u16 i = 0; i < blobsLength; ++i)
					{
						CBlob@ block = blocks[i];
						const u32 col = XORRandom(2)+1;
						block.set_u16("last color", col);
						block.getShape().getVars().customData = 0;
					}
					
					getShipSet(this).deleteAll();
					this.set_bool("dirty ships", true);
				}
			}
		}
	}
	
	return hasSoftBanExpired(player);
}
