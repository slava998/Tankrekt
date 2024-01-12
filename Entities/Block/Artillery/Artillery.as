#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "ExplosionEffects.as";
#include "DamageBooty.as";

const f32 PROJECTILE_RANGE = 450.0F;
const f32 PROJECTILE_SPEED = 5.0f;;

const u16 FIRE_RATE = 500; //max wait between shots

const u8 MAX_AMMO = 4;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 10;
const u8 REFILL_SECONDARY_CORE_SECONDS = 16;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;

const f32 BOMB_RADIUS = 15.0f;
const f32 BOMB_BASE_DAMAGE = 4.0f;

Random _shotrandom(0x15125); //clientside
BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	this.Tag("bomb");
	this.Tag("weapon");
	this.Tag("cannon");
	this.Tag("usesAmmo");
	this.Tag("fixed_gun");
	
	this.set_f32("weight", 12.0f);
	
	this.addCommandID("fire");

	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 20);
		_booty_reward.addTagReward("mothership", 35);
		_booty_reward.addTagReward("secondarycore", 25);
		_booty_reward.addTagReward("weapon", 20);
		_booty_reward.addTagReward("solid", 15);
		_booty_reward.addTagReward("seat", 20);
		_booty_reward.addTagReward("platform", 5);
		_booty_reward.addTagReward("door", 15);
		@booty_reward = _booty_reward;
	}

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true); //1536888239 HASH
		this.Sync("maxAmmo", true); //2002479429 HASH
	}

	CSprite@ sprite = this.getSprite();
	sprite.SetRelativeZ(2);
	{
		//shoot anim
		Animation@ anim = sprite.addAnimation("fire", 0, false);
		anim.AddFrame(0);
		anim.AddFrame(1);
		sprite.SetAnimation("fire");
	}
	this.set_u32("fire time", 0);
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	const u32 gameTime = getGameTime();

	//fire ready
	const u32 fireTime = this.get_u32("fire time");
	this.set_bool("fire ready", (gameTime > fireTime + FIRE_RATE));
	
	if (isClient())
	{
		//sprite ready
		if (fireTime + FIRE_RATE - 15 == gameTime)
		{
			this.getSprite().animation.SetFrameIndex(0);
			directionalSoundPlay("Charging.ogg", this.getPosition(), 2.0f);
		}
	}

	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
		{
			checkDocked(this, ship);
			if (this.get_bool("fire ready"))
				refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
		}
	}
}

void Explode(CBlob@ this, const f32&in radius = BOMB_RADIUS)
{
	const Vec2f pos = this.getPosition();

	if (isClient())
{
		directionalSoundPlay("Bomb.ogg", pos);
		makeLargeExplosionParticle(pos);
		ShakeScreen(4 * radius, 45, pos);
	}

	//hit blobs
	CBlob@[] blobs;
	if (!getMap().getBlobsInRadius(pos, (radius-3), @blobs))
		return;
	
	ShipDictionary@ ShipSet = getShipSet();
	const u8 blobsLength = blobs.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ hit_blob = blobs[i];
		if (hit_blob is this) continue;
		
		const int hitCol = hit_blob.getShape().getVars().customData;

		if (isServer())
		{
			Vec2f hit_blob_pos = hit_blob.getPosition();  

			if (hit_blob.hasTag("block"))
			{
				if (hitCol <= 0) continue;

				// move the ship
				Ship@ ship = ShipSet.getShip(hitCol);
				if (ship !is null && ship.mass > 0.0f)
				{
					Vec2f impact = (hit_blob_pos - pos) * 0.15f / ship.mass;
					ship.vel += impact;
				}
			}
		
			const f32 distanceFactor = Maths::Min(1.0f, Maths::Max(0.0f, BOMB_RADIUS - this.getDistanceTo(hit_blob) + 8.0f) / BOMB_RADIUS);
			//f32 distanceFactor = 1.0f;
			const f32 damageFactor = (hit_blob.hasTag("mothership")) ? 0.25f : 1.0f;

			//hit the object
			this.server_Hit(hit_blob, hit_blob_pos, Vec2f_zero, BOMB_BASE_DAMAGE * distanceFactor * damageFactor, Hitters::bomb, true);
			//print(hit_blob.getNetworkID() + " for: " + BOMB_BASE_DAMAGE * distanceFactor + " dFctr: " + distanceFactor + ", dist: " + this.getDistanceTo(hit_blob));
		}
		
		CPlayer@ owner = this.getDamageOwnerPlayer();
		if (owner !is null && hitCol > 0)
		{
			rewardBooty(owner, hit_blob, booty_reward, "Pinball_3");
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("fire"))
	{
		if (!this.get_bool("fire ready") || this.get_bool("docked")) return;

		const Vec2f pos = this.getPosition();

		this.set_u32("fire time", getGameTime());

		if (!isClear(this))
		{
			directionalSoundPlay("lightup", pos);
			return;
		}

		//ammo
		u16 ammo = this.get_u16("ammo");

		if (ammo <= 0)
		{
			directionalSoundPlay("LoadingTick1", pos, 1.0f);
			return;
		}

		ammo--;
		this.set_u16("ammo", ammo);

		u16 shooterID;
		if (!params.saferead_netid(shooterID))
			return;

		CBlob@ shooter = getBlobByNetworkID(shooterID);
		if (shooter is null)
			return;

		Fire(this, shooter);

		this.getSprite().animation.SetFrameIndex(1);
	}
}

void Fire(CBlob@ this, CBlob@ shooter)
{
	Vec2f pos = this.getPosition();
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());

	if (isServer())
	{
		f32 variation = 0.9f + _shotrandom.NextFloat()/5.0f;
		f32 _lifetime = 0.05f + variation*PROJECTILE_RANGE/PROJECTILE_SPEED/32.0f;

		CBlob@ cannonball = server_CreateBlob("tankshell", this.getTeamNum(), pos + aimVector*4);
		if (cannonball !is null)
		{
			Vec2f vel = aimVector * PROJECTILE_SPEED;

			Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
			if (ship !is null)
			{
				vel += ship.vel;

				if (shooter !is null)
				{
					CPlayer@ attacker = shooter.getPlayer();
					if (attacker !is null)
						cannonball.SetDamageOwnerPlayer(attacker);
				}

				cannonball.setVelocity(vel);
				cannonball.server_SetTimeToDie(_lifetime);
			}
		}
	}

	if (isClient())
	{
		this.getSprite().animation.SetFrameIndex(0);
		shotParticles(pos + aimVector*9, aimVector.Angle());
		directionalSoundPlay("TankCannonFire.ogg", pos, 7.0f);
	}
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

			if (this.getShape().getVars().customData == b.getShape().getVars().customData && (b.hasTag("weapon") || (b.hasTag("solid") && !b.hasTag("plank")))) //same ship
			{
				return false;
			}
		}
	}

	return true;
}

void onDie(CBlob@ this)
{
	if (this.getShape().getVars().customData > 0)
	{
		this.getSprite().Gib();
		if (!this.hasTag("disabled"))
			Explode(this);
	}
}
