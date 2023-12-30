// Punish players by forcing them to become sharks for the duration of their ban
// A better alternative to hard-bans, since players can still 'play' while being punished.

const string FileName = "Shiprekt/SoftBans.cfg";

ConfigFile@ openBansConfig()
{
	ConfigFile cfg = ConfigFile();
	if (!cfg.loadFile("../Cache/"+FileName))
	{
		warn("Creating soft bans config ../Cache/"+FileName);
		cfg.saveFile(FileName);
	}

	return cfg;
}

void server_SoftBan(string&in playerKey, const s32&in time, string&in description = "")
{
	ConfigFile@ cfg = openBansConfig();
	
	//ban by IP if available, set new player if online
	CPlayer@ player = getPlayerByUsername(playerKey);
	if (player !is null)
	{
		if (player.getBlob() !is null) player.getBlob().server_Die();
		description = "[ "+playerKey+" ] " + description;
		playerKey = player.server_getIP();
	}
	
	//add to ban file
	const s32 ban_time = time > -1 ? Time() + time : -1;
	cfg.add_s32(playerKey+"_time_end", ban_time);
	cfg.add_string(playerKey+"_description", description);
	cfg.saveFile(FileName);
	
	error("\nSoft banned [ "+playerKey+" ] for"+(time > -1 ? " "+time/60+" minutes" : "ever")+"; "+description+"\n");
}

const bool isSoftBanned(CPlayer@ player, string&out playerKey, s32&out playerBanTime)
{
	ConfigFile@ cfg = openBansConfig();
	
	//check banned IP addresses
	const string IP = player.server_getIP();
	if (cfg.exists(IP+"_time_end"))
	{
		playerKey = IP;
		playerBanTime = cfg.read_s32(IP+"_time_end");
		return true;
	}
	
	//check banned usernames
	const string Username = player.getUsername();
	if (cfg.exists(Username+"_time_end"))
	{
		playerKey = Username;
		playerBanTime = cfg.read_s32(Username+"_time_end");
		return true;
	}
	
	return false;
}

const bool hasSoftBanExpired(CPlayer@ player)
{
	string playerKey;
	s32 playerBanEnd;
	if (!isSoftBanned(player, playerKey, playerBanEnd))
	{
		return true;
	}
	
	if (Time() >= playerBanEnd && playerBanEnd > -1)
	{
		//remove ban
		ConfigFile@ cfg = openBansConfig();
		
		cfg.remove(playerKey+"_time_end");
		cfg.remove(playerKey+"_description");
		cfg.saveFile(FileName);
		
		return true;
	}
	
	return false;
}
