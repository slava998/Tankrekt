#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "RecoilCommon.as";

const f32 PROJECTILE_SPEED = 15.0f;
const f32 PROJECTILE_SPREAD = 1.15;
const int AUTOCANNON_FIRE_RATE = 10; //this also has to be copied to Seat.as!
const f32 PROJECTILE_RANGE = 400.0f;
const f32 RECOIL_POWER = 40.0f;

const u8 MAX_AMMO = 50;
const u8 REFILL_AMOUNT = 10;
const u8 REFILL_SECONDS = 15;
const u8 REFILL_SECONDARY_CORE_SECONDS = 10;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 10;

Random _shotspreadrandom(0x11598); //clientside

//Some important code is in Seat.as

void onInit(CBlob@ this)
{
	this.Tag("solid");
	this.Tag("autocannon");
	this.Tag("weapon");
	this.Tag("usesAmmo");
	
	this.set_f32("weight", 1.5f);
	
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
    CSpriteLayer@ layer = sprite.addSpriteLayer("weapon", "Autocannon_barrel.png", 16, 6);
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
	this.set_bool("fire ready", (gameTime > fireTime + AUTOCANNON_FIRE_RATE));

	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
			refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
	}
}

bool canShoot(CBlob@ this)
{
	return this.get_u32("fire time") + AUTOCANNON_FIRE_RATE < getGameTime();
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

		const f32 time = Maths::Max(PROJECTILE_RANGE/PROJECTILE_SPEED/32.0f, 0.25f);;

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
                bullet.server_SetTimeToDie(time);
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
