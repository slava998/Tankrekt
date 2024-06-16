shared CBlob@ makeBlock(const Vec2f&in pos, const f32&in angle, const string&in blockName, const u8&in team)
{
	CBlob@ block = server_CreateBlob(blockName, team, pos);
	if (block !is null) 
	{
		block.setAngleDegrees(angle);
		block.getShape().getVars().customData = 0;
		block.set_u32("placedTime", getGameTime());
	}
	return block;
}

shared CBlob@ makeMultiblockPart(const Vec2f&in pos, const string&in blockName, const u8&in team, const u8&in num)
{
	CBlob@ block = server_CreateBlobNoInit(blockName);
	if (block !is null) 
	{
		block.set_u32("placedTime", getGameTime());
		block.set_u8("number", num);
		block.server_setTeamNum(team);
		block.setPosition(pos);
	}
	return block;
}