const u16 getCost(const string&in blockName)
{
	ConfigFile cfg;
	if (!cfg.loadFile("BlockVars.cfg"))
		return 0;
	
	if (!cfg.exists(blockName))
	{
		warn("BlockCosts.as: Cost not found! : "+blockName);
		return 0;
	}
	u16 cost = cfg.read_u16(blockName);
	
	return cost;
}
