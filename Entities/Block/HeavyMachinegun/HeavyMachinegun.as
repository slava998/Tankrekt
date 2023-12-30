#include "WeaponCommon.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "GunStandard.as";

const int FIRE_RATE = 4;

const u8 MAX_AMMO = 160;
const u8 REFILL_AMOUNT = 30;
const u8 REFILL_SECONDS = 5;
const u8 REFILL_SECONDARY_CORE_SECONDS = 1;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 2;

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 2);
		_booty_reward.addTagReward("engine", 2);
		_booty_reward.addTagReward("weapon", 1);
		@booty_reward = _booty_reward;
	}

	this.Tag("heavy machinegun");
	this.Tag("weapon");
	this.Tag("usesAmmo");
	
	this.Tag("noEnemyEntry");
	this.set_string("seat label", "Control Machinegun");
	this.set_u8("seat icon", 7);
	
	this.set_u8("TTL", 20);
	this.set_u8("speed", 20);
	
	this.set_f32("weight", 3.0f);
	
	this.addCommandID("fire");
	this.set_string("barrel", "left");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true);
		this.Sync("maxAmmo", true);
	}

	this.set_u32("fire time", 0);

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.addSpriteLayer("weapon", "HeavyMachinegun.png", 21, 13);
	if (layer !is null)
	{
		layer.SetRelativeZ(2);
    	layer.SetLighting(false);
		layer.SetOffset(Vec2f(-4, 0));
		Animation@ anim = layer.addAnimation("fire left", Maths::Round(FIRE_RATE), false);
		anim.AddFrame(2);
		anim.AddFrame(0);

		Animation@ anim2 = layer.addAnimation("fire right", Maths::Round(FIRE_RATE), false);
		anim2.AddFrame(1);
		anim2.AddFrame(0);

		Animation@ anim3 = layer.addAnimation("default", 1, false);
		anim3.AddFrame(0);
		layer.SetAnimation("default");
	}
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null)
	{
		Manual(this, occupier);
	}

	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null && canShoot(this))
			refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
	}
}

void Manual(CBlob@ this, CBlob@ controller)
{
	Vec2f aimpos = controller.getAimPos();
	Vec2f pos = this.getPosition();
	Vec2f aimVector = aimpos - pos;

	// fire
	if (controller.isMyPlayer() && controller.isKeyPressed(key_action1) && isClearShot(this, aimVector))
	{
		Fire(this, aimVector, controller.getNetworkID());
	}

	// rotate turret
	Rotate(this, aimVector);
	aimVector.y *= -1;
	controller.setAngleDegrees(aimVector.Angle());
}

bool canShoot(CBlob@ this)
{
	return this.get_u32("fire time") + FIRE_RATE < getGameTime();
}

const bool isClearShot(CBlob@ this, Vec2f&in aimVector)
{
	Vec2f pos = this.getPosition();
	const f32 distanceToTarget = Maths::Max(aimVector.Length(), 80.0f);
	CMap@ map = getMap();

	Vec2f offset = aimVector;
	offset.Normalize();
	offset *= 7.0f;

	HitInfo@[] hitInfos;
	map.getHitInfosFromRay(pos + offset.RotateBy(30), -aimVector.Angle(), distanceToTarget, this, @hitInfos);
	map.getHitInfosFromRay(pos + offset.RotateBy(-60), -aimVector.Angle(), distanceToTarget, this, @hitInfos);
	
	const u8 hitLength = hitInfos.length;
	if (hitLength > 0)
	{
		//HitInfo objects are sorted, first come closest hits
		for (u8 i = 0; i < hitLength; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b is null || b is this) continue;
			
			const bool sameShip = this.getShape().getVars().customData == b.getShape().getVars().customData;
			if (b.hasTag("block") && b.getShape().getVars().customData > 0 && ((b.hasTag("solid") && !b.hasTag("plank")) || b.hasTag("weapon")) && sameShip)
			{
				return false;
			}
		}
	}

	return true;
}

void Fire(CBlob@ this, Vec2f&in aimVector, const u16&in netid)
{
	CBitStream params;
	params.write_netid(netid);
	params.write_Vec2f(aimVector);
	this.SendCommand(this.getCommandID("fire"), params);
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
	if (layer !is null)
	{
		layer.ResetTransform();
		layer.RotateBy(-aimVector.getAngleDegrees() - this.getAngleDegrees(), -layer.getOffset());
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd != this.getCommandID("fire")) return;
	
	if (!canShoot(this)) return;

	CBlob@ shooter = getBlobByNetworkID(params.read_netid());
	if (shooter is null) return;

	this.set_u32("fire time", getGameTime());
	
	CPlayer@ attacker = shooter.getPlayer();
	if (attacker !is null && attacker !is this.getDamageOwnerPlayer())
		this.SetDamageOwnerPlayer(shooter.getPlayer());
	
	Vec2f aimVector = params.read_Vec2f();
	Vec2f pos = this.getPosition();

	//ammo
	u16 ammo = this.get_u16("ammo");
	if (ammo == 0)
	{
		directionalSoundPlay("LoadingTick1", pos, 1.0f);
		return;
	}

	ammo--;
	this.set_u16("ammo", ammo);
	
	Vec2f barrelOffset;
	if (this.get_string("barrel") == "left")
	{
		barrelOffset = Vec2f(14, -2.0).RotateBy(-aimVector.Angle());
		this.set_string("barrel", "right");
	}
	else
	{
		barrelOffset = Vec2f(14, 2.0).RotateBy(-aimVector.Angle());
		this.set_string("barrel", "left");
	}
	
	Vec2f barrelPos = pos + barrelOffset;

	if (isServer())
	{
		shootGun(this.getNetworkID(), -aimVector.Angle() + XORRandom(2) - XORRandom(4), barrelPos); //make bullets!
	}

	if (isClient())
	{
		CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
		if (layer !is null)
		{
			if (this.get_string("barrel") == "left")
				layer.SetAnimation("fire left");
			else
				layer.SetAnimation("fire right");
		}
		Rotate(this, aimVector);
		shotParticles(barrelPos, aimVector.Angle(), false);
		directionalSoundPlay("AutoFire", barrelPos);
	}
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
