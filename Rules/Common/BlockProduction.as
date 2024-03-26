#include "MakeBlock.as"

//Produce a block by a player
shared void ProduceBlock(CRules@ this, CBlob@ blob, const string&in type, const u8&in amount = 1, const u8&in lineLength = 0)
{
	const u8 blobTeam = blob.getTeamNum();

	if (isServer())
	{
		blob.clear("blocks");

		const u16 blobID = blob.getNetworkID();
		const bool square = lineLength > 0;
		if(lineLength == 0)
		{
			for (u8 i = 0; i < amount; i++)
			{
				CBlob@ b = makeBlock(Vec2f(i, 0) * 8, 0.0f, type, blobTeam);
				blob.push("blocks", b.getNetworkID());

				//set block infos
				b.set_Vec2f("offset", b.getPosition());
				b.set_netid("ownerID", blobID);
				b.getShape().getVars().customData = -1; // don't push on ship
			}
		}
		else 
		{
			u32[] blocks;
			u8 column = 0;
			for (u8 i = 1; i < amount + 1; i++) //counter must start from 1 to prevent division by 0
			{
				CBlob@ b = makeMultiblockPart(Vec2f(-s8(i % lineLength - lineLength / 2), s8(column - lineLength / 2)) * 8, type, blobTeam, i - 1);
				blob.push("blocks", b.getNetworkID());

				//set block infos
				b.setPosition(Vec2f(-s8(i % lineLength - lineLength / 2), s8(column - lineLength / 2)) * 8);
				b.set_Vec2f("offset",Vec2f(-s8(i % lineLength - lineLength / 2), s8(column - lineLength / 2)) * 8);
				b.set_netid("ownerID", blobID);
				b.set_u8("number", i - 1);
				
				if(square && i % lineLength == 0) column++; //we have finished this column of blocks and are starting to build a new one
				if(i == amount)
				{
					b.Tag("main_block"); //tag the last block as main - it will do the logic of the structure
					b.set("linkedIDs", blocks);
					b.AddScript("Multiblock.as");
				}
				else blocks.push_back(b.getNetworkID());
				b.Init();
				b.setPosition(Vec2f(-s8(i % lineLength - lineLength / 2), s8(column - lineLength / 2)) * 8);
				b.getSprite().SetFrame(i - 1);
				b.getShape().getVars().customData = -1; // don't push on ship
			}
		}
	}
}
