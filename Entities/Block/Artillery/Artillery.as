#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "ShipsCommon.as";

const f32 PROJECTILE_SPEED = 10.0f;
const f32 PROJECTILE_SPREAD = 0.5f;
const int FIRE_RATE = 500;
const f32 PROJECTILE_RANGE = 600.0f;
const int ENGINE_COEF = 17; //how much engines decrease reloading time, in ticks
const f32 TURN_SPEED = 2.0f;

const u8 MAX_AMMO = 6;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 18;
const u8 REFILL_SECONDARY_CORE_SECONDS = 30;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;
const Vec2f BARREL_OFFSET = Vec2f(-5, 0);

Random _shotspreadrandom(0x11598); //clientside

void onInit(CBlob@ this)
{
	this.Tag("weapon");
	this.Tag("usesAmmo");
	
	this.Tag("noEnemyEntry");
	this.set_string("seat label", "Operate Artillery");
	this.set_u8("seat icon", 7);
	
	this.set_f32("weight", 10.0f);
	this.set_u16("fire_rate_accelerated", FIRE_RATE);
	
	this.addCommandID("fire");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true);
		this.Sync("maxAmmo", true);
	}

	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer("weapon", "Artillery_Base.png", 19, 20);
    if (layer !is null)
    {
    	layer.SetRelativeZ(4);
    	layer.SetLighting(false);
    }
	CSpriteLayer@ layer2 = sprite.addSpriteLayer("movable", "Artillery_movable_parts.png", 39, 8);
    if (layer2 !is null)
    {
    	layer2.SetRelativeZ(2);
    	layer2.SetLighting(false);
		layer2.SetOffset(Vec2f(-5, 0));
    }
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	const u32 gameTime = getGameTime();
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null) Manual(this, occupier);

	if(gameTime % 120 == 0) RecountEngines(this);
	
	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
			refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
	}
	f32 angle = -this.get_f32("rot_angle") - this.getAngleDegrees();
	
	Vec2f seat_offset = Vec2f(-5, -6).RotateBy(angle);
	this.getAttachments().getAttachmentPointByName("SEAT").offset = seat_offset;
	
	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ base = this.getSprite().getSpriteLayer("weapon");
		CSpriteLayer@ barrel = this.getSprite().getSpriteLayer("movable");

		f32 difference = gameTime - this.get_u32("fire time"); //needs to be a separate variable to make it float
		Vec2f barrel_offset = Vec2f(3, 0) - Vec2f(8, 0) * Maths::Min(difference / this.get_u16("fire_rate_accelerated"), 1);

		if (barrel !is null)
		{
			barrel.ResetTransform();
			barrel.SetOffset(barrel_offset);
			barrel.RotateBy(angle, -barrel_offset);
		}
		
		if (base !is null)
		{
			base.ResetTransform();
			base.RotateBy(angle, Vec2f_zero);
		}
		
		if(this.get_u16("fire_rate_accelerated") - difference == 18) directionalSoundPlay("Artillery_loaded", this.getPosition(), 1.8f);
	}
}

void Manual(CBlob@ this, CBlob@ controller)
{
	Vec2f aimpos = controller.getAimPos();
	Vec2f pos = this.getPosition();
	Vec2f aimVec = aimpos - pos;

	// fire
	if (controller.isMyPlayer() && controller.isKeyPressed(key_action1) && canShootManual(this))
	{
		Fire(this, aimVec, controller.getNetworkID());
	}

	// rotate turret
	Rotate(this, aimVec);
	aimVec.y *= -1;
	controller.setAngleDegrees((-this.get_f32("rot_angle")));
}

//TODO: REMAKE THIS!!!
void RecountEngines(CBlob@ this)
{
	if(this is null) return;

	const int col = this.getShape().getVars().customData;
	if (col <= 0) return;

	Ship@ ship = getShipSet().getShip(col);
	if (ship is null) return;
	
	u16 engineblockcount = 0;
	const u16 blocksLength = ship.blocks.length;
	for (u16 q = 0; q < blocksLength; ++q)
	{
		ShipBlock@ ship_block = ship.blocks[q];
		CBlob@ b = getBlobByNetworkID(ship_block.blobID);
		if (b.hasTag("engineblock"))
			engineblockcount += 1;
	}
	this.set_u16("fire_rate_accelerated", Maths::Max(FIRE_RATE - engineblockcount * ENGINE_COEF, 15));
	return;
}
//

bool canShootManual(CBlob@ this)
{
	return this.get_u32("fire time") + this.get_u16("fire_rate_accelerated") < getGameTime();
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

			//if (b.hasTag("block") && b.getShape().getVars().customData > 0 && ((b.hasTag("solid") && !b.hasTag("plank")) || b.hasTag("weapon")) && sameShip && !canShootSelf)
			//{
				return true;
			//}
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
	params.write_f32(_lifetime);
	this.SendCommand(this.getCommandID("fire"), params);
	this.set_u32("fire time", getGameTime());
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	f32 degrees = aimVector.getAngleDegrees();
	f32 curr_angle = this.get_f32("rot_angle");
	f32 diff = curr_angle - degrees;
	if(diff < 180 && diff > -180) diff = curr_angle - degrees;
	else diff = degrees - curr_angle;
	f32 new_angle = loopAngle((curr_angle - Maths::Clamp(diff, -TURN_SPEED, TURN_SPEED)));
	
	this.set_f32("rot_angle", new_angle);
}

// Keeps an angle within the engine's boundaries (-740 to 740)
const f32 loopAngle(f32 angle)
{
	while (angle < 0.0f)	angle += 360.0f;
	while (angle > 360.0f)	angle -= 360.0f;
	return angle;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("fire"))
    {
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
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

		Vec2f offset(_shotspreadrandom.NextFloat() * PROJECTILE_SPREAD, 0);
		offset.RotateBy(_shotspreadrandom.NextFloat() * 360.0f, Vec2f());
		
		f32 angle = this.get_f32("rot_angle");

		const Vec2f velocity = Vec2f((PROJECTILE_SPEED), 0).RotateBy(-angle, Vec2f()) + offset;
		
		Vec2f bullet_offset = pos + Vec2f(25, 0).RotateBy(-angle, Vec2f());

		if (isServer())
		{
            CBlob@ bullet = server_CreateBlob("artilleryshell", this.getTeamNum(), bullet_offset);
            if (bullet !is null)
            {
            	if (caller !is null)
				{
					if (caller.getPlayer() !is null)
						bullet.SetDamageOwnerPlayer(caller.getPlayer());
				}

                bullet.setVelocity(velocity);
                bullet.server_SetTimeToDie(params.read_f32());
				bullet.setAngleDegrees(-angle);
            }
    	}

		if (isClient())
		{
			shotParticles(bullet_offset, angle);
			directionalSoundPlay("Artillery_fire.ogg", bullet_offset, 2.5f);
		}
    }
}
