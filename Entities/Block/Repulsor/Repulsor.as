#include "Hitters.as";
#include "ExplosionEffects.as";
#include "ShipsCommon.as";
#include "AccurateSoundPlay.as"

const f32 PUSH_RADIUS = 18.0f;
const f32 PUSH_FACTOR =  1.0f;
const u8 FUSE_TIME = 40;

Random _effectsrandom(0x15125); //clientside

void onInit(CBlob@ this)
{
	this.Tag("repulsor");
	this.Tag("removable"); //for corelinked checks
	
	this.set_f32("weight", 0.25f);
	
	this.addCommandID("chainReaction");
	this.addCommandID("activate");
	this.set_u32("detonationTime", 0);
	this.server_SetHealth(2.0f);

	CSprite@ sprite = this.getSprite();
	//default animation
	{
		Animation@ anim = sprite.addAnimation("default", 0, false);
		anim.AddFrame(0);
	}
	//activated animation
	{
		Animation@ anim = sprite.addAnimation("activated", FUSE_TIME/3, false);

		int[] frames = {0, 1, 2, 2, 3};
		anim.AddFrames(frames);
	}
}

void Repulse(CBlob@ this)
{
	const Vec2f pos = this.getPosition();
	if (isClient())
	{
		directionalSoundPlay("Repulse2.ogg", pos, 2.5f);
		directionalSoundPlay("Repulse3.ogg", pos, 1.5f);
		
		CParticle@ p = ParticleAnimated("Shockwave2.png",
										  pos, //position
										  Vec2f(0, 0), //velocity
										  _effectsrandom.NextFloat()*360, //angle
										  1.0f, //scale
										  2, //animtime
										  0.0f, //gravity
										  true); //selflit
		if (p !is null)
			p.Z = 4.0f;
	}
	
	CBlob@[] blobs;
	getMap().getBlobsInRadius(pos, PUSH_RADIUS, @blobs);
	ShipDictionary@ ShipSet = getShipSet();
	const u8 blobsLength = blobs.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ b = blobs[i];
		const int color = b.getShape().getVars().customData;
		if (b is this || color <= 0) continue;
		
		//push ship
		Ship@ ship = ShipSet.getShip(color);
		if (ship !is null && ship.mass > 0.0f)
		{
			const f32 pushMultiplier = b.hasTag("engine") ? 1.5f : 1.0f; //engines get pushed more
			const f32 pushDistance = (b.getPosition() - pos).getLength();
			const Vec2f pushVel = (b.getPosition() - pos) * (1 - (pushDistance/(PUSH_RADIUS*1.5f))) * PUSH_FACTOR*pushMultiplier/ship.mass;
			
			ship.vel += pushVel;
			//if (ship.blocks.length == 1) b.setAngularVelocity(300.0f);
		}
		
		//turn on propellers
		if (isServer() && b.hasTag("engine") && ship.owner.isEmpty())
		{
			b.set_u32("onTime", getGameTime());
			b.set_f32("power", -1.0f);
		}
	}
	
	this.server_Die();
}

void onTick(CBlob@ this)
{
	if (this.hasTag("activated"))
	{
		const u32 gameTime = getGameTime();
		if (isServer() && gameTime == this.get_u32("detonationTime") - 1) //one tick before repulsion
		{
			SeperateShip(this);
		}
		else if (gameTime == this.get_u32("detonationTime"))
			Repulse(this);
	}
}

void SeperateShip(CBlob@ this)
{
	CRules@ rules = getRules();
	Ship@ ship = getShipSet(rules).getShip(this.getShape().getVars().customData);
	if (ship !is null)
	{
		this.Tag("dead");
		CBlob@[] tempArray; tempArray.push_back(this);
		rules.push("dirtyBlocks", tempArray);
	}
}

void Activate(CBlob@ this, const u32&in time)
{
	this.Tag("activated");
	this.set_u32("detonationTime", time);
	if (isClient())
	{
		this.getSprite().SetAnimation("activated");
		directionalSoundPlay("ChargeUp3.ogg", this.getPosition(), 3.75f);
	}
}

void ChainReaction(CBlob@ this, const u32&in time)
{
	CBitStream bs;
	bs.write_u32(time);
	this.SendCommand(this.getCommandID("activate"), bs);

	CBlob@[] overlapping;
	this.getOverlapping(@overlapping);
	
	const u8 overlappingLength = overlapping.length;
	for (u8 i = 0; i < overlappingLength; i++)
	{
		CBlob@ b = overlapping[i];
		if (b.hasTag("repulsor") && !b.hasTag("activated") && b.getShape().getVars().customData > 0 && b.getDistanceTo(this) < 8.8f)
		{
			ChainReaction(b, time); //repeat until all connected repulsors are activated
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("activate") && !this.hasTag("activated"))
		Activate(this, params.read_u32());
	else if (isServer() && cmd == this.getCommandID("chainReaction") && !this.hasTag("activated"))
		ChainReaction(this, getGameTime() + FUSE_TIME);
}

void onDie(CBlob@ this)
{
	if (!this.hasTag("disabled"))
	{
		Repulse(this);
		
		if (getGameTime() != this.get_u32("detonationTime"))
			SeperateShip(this);
	}
}
