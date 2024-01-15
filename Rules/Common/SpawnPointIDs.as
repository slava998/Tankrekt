
shared void SetupRespIDs(CRules@ this)
{
	if (isServer())
	{
		dictionary@ current_RespIDs;
		if (!this.get("RespIDs", @current_RespIDs))
		{
			dictionary RespIDs;
			this.set("RespIDs", RespIDs);
		}
	}
}

shared dictionary@ getRespIDs(CRules@ rules = getRules())
{
	dictionary@ RespIDs;
	rules.get("RespIDs", @RespIDs);
	
	return RespIDs;
}

shared void server_setSpawnPoint(const string&in name, const u32&in spawnID)
{
	if (!isServer()) return;
	
	CRules@ rules = getRules();
	
	getRespIDs().set("respID" + name, spawnID);
}

shared u32 server_getPlayerRespID(const string&in name)
{
	if (isServer())
	{
		u32 spawnID;
		if (getRespIDs().get("respID" + name, spawnID))
			return spawnID;
	}
	return 0;
}