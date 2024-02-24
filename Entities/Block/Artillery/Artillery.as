#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "ShipsCommon.as";
#include "Hitters.as";
#include "ExplosionEffects.as";

const f32 PROJECTILE_SPEED = 10.0f;
const f32 FIRE_RATE = 800;
const f32 PROJECTILE_RANGE = 1000.0f;
const int ENGINE_COEF = 9; //how much engines decrease reloading time, in ticks
const f32 TURN_SPEED = 2.0f;

const u8 MAX_AMMO = 6;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 23;
const u8 REFILL_SECONDARY_CORE_SECONDS = 30;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;
const Vec2f BARREL_OFFSET = Vec2f(-5, 0);

const f32 BOMB_RADIUS = 15.0f;
const f32 BOMB_BASE_DAMAGE = 2.7f;

void onInit(CBlob@ this)
{
	this.Tag("weapon");
	this.Tag("usesAmmo");
	
	this.Tag("noEnemyEntry");
	this.set_string("seat label", "Operate Artillery");
	this.set_u8("seat icon", 7);
	
	this.set_f32("weight", 40.0f);
	
	this.set_f32("gives_zoom", 0.3f);
	
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
	
	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
			refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
	}
	f32 angle = -this.get_f32("rot_angle");
	
	Vec2f seat_offset = Vec2f(-5, -6).RotateBy(angle);
	this.getAttachments().getAttachmentPointByName("SEAT").offset = seat_offset;
	
	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ base = this.getSprite().getSpriteLayer("weapon");
		CSpriteLayer@ barrel = this.getSprite().getSpriteLayer("movable");

		f32 difference = gameTime - this.get_u32("fire time");
		Vec2f barrel_offset = Vec2f(3, 0) - Vec2f(8, 0) * Maths::Min(difference / getAcceleratedFireRate(this), 1);

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
		if(getAcceleratedFireRate(this) - difference == 18) directionalSoundPlay("Artillery_loaded", this.getPosition(), 1.8f);
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
	CSprite@ sprite = controller.getSprite();
	sprite.ResetTransform();
	sprite.RotateBy(this.getAngleDegrees() - this.get_f32("rot_angle") - controller.getAngleDegrees(), Vec2f_zero); //Rotate player sprite without rotating blob because otherwise rotation would be continious
}

f32 getAcceleratedFireRate(CBlob@ this)
{
	if(this is null) return FIRE_RATE;

	const int col = this.getShape().getVars().customData;
	if (col <= 0) return FIRE_RATE;

	Ship@ ship = getShipSet().getShip(col);
	if (ship is null) return FIRE_RATE;
	
	f32 firerate = Maths::Max(FIRE_RATE - ship.engineblockcount * ENGINE_COEF, 8);
	return firerate;
}

bool canShootManual(CBlob@ this)
{
	return this.get_u32("fire time") + getAcceleratedFireRate(this) < getGameTime();
}

void Fire(CBlob@ this, Vec2f&in aimVector, const u16&in netid)
{
	const f32 aimdist = Maths::Min(aimVector.Normalize(), PROJECTILE_RANGE);

	const Vec2f _vel = (aimVector * PROJECTILE_SPEED);
	const f32 _lifetime = Maths::Max(0.05f + aimdist/PROJECTILE_SPEED/32.0f, 0.25f);

	CBitStream params;
	params.write_netid(netid);
	params.write_f32(_lifetime);
	this.SendCommand(this.getCommandID("fire"), params);
	this.set_u32("fire time", getGameTime());
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	f32 degrees = loopAngle(aimVector.getAngleDegrees() + this.getAngleDegrees());
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

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();

	//if (isServer())
	//	explode(this);
		
	if (this.getShape().getVars().customData > 0 && !this.hasTag("disabled"))
	{
		if (isServer()) Explode(this);
			
		if (isClient())
		{
			directionalSoundPlay("Bomb.ogg", pos, 2.0f);
			const u8 particleAmount = v_fastrender ? 1 : 3;
			for (u8 i = 0; i < particleAmount; i++)
			{
				makeSmallExplosionParticle(pos + getRandomVelocity(90, 12, 360));
			}
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
	}
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
		
		f32 angle = -this.get_f32("rot_angle") + this.getAngleDegrees();

		const Vec2f velocity = Vec2f((PROJECTILE_SPEED), 0).RotateBy(angle, Vec2f());
		
		Vec2f bullet_offset = pos + Vec2f(25, 0).RotateBy(angle, Vec2f());

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
				bullet.setAngleDegrees(angle);
            }
    	}

		if (isClient())
		{
			shotParticles(bullet_offset, -angle);
			directionalSoundPlay("Artillery_fire.ogg", bullet_offset, 5.5f);
		}
    }
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	if(detached is null) return;
	detached.getSprite().ResetTransform();
}