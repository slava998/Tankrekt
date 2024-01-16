#include "WaterEffects.as";
#include "ShipsCommon.as";
#include "Booty.as";
#include "AccurateSoundPlay.as";
#include "TileCommon.as";
#include "ParticleSpark.as";
#include "BlockCosts.as";
 
const f32 CONSTRUCT_RATE = 5.0f; //higher values = higher recover
const int CONSTRUCT_VALUE = 5;
const int NUM_HEALS = 5;

void onInit(CBlob@ this)
{
	this.getCurrentScript().tickFrequency = 2;

	this.Tag("weapon");
	this.Tag("machinegun");
	this.Tag("fixed_gun");
	
	this.set_f32("weight", 3.0f);
	
	this.addCommandID("fire");
	
	
	this.set_u32("fire time", 0);
}
 
void onTick(CBlob@ this)
{
	if (getGameTime() % 35 != 0) return;

	if (this.getShape().getVars().customData <= 0) //not placed yet
		return;
	ShipDictionary@ ShipSet = getShipSet();

	Vec2f pos = this.getPosition();
	Vec2f tl = pos + Vec2f(8, 8);
	Vec2f br = pos - Vec2f(8, 8);

	u8 count = 0;
	CBlob@[] blobs;
	getMap().getBlobsInBox(tl, br, @blobs);
	const u8 blobsLength = blobs.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ b = blobs[i];
		if (b is null || b is this) continue;
		
		const int color = b.getShape().getVars().customData;
		if (color <= 0) continue;
		
		if (isClient())//effects
		{
			sparks(b.getPosition(), v_fastrender ? 1 : 4);
		}
		
		if (b.hasTag("station")) continue;
		if (count >= NUM_HEALS) continue;
		
		const bool isMyShip = color == this.getShape().getVars().customData;
		f32 reconstructAmount = 0;
		u16 reconstructCost = 0;
		const f32 mBlobHealth = b.getHealth();
		const f32 mBlobCost = getCost(b.getName());
		const f32 initialReclaim = b.getInitialHealth();
		const f32 currentReclaim = b.get_f32("current reclaim");
		f32 fullConstructAmount;

		if (!b.hasTag("mothership"))
			fullConstructAmount = Maths::Min(1.0f, CONSTRUCT_VALUE/mBlobCost)*initialReclaim;
		else
			fullConstructAmount = (0.01f)*initialReclaim; //mothership
		
		if (currentReclaim < initialReclaim || b.hasTag("mothership"))
		{
			//healing
			if ((currentReclaim + reconstructAmount) <= initialReclaim)
			{
				reconstructAmount = fullConstructAmount;
				reconstructCost = CONSTRUCT_VALUE;
			}
			else if ((currentReclaim + reconstructAmount) > initialReclaim)
			{
				reconstructAmount = initialReclaim - currentReclaim;
				reconstructCost = CONSTRUCT_VALUE - CONSTRUCT_VALUE*(reconstructAmount/fullConstructAmount);
			}
					
			if (b.hasTag("mothership"))
			{
				//mothership
				if (mBlobHealth < initialReclaim)
				{
					b.server_SetHealth(mBlobHealth + reconstructAmount);
				}
			}
			else
			//normal blocks
			{
				b.server_SetHealth(Maths::Min(initialReclaim, mBlobHealth + reconstructAmount));
				b.set_f32("current reclaim", Maths::Min(initialReclaim, currentReclaim + reconstructAmount));
				count++;
			}
			if ((currentReclaim + reconstructAmount) < mBlobHealth)
				b.set_f32("current reclaim", Maths::Min(initialReclaim, currentReclaim + reconstructAmount));
		}
	}
}



