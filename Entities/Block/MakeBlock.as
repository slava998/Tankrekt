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
