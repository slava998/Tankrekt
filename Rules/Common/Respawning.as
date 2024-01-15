#define SERVER_ONLY
#include "ShipsCommon.as";
#include "SoftBans.as";
#include "SpawnPointIDs.as";

const string PLAYER_BLOB = "human";
const string SPAWN_TAG = "mothership";

const u32 standardRespawnTime = 7 * getTicksASecond();
const u32 specToTeamRespawnTime = 10 * getTicksASecond();

shared class Respawn
{
	string username;
	u32 timeStarted;

	Respawn(const string _username, const u32 _timeStarted)
	{
		username = _username;
		timeStarted = _timeStarted;
	}
};

void onInit(CRules@ this)
{
	SetupRespIDs(this);
	Respawn[] respawns;
	this.set("respawns", respawns);
	onRestart(this);
}

void onReload(CRules@ this)
{
	this.clear("respawns");
	const u32 gameTime = getGameTime();
	const u8 specNum = this.getSpectatorTeamNum();
	const u8 plyCount = getPlayerCount();
	for (u8 i = 0; i < plyCount; i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player.getBlob() is null && player.getTeamNum() != specNum)
		{
			Respawn r(player.getUsername(), gameTime);
			this.push("respawns", r);
			syncRespawnTime(this, player, gameTime);
		}
	}
}

void onRestart(CRules@ this)
{
	this.clear("respawns");
	
	CPlayer@[] players;
	const u32 gameTime = getGameTime();
	const u8 specNum = this.getSpectatorTeamNum();
	const u8 plyCount = getPlayerCount();
	for (u8 i = 0; i < plyCount; i++)
	{
		CPlayer@ player = getPlayer(i);
		const bool isSpec = player.getTeamNum() == specNum;
		if (!isSpec || !hasSoftBanExpired(player))
		{
			if (!isSpec)
				players.push_back(player);
			
			//spawn players!
			Respawn r(player.getUsername(), gameTime);
			this.push("respawns", r);
			syncRespawnTime(this, player, gameTime);
		}
	}
	
	//assign player teams
	if (players.length > 0)
		assignTeams(this, players);
}

void assignTeams(CRules@ this, CPlayer@[] players)
{
	//equally distribute players
	
	CBlob@[] cores;
	getBlobsByTag(SPAWN_TAG, cores); //get available teams for the map
	const u8 coresLength = cores.length;
	u8 currentTeam = XORRandom(coresLength);
	
	while (!players.isEmpty())
	{
		const u8 randPlayer = XORRandom(players.length); //randomize selection
		CPlayer@ player = players[randPlayer];
		
		//print("assignTeams: assigning " + player.getUsername() +" "+cores[currentTeam].getTeamNum());
		player.server_setTeamNum(cores[currentTeam].getTeamNum());
		
		if (currentTeam + 2 > coresLength)
			currentTeam = 0;
		else currentTeam++;
		
		players.removeAt(randPlayer);
	}
}

void assignTeam(CRules@ this, CPlayer@ player)
{
	//assigns the player to the team with the lowest amount of players.
	//in case there is multiple teams with the lowest amount of players, it will select the team with the lowest team-booty.

	if (!hasSoftBanExpired(player))
	{
		player.server_setTeamNum(this.getSpectatorTeamNum());
		return;
	}

	if (getMothership(player.getTeamNum()) !is null)
		return; //if we already have a suitable team, dont re-assign
	
	const u8 teamsNum = this.getTeamsNum();
	u8[] playersperteam(teamsNum);

	//gather the per team player counts
	const u8 plyCount = getPlayersCount();
	for (u8 i = 0; i < plyCount; i++)
	{
		CPlayer@ p = getPlayer(i);
		if (p is null) continue;
		
		const u8 pteam = p.getTeamNum();
		if (pteam < teamsNum)
			playersperteam[pteam]++;
	}
	
	//calc the minimum player count, dequalify teams
	u8 minplayers = 255; //set as the max of u8
	for (u8 i = 0; i < teamsNum; i++)
	{
		if (getMothership(i) is null)
			playersperteam[i] = 255; //disqualify since team is dead
			
		minplayers = Maths::Min(playersperteam[i], minplayers); //set minimum
	}

	if (minplayers == 255) return;

	//only allow the teams with the least amount of players to get more players.
	//find the minimum team booty
	u8[] smallestTeams;
	u16 minbooty = -1;
	for (u8 i = 0; i < teamsNum; i++)
	{
		if (playersperteam[i] == minplayers)
		{
			smallestTeams.push_back(i);
			minbooty = Maths::Min(this.get_u16("bootyTeam_total" + i), minbooty);
		}
	}
	
	//find and choose the team with the minimum booty. we have to randomize incase multiple teams have the same team booty
	u8 team;
	do
		team = smallestTeams[XORRandom(smallestTeams.length)]; //choose a random team from our selected smallest teams
	while (this.get_u16("bootyTeam_total" + team) > minbooty); //if the chosen team has more booty than the min, continue the loop and choose a new team to check.

	player.server_setTeamNum(team);
}

void onPlayerRequestSpawn(CRules@ this, CPlayer@ player)
{
	const bool isSoftBanned = !hasSoftBanExpired(player);
	if (!isRespawnAdded(this, player.getUsername()) && (player.getTeamNum() != this.getSpectatorTeamNum() || isSoftBanned))
	{
		if (isSoftBanned && player.getTeamNum() != this.getSpectatorTeamNum())
			player.server_setTeamNum(this.getSpectatorTeamNum());
		
		const u32 gametime = getGameTime();
		Respawn r(player.getUsername(), standardRespawnTime + gametime);
		this.push("respawns", r);
		syncRespawnTime(this, player, standardRespawnTime + gametime);
	}
}

void onTick(CRules@ this)
{
	const u32 gametime = getGameTime();
	if (!this.isGameOver() && gametime % 30 == 0)
	{
		Respawn[]@ respawns;
		if (this.get("respawns", @respawns))
		{
			for (u8 i = 0; i < respawns.length; i++)
			{
				Respawn@ r = respawns[i];
				CPlayer@ player = getPlayerByUsername(r.username);
				// check if player is in spectator team
				if (player is null || (player.getTeamNum() == this.getSpectatorTeamNum() && hasSoftBanExpired(player)))
				{
					respawns.erase(i);
					i--;
				}
				else if (r.timeStarted == 0 || r.timeStarted <= gametime)
				{
					SpawnPlayer(this, player);
					respawns.erase(i);
					i--;
				}
			}
		}
	}
}

void SpawnPlayer(CRules@ this, CPlayer@ player)
{
	if (player is null) return;

	// remove previous players blob
	CBlob@ blob = player.getBlob();
	if (blob !is null)
	{
		blob.server_SetPlayer(null);
		blob.server_Die();
	}

	assignTeam(this, player);

	const u8 newteam = player.getTeamNum();
	
	u32 spawnID = server_getPlayerRespID(player.getUsername());
	CBlob@ spawnPoint = getBlobByNetworkID(spawnID);
	if(spawnID > 0) //if spawnpoint is not set, respawn like in vanilla shiprekt
	{
		if(spawnPoint !is null) //if spawnpoint is null, respawn like in vanilla shiprekt
		{
			if(spawnPoint.getTeamNum() == newteam) //if spawnpoint was already captured, find closes avaliable respawn
			{
				f32 cap_ratio = spawnPoint.get_u8("capture time") / Maths::Max(spawnPoint.get_u8("convertTime"), 1);

				if (cap_ratio <= 0.5f || cap_ratio == 1) RespawnAtBlob(player, spawnPoint, newteam); //everything is ok, respawning at spawnpoint. //cap_ratio stays equal to 1 when no one captures point
				else RaspawnAtClosestSpawnAvaliable(this, player, spawnPoint, newteam); //if the station is half-captured respawn at closest spawn
			}
			else
			{
				RaspawnAtClosestSpawnAvaliable(this, player, spawnPoint, newteam, true); //true means that player's spawnPointID will be reset to the closest spawn found
			}
		}
		else
		{
			RespawnAtMothership(this, player, newteam);
			server_setSpawnPoint(player.getUsername(), 0); //reset spawn point because it is unavaliable
		}
	}
	else
	{
		RespawnAtMothership(this, player, newteam);
		server_setSpawnPoint(player.getUsername(), 0); //reset spawn point because it is unavaliable
	}
}

void RespawnAtMothership(CRules@ this, CPlayer@ player, const u8 team)
{
	server_setSpawnPoint(player.getUsername(), 0);
	CBlob@ newship = getMothership(team);
	
	// spawn as shark if cant find a ship
	if(newship is null) SpawnAsShark(this, player);
	
	CBlob@ newBlob = server_CreateBlobNoInit(PLAYER_BLOB);
	if (newBlob !is null)
	{
		newBlob.server_SetPlayer(player);
		newBlob.server_setTeamNum(team);
		newBlob.setPosition(newship.getPosition());
		newBlob.Init();
	}
}

void RaspawnAtClosestSpawnAvaliable(CRules@ this, CPlayer@ player, CBlob@ spawnPoint, const u8 team, const bool shouldResetSpawn = false)
{
	CBlob@[] bs;
	getBlobsByTag("spawnPoint", @bs);
	f32 temp_range = 999999;
	u16 id = 0;
	for (u8 i = 0; i < bs.size(); i++) //Find the closest spawnpoint. We can use getBlobsByTag becuase there is not much blobs with this tag so getting all of them is not very expensive.
	{
		CBlob@ b = bs[i];

		f32 cap_ratio = spawnPoint.get_u8("capture time") / Maths::Max(spawnPoint.get_u8("convertTime"), 1);
		if (b is null || b.getDistanceTo(spawnPoint) > temp_range || b.getTeamNum() != player.getTeamNum() || ((cap_ratio > 0.5f && cap_ratio < 1) || cap_ratio != 1 || !b.hasTag("station"))) continue; //cap_ratio stays equal to 1 when no one captures point
		temp_range = b.getDistanceTo(spawnPoint);
		id = b.getNetworkID();
	}
	if (id > 0)
	{
		RespawnAtBlob(player, getBlobByNetworkID(id), team);
		if(shouldResetSpawn) server_setSpawnPoint(player.getUsername(), id);
	}
	else RespawnAtMothership(this, player, team);
}

void RespawnAtBlob(CPlayer@ player, CBlob@ SpawnBlob, const u8 team)
{
	CBlob@ newBlob = server_CreateBlobNoInit(PLAYER_BLOB);
	if (newBlob !is null)
	{
		newBlob.server_SetPlayer(player);
		newBlob.server_setTeamNum(team);
		newBlob.setPosition(SpawnBlob.getPosition());
		newBlob.Init();
	}
}

void SpawnAsShark(CRules@ this, CPlayer@ player)
{
	CBlob@ shark = server_CreateBlob("shark", this.getSpectatorTeamNum(), getSpawnPosition(0));
	if (shark !is null)
		shark.server_SetPlayer(player);

	return;
}

bool isRespawnAdded(CRules@ this, const string&in username)
{
	Respawn[]@ respawns;
	if (this.get("respawns", @respawns))
	{
		const u8 respawnLength = respawns.length;
		for (u8 i = 0; i < respawnLength; i++)
		{
			Respawn@ r = respawns[i];
			if (r.username == username)
				return true;
		}
	}
	return false;
}

Vec2f getSpawnPosition(const u8&in team)
{
	CMap@ map = getMap();
	
	Vec2f[] spawns;
	if (map.getMarkers("spawn", spawns))
	{
		if (team < spawns.length)
			return spawns[team];
	}
	return map.getMapDimensions() / 2;
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newteam)
{
	if (!hasSoftBanExpired(player)) return;
	
	CBlob@ blob = player.getBlob();
	if (blob !is null)
		blob.server_Die();
	
	const u8 specNum = this.getSpectatorTeamNum();
	const u8 old_team = player.getTeamNum();
	
	player.server_setTeamNum(newteam);
	if (newteam != specNum)
	{
		if (old_team == specNum)
		{
			assignTeam(this, player);
			Respawn r(player.getUsername(), specToTeamRespawnTime + getGameTime());
			this.push("respawns", r);
			syncRespawnTime(this, player, specToTeamRespawnTime + getGameTime());
			return;
		}
		onPlayerRequestSpawn(this, player);
	}
}

void syncRespawnTime(CRules@ this, CPlayer@ player, const u32&in time)
{
	CBitStream params;
	params.write_u32(time);
	this.SendCommand(this.getCommandID("sync respawn time"), params, player);
}