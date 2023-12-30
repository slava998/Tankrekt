//bouncy map borders
#define SERVER_ONLY
#include "ShipsCommon.as";

s32[] shipIDs;
u32[] shipTimes;

const u32 ticksTillNextBounce = 4;
const u8 torpedo_size_max = 2;

void onTick(CRules@ this)
{
	CMap@ map = getMap();
	if (map is null) return;

	const Vec2f dim = map.getMapDimensions();
	const u32 gameTime = getGameTime();

	//simulate borders on each side of the map
	CBlob@[] blobsAtBorder;
	map.getBlobsInBox(dim, Vec2f(0.0f, dim.y), @blobsAtBorder);
	map.getBlobsInBox(dim, Vec2f(dim.x, 0.0f), @blobsAtBorder);
	map.getBlobsInBox(Vec2f(dim.x, 0.0f), Vec2f(), @blobsAtBorder);
	map.getBlobsInBox(Vec2f(0.0f, dim.y), Vec2f(), @blobsAtBorder);
	
	const u8 borderBlobsLength = blobsAtBorder.length;
	if (borderBlobsLength > 0)
	{
		ShipDictionary@ ShipSet = getShipSet(this);
		for (u8 i = 0; i < borderBlobsLength; i++)
		{
			CBlob@ b = blobsAtBorder[i];
			const int bCol = b.getShape().getVars().customData;
			if (bCol <= 0) continue;
			
			Ship@ ship = ShipSet.getShip(bCol);
			if (ship is null) continue;
			
			const Vec2f pos = b.getPosition();

			//determine bounce direction
			const f32 bounceX = dim.x - 20 < pos.x ? -3.0f : pos.x - 20 < 0.0f ? 3.0f : ship.vel.x;
			const f32 bounceY = dim.y - 20 < pos.y ? -3.0f : pos.y - 20 < 0.0f ? 3.0f : ship.vel.y;
			
			CBitStream bs;
			bs.write_s32(ship.id);
			
			const u16 blocksLength = ship.blocks.length;
			if (blocksLength <= torpedo_size_max && ship.owner.isEmpty()) //do torpedo bounce
			{
				if (shipIDs.find(ship.id) < 0)
				{
					//set the ship to not bounce again for the next few ticks
					shipIDs.push_back(ship.id);
					shipTimes.push_back(gameTime);
					
					//calculate perpendicular angle
					const f32 bounceFactor = dim.y - 20 < pos.y || pos.y - 20 < 0.0f ? -1 : 1; //account for all border sides
					const f32 bounceAngle = Vec2f(-ship.vel.y * bounceFactor, ship.vel.x * bounceFactor).Angle();
					
					bs.write_f32(bounceAngle);
				}
				else
					bs.write_f32(800.0f);
				
				bs.write_Vec2f(Vec2f(bounceX / 1.5f, bounceY / 1.5f));
			}
			else //do normal bounce
			{
				bs.write_f32(800.0f);
				bs.write_Vec2f(Vec2f(bounceX, bounceY));
				server_turnOffPropellers(ship);
			}
			this.SendCommand(this.getCommandID("ship bounce"), bs); //sent to Ships.as
		}
	}
	
	//release any ships to be bounced again
	for (u8 i = 0; i < shipTimes.length; i++)
	{
		if (gameTime > shipTimes[i] + ticksTillNextBounce)
		{
			shipIDs.erase(i);
			shipTimes.erase(i);
			i = 0;
		}
	}
}

void server_turnOffPropellers(Ship@ ship)
{
	const u16 blocksLength = ship.blocks.length;
	for (u16 i = 0; i < blocksLength; ++i)
	{
		ShipBlock@ ship_block = ship.blocks[i];
		if (ship_block is null) continue;

		CBlob@ block = getBlobByNetworkID(ship_block.blobID);
		if (block is null) continue;
		
		//set all propellers off on the ship
		if (block.hasTag("engine"))
		{
			block.set_f32("power", 0);
		}
	}
}
