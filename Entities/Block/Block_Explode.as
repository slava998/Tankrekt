#include "ExplosionEffects.as";
#include "AccurateSoundPlay.as";
#include "Hitters.as";

void onTick(CBlob@ this)
{
	if (!this.exists("nextExplosion"))
	{
		this.set_u32("addedTime", getGameTime());
		this.set_u32("nextExplosion", getGameTime() + 20 + XORRandom(80));
	}
		
	if (getGameTime() > this.get_u32("nextExplosion"))
	{
		Explode(this);
		this.set_u32("nextExplosion", getGameTime() + 20 + XORRandom(45));
	}
	
	//failsafe
	if (isClient() && getGameTime() > this.get_u32("addedTime") + 450)
		this.getCurrentScript().runFlags |= Script::remove_after_this;	
}

void Explode(CBlob@ this)
{
	const Vec2f pos = this.getPosition();
	if (isClient())
	{
		//explosion effect
		directionalSoundPlay("KegExplosion.ogg", pos);
		makeSmallExplosionParticle(pos);
		//makeBrightExplosionParticle(pos);
		
		if (this.isOnScreen())
			ShakeScreen(30, 20, pos);
	}

	if (!isServer()) return;
	
	//grab players nearby and damage them
	CBlob@[] overlapping;
	this.getOverlapping(@overlapping);
	
	const u8 overlappingLength = overlapping.length;
	for (u8 i = 0; i < overlappingLength; i++)
	{
		CBlob@ blob = overlapping[i];
		if (blob.hasTag("player"))
			this.server_Hit(blob, pos, Vec2f_zero, blob.getInitialHealth()/5.0f, Hitters::bomb, true);
	}
	
	//damage self
	if (!this.hasTag("mothership"))
		this.server_Hit(this, pos, Vec2f_zero, this.getInitialHealth()/4.0f, 0, true);
}
