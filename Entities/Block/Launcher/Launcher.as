#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";

const f32 BULLET_SPEED = 3.0f;
const int FIRE_RATE = 200;

const u8 MAX_AMMO = 8;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 8;
const u8 REFILL_SECONDARY_CORE_SECONDS = 14;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;

Random _shotspreadrandom(0x11598); //clientside

void onInit(CBlob@ this)
{
	this.Tag("weapon");
	this.Tag("usesAmmo");
	this.Tag("machinegun"); //for seat.as
	
	this.set_f32("weight", 4.5f);
	
	this.addCommandID("fire");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true);
		this.Sync("maxAmmo", true);
	}

	CSprite@ sprite = this.getSprite();
    sprite.SetRelativeZ(2);

	this.set_u32("fire time", 0);
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
		{
			checkDocked(this, ship);
			if (canShoot(this))
				refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
		}
	}
}

const bool canShoot(CBlob@ this)
{
	return (this.get_u32("fire time") + FIRE_RATE < getGameTime());
}

const bool isClear(CBlob@ this)
{
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());
	
	HitInfo@[] hitInfos;
	if (getMap().getHitInfosFromRay(this.getPosition(), -aimVector.Angle(), 60.0f, this, @hitInfos))
	{
		const u8 hitLength = hitInfos.length;
		for (u8 i = 0; i < hitLength; i++)
		{
			CBlob@ b =  hitInfos[i].blob;
			if (b is null || b is this) continue;

			if (this.getShape().getVars().customData == b.getShape().getVars().customData && 
			   (b.hasTag("weapon") || b.hasTag("door") ||(b.hasTag("solid") && !b.hasTag("plank")))) //same ship
			{
				return false;
			}
		}
	}

	return true;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("fire"))
    {
		if (!canShoot(this) || this.get_bool("docked")) return;

		u16 shooterID;
		if (!params.saferead_netid(shooterID)) return;

		CBlob@ shooter = getBlobByNetworkID(shooterID);
		if (shooter is null) return;
		
		Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
		if (ship is null) return;
			
		Vec2f pos = this.getPosition();

		if (!isClear(this))
		{
			directionalSoundPlay("lightup", pos);
			return;
		}

		//ammo
		u16 ammo = this.get_u16("ammo");

		if (ammo <= 0)
		{
			directionalSoundPlay("LoadingTick1", pos, 0.35f);
			return;
		}

		ammo--;
		this.set_u16("ammo", ammo);

		Vec2f aimvector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());
		const Vec2f barrelPos = this.getPosition() + aimvector*9;
		Vec2f velocity = aimvector*BULLET_SPEED;

		if (isServer())
		{
            CBlob@ bullet = server_CreateBlob("rocket", this.getTeamNum(), pos + aimvector*8.0f);
            if (bullet !is null)
            {
            	if (shooter !is null)
				{
                	bullet.SetDamageOwnerPlayer(shooter.getPlayer());
                }
                bullet.setVelocity(velocity + ship.vel);
				bullet.setAngleDegrees(-aimvector.Angle() + 90.0f);
                bullet.server_SetTimeToDie(25);
            }
    	}

		shotParticles(barrelPos, aimvector.Angle(), false);
		directionalSoundPlay("LauncherFire" + (XORRandom(2) + 1), barrelPos);

		this.set_u32("fire time", getGameTime());
    }
}
