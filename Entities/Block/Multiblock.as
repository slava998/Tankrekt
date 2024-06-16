
//destroy all blocks of this structure on death
void onDie(CBlob@ this)
{
	if(this.hasTag("no_recheck")) return;

	u32[] linkedIDs;
	if (!this.get("linkedIDs", linkedIDs))
		return;

	const int color = this.getShape().getVars().customData;
	bool killed = false;
	const u8 len = linkedIDs.length;
	for (u8 i = 0; i < len + 1; i++)
	{
		CBlob@ b = getBlobByNetworkID(linkedIDs[i]);
		if(b !is null)
		{
			b.Tag("dead");
			b.server_Die();
		}
	}
}