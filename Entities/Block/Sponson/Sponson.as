#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "RecoilCommon.as";

const f32 PROJECTILE_SPEED = 9.0f;
const f32 PROJECTILE_SPREAD = 1.15;
const int SPONSON_FIRE_RATE = 60; //this also has to be copied to Seat.as!
const f32 PROJECTILE_RANGE = 340.0f;
const f32 RECOIL_POWER = 30.0f;

const u8 MAX_AMMO = 15;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 3;
const u8 REFILL_SECONDARY_CORE_SECONDS = 6;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;

Random _shotspreadrandom(0x11598); //clientside

//Some important code is in Seat.as

void onInit(CBlob@ this)
{
	this.Tag("solid");
	this.Tag("sponson");
	this.Tag("weapon");
	this.Tag("usesAmmo");
	
	this.set_f32("weight", 3.5f);
	
	this.addCommandID("fire");
	this.addCommandID("rotate");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true);
		this.Sync("maxAmmo", true);
	}

	this.set_u32("fire time", 0);
	this.set_u16("parentID", 0);
	this.set_u16("childID", 0);

	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer("weapon", "Sponson_barrel.png", 16, 6);
    if (layer !is null)
    {
    	layer.SetRelativeZ(-2);
		layer.SetOffset(Vec2f(-4, 0));
    	layer.SetLighting(false);
     	Animation@ anim = layer.addAnimation("fire", 15, false);
        anim.AddFrame(1);
        anim.AddFrame(0);
        layer.SetAnimation("fire");
    }
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	const u32 gameTime = getGameTime();
	
	//fire ready
	const u32 fireTime = this.get_u32("fire time");
	this.set_bool("fire ready", (gameTime > fireTime + SPONSON_FIRE_RATE));

	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
			refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
	}
}

bool canShoot(CBlob@ this)
{
	return this.get_u32("fire time") + SPONSON_FIRE_RATE < getGameTime();
}

const bool isClearShot(CBlob@ this, Vec2f&in aimVec, const bool&in targetMerged = false)
{
	Vec2f pos = this.getPosition();
	const f32 distanceToTarget = Maths::Max(aimVec.Length(), 80.0f);
	CMap@ map = getMap();

	Vec2f offset = aimVec;
	offset.Normalize();
	offset *= 7.0f;

	HitInfo@[] hitInfos;
	map.getHitInfosFromRay(pos + offset.RotateBy(30), -aimVec.Angle(), distanceToTarget, this, @hitInfos);
	map.getHitInfosFromRay(pos + offset.RotateBy(-60), -aimVec.Angle(), distanceToTarget, this, @hitInfos);
	
	const u8 hitLength = hitInfos.length;
	if (hitLength > 0)
	{
		//HitInfo objects are sorted, first come closest hits
		for (u8 i = 0; i < hitLength; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b is null || b is this) continue;

			const int thisColor = this.getShape().getVars().customData;
			const int bColor = b.getShape().getVars().customData;
			
			const bool sameShip = bColor != 0 && thisColor == bColor;
			const bool canShootSelf = targetMerged && hi.distance > distanceToTarget * 0.7f;

			if (b.hasTag("block") && b.getShape().getVars().customData > 0 && !b.hasTag("non-solid") && b.getShape().getConsts().collidable && ((b.hasTag("solid") && !b.hasTag("plank")) || b.hasTag("weapon")) && sameShip && !canShootSelf)
			{
				return false;
			}
		}
	}
	
	//check to make sure we aren't shooting through rock
	Vec2f solidPos;
	if (map.rayCastSolid(pos, pos + aimVec, solidPos))
	{
		AttachmentPoint@ seat = this.getAttachmentPoint(0);
		CBlob@ occupier = seat.getOccupied();

		if (occupier is null) return false;
	}

	return true;
}

void Fire(CBlob@ this, Vec2f&in aimVector, const u16&in netid)
{
	const f32 aimdist = Maths::Min(aimVector.Normalize(), PROJECTILE_RANGE);

	Vec2f offset(_shotspreadrandom.NextFloat() * PROJECTILE_SPREAD, 0);
	offset.RotateBy(_shotspreadrandom.NextFloat() * 360.0f, Vec2f());

	const Vec2f _vel = (aimVector * PROJECTILE_SPEED) + offset;
	const f32 _lifetime = Maths::Max(0.05f + aimdist/PROJECTILE_SPEED/32.0f, 0.25f);

	CBitStream params;
	params.write_netid(netid);
	params.write_Vec2f(_vel);
	params.write_f32(_lifetime);
	this.SendCommand(this.getCommandID("fire"), params);
	this.set_u32("fire time", getGameTime());
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
	if (layer !is null)
	{
		layer.ResetTransform();
		layer.SetOffset(Vec2f(-4, 0));
		layer.RotateBy(-aimVector.getAngleDegrees() - this.getAngleDegrees(), Vec2f(4, 0));
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("fire"))
    {
		if(!canShoot(this)) return;
		this.set_u32("fire time", getGameTime());
		
		Vec2f pos = this.getPosition();
		//ammo
		u16 ammo = this.get_u16("ammo");
		if (ammo == 0)
		{
			directionalSoundPlay("LoadingTick1", pos, 1.0f);
			return;
		}
		
		Vec2f aimVector = params.read_Vec2f();
		const f32 aimdist = Maths::Min(aimVector.Length(), PROJECTILE_RANGE);
		const f32 lifetime = Maths::Max(0.05f + aimdist/PROJECTILE_SPEED/32.0f, 0.25f);
		
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		aimVector.Normalize();

		Vec2f spread(_shotspreadrandom.NextFloat() * PROJECTILE_SPREAD, 0);
		spread.RotateBy(_shotspreadrandom.NextFloat() * 360.0f, Vec2f());
		
		ammo--;
		this.set_u16("ammo", ammo);
	
		Vec2f velocity = (aimVector * PROJECTILE_SPEED) + spread;

		f32 angle = aimVector.Angle();
		Vec2f offset = Vec2f(9.6f, 0);
		offset.RotateBy(-angle);

		if (isServer())
		{
            CBlob@ bullet = server_CreateBlob("autocannonshell", this.getTeamNum(), pos + offset);
            if (bullet !is null)
            {
            	if (caller !is null)
				{
					if (caller.getPlayer() !is null)
						bullet.SetDamageOwnerPlayer(caller.getPlayer());
				}

                bullet.setVelocity(velocity);
                bullet.server_SetTimeToDie(lifetime);
				bullet.setAngleDegrees(-angle);
            }
    	}

		Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);

		//Recoil
		RecoilForces(this, aimVector, ship, RECOIL_POWER);

		if (isClient())
		{
			Rotate(this, aimVector);
			shotParticles(pos + offset, angle);
			directionalSoundPlay("FlakFire.ogg", pos, 0.50f);

			CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
			if (layer !is null)
				layer.animation.SetFrameIndex(0);
		}
    }
	else if(cmd == this.getCommandID("rotate")) //TODO: REWRITE! using commands for this is very bad
	{
		if(isClient())
		{
			Vec2f aimVector = params.read_Vec2f();
			CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
			if (layer !is null)
			{
				layer.ResetTransform();
				layer.SetOffset(Vec2f(-4, 0));
				layer.RotateBy(-aimVector.getAngleDegrees() - this.getAngleDegrees(), Vec2f(4, 0));
			}
		}
	}
}
