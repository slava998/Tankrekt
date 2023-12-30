namespace Human
{
	const float walkSpeed = 1.0f;
	const float swimSlow = 0.4f;
	
	const int PUNCH_RATE = 15;
	const int FIRE_RATE = 40;
	const int CONSTRUCT_RATE = 14;
};

// helper functions

namespace Human
{
	shared bool isHoldingBlocks(CBlob@ this)
	{
		u16[] blocks;
		this.get("blocks", blocks);
		return blocks.length > 0;
	}
	
	shared bool wasHoldingBlocks(CBlob@ this)
	{
		return getGameTime() - this.get_u32("placedTime") < 10;
	}
	
	shared void clearHeldBlocks(CBlob@ this)
	{
		u16[] blocks;
		if (this.get("blocks", blocks))
		{
			const u8 blocksLength = blocks.length;
			for (u8 i = 0; i < blocksLength; ++i)
			{
				CBlob@ block = getBlobByNetworkID(blocks[i]);
				if (block is null) continue;
				
				block.Tag("disabled");
				block.server_Die();
			}
		}
		this.clear("blocks");
	}
}

shared bool canPunch(CBlob@ this)
{
	return !this.hasTag("dead") && this.get_u32("punch time") + Human::PUNCH_RATE < getGameTime();
}

shared bool canShootPistol(CBlob@ this)
{
	return !this.hasTag("dead") && this.get_string("current tool") == "pistol" && this.get_u32("fire time") + Human::FIRE_RATE < getGameTime();
}

shared bool canConstruct(CBlob@ this)
{
	return !this.hasTag("dead") && (this.get_string("current tool") == "deconstructor" || this.get_string("current tool") == "reconstructor")
				&& this.get_u32("fire time") + Human::CONSTRUCT_RATE < getGameTime();
}
