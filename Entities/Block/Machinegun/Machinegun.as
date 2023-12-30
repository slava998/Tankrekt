#include "WeaponCommon.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "PlankCommon.as";
#include "GunStandard.as";

const f32 MIN_FIRE_PAUSE = 2.85f; //min wait between shots
const f32 MAX_FIRE_PAUSE = 8.0f; //max wait between shots
const f32 FIRE_PAUSE_RATE = 0.08f; //higher values = higher recover

const u8 MAX_AMMO = 250;
const u8 REFILL_AMOUNT = 30;
const u8 REFILL_SECONDS = 6;
const u8 REFILL_SECONDARY_CORE_SECONDS = 1;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 2;

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 1);
		_booty_reward.addTagReward("engine", 1);
		@booty_reward = _booty_reward;
	}
	
	this.Tag("weapon");
	this.Tag("machinegun");
	this.Tag("usesAmmo");
	this.Tag("fixed_gun");
	
	this.set_u8("TTL", 12);
	this.set_u8("speed", 25);
	
	this.set_f32("weight", 2.0f);
	
	this.addCommandID("fire");
	this.set_string("barrel", "left");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.set_f32("fire pause", MIN_FIRE_PAUSE);

		this.Sync("fire pause", true); //-1042743405 HASH
		this.Sync("ammo", true);
		this.Sync("maxAmmo", true);
	}

	CSprite@ sprite = this.getSprite();
	{
		sprite.SetRelativeZ(2);
		Animation@ anim = sprite.addAnimation("fire left", Maths::Round(MIN_FIRE_PAUSE), false);
		anim.AddFrame(2);
		anim.AddFrame(0);

		Animation@ anim2 = sprite.addAnimation("fire right", Maths::Round(MIN_FIRE_PAUSE), false);
		anim2.AddFrame(1);
		anim2.AddFrame(0);

		Animation@ anim3 = sprite.addAnimation("default", 1, false);
		anim3.AddFrame(0);
		sprite.SetAnimation("default");
	}

	this.set_u32("fire time", 0);
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	const u32 gameTime = getGameTime();
	const f32 currentFirePause = this.get_f32("fire pause");
	if (currentFirePause > MIN_FIRE_PAUSE)
		this.set_f32("fire pause", currentFirePause - FIRE_PAUSE_RATE * this.getCurrentScript().tickFrequency);

	//print("Fire pause: " + currentFirePause);

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
	return (this.get_u32("fire time") + this.get_f32("fire pause") < getGameTime());
}

const bool canIncreaseFirePause(CBlob@ this)
{
	return (MIN_FIRE_PAUSE < getGameTime());
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("fire"))
	{
		if (!canShoot(this) || this.get_bool("docked"))
			return;

		u16 shooterID;
		if (!params.saferead_netid(shooterID))
			return;

		CBlob@ shooter = getBlobByNetworkID(shooterID);
		if (shooter is null)
			return;

		Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
		if (ship is null)
			return;

		if (canIncreaseFirePause(this))
		{
			f32 currentFirePause = this.get_f32("fire pause");
			if (currentFirePause < MAX_FIRE_PAUSE)
				this.set_f32("fire pause", currentFirePause + Maths::Sqrt(currentFirePause * (ship.isMothership ? 1.1 : 1.0f) * FIRE_PAUSE_RATE));
		}

		Vec2f pos = this.getPosition();

		this.set_u32("fire time", getGameTime());

		// ammo
		u16 ammo = this.get_u16("ammo");
		if (ammo <= 0)
		{
			directionalSoundPlay("LoadingTick1", pos, 0.5f);
			return;
		}

		ammo--;
		this.set_u16("ammo", ammo);
		
		CPlayer@ attacker = shooter.getPlayer();
		if (attacker !is null && attacker !is this.getDamageOwnerPlayer())
			this.SetDamageOwnerPlayer(shooter.getPlayer());

		//effects
		CSprite@ sprite = this.getSprite();
		sprite.SetAnimation("default");

		Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());
		Vec2f barrelOffset;
		if (this.get_string("barrel") == "left")
		{
			barrelOffset = Vec2f(0, -2.0).RotateBy(-aimVector.Angle());
			this.set_string("barrel", "right");
		}
		else
		{
			barrelOffset = Vec2f(0, 2.0).RotateBy(-aimVector.Angle());
			this.set_string("barrel", "left");
		}

		Vec2f barrelPos = pos + aimVector*9 + barrelOffset;
		if (isObstructed(this, barrelPos, aimVector))
		{
			directionalSoundPlay("lightup", barrelPos);
			return;
		}
		
		if (isServer())
			shootGun(this.getNetworkID(), -aimVector.Angle(), barrelPos); //make bullets!

		if (isClient())
		{
			if (this.get_string("barrel") == "left")
				sprite.SetAnimation("fire left");
			else
				sprite.SetAnimation("fire right");
			shotParticles(barrelPos, aimVector.Angle(), false);
			directionalSoundPlay("Gunshot" + (XORRandom(2) + 2), barrelPos, 1.8f);
		}
	}
}

bool isObstructed(CBlob@ this, Vec2f&in barrelPos, Vec2f&in aimVector)
{
	HitInfo@[] hitInfos;
	if (getMap().getHitInfosFromRay(barrelPos, -aimVector.Angle(), 100.0f, this, @hitInfos))
	{
		const u8 hitLength = hitInfos.length;
		for (u8 i = 0; i < hitLength; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b is null || (b.hasTag("plank") && !CollidesWithPlank(b, aimVector))) continue;
			
			const bool sameShip = b.getShape().getVars().customData == this.getShape().getVars().customData;
			if (sameShip && (b.hasTag("weapon") || b.getShape().getConsts().collidable) && b.getTeamNum() == this.getTeamNum())
				return true;
		}
	}
	return false;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (damage <= 0.0f) return;

	CPlayer@ player = this.getDamageOwnerPlayer();
	if (player !is null)
		rewardBooty(player, hitBlob, booty_reward, "Pinball_"+XORRandom(4));
	
	if (isServer())
	{
		if (hitBlob.hasTag("engine") && hitBlob.getTeamNum() != this.getTeamNum() && XORRandom(3) == 0)
			hitBlob.SendCommand(hitBlob.getCommandID("off")); //force turn off
	}
}
