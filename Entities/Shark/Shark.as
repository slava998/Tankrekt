#include "WaterEffects.as";
#include "Booty.as";
#include "AccurateSoundPlay.as";
#include "ShipsCommon.as";
#include "TileCommon.as";

const f32 SHARK_SPEED = 0.75f;

void onInit(CBlob@ this)
{
	//find target to swim towards
	this.set_Vec2f("target", getTargetVel(this) * 0.5f);
	
	this.set_bool("retreating", false);

	CSprite@ sprite = this.getSprite();
	sprite.SetZ(-10.0f);
	sprite.ReloadSprites(0,0); //always blue
	sprite.SetAnimation("out");
	
	this.SetMapEdgeFlags(u8(CBlob::map_collide_up | CBlob::map_collide_down | CBlob::map_collide_sides));
}

void onTick(CBlob@ this)
{
	if (this.getPlayer() is null)
	{
		// bot
		Vec2f pos = this.getPosition();	
		
		CMap@ map = getMap();
		Tile tile = map.getTile(pos);
		if (map.isTileBackgroundNonEmpty(tile) || map.isTileSolid(tile)) //on land
			this.set_bool("retreating", true);
		
		const u32 gameTime = getGameTime();
		const u32 ticktime = (gameTime + this.getNetworkID());

		if (ticktime % 5 == 0 && //check each 5 ticks
			this.hasTag("vanish") && //read tag
			gameTime > this.get_u32("vanishtime")) //compare time
		{
			this.Tag("no gib");
			this.server_Die();
			return;
		}
		if (ticktime % 40 == 0)
		{
			this.set_Vec2f("target", getTargetVel(this));
		}
		
		if (!this.get_bool("retreating"))
			MoveTo(this, this.get_Vec2f("target"));
		else
		{
			MoveTo(this, -this.get_Vec2f("target"));
			this.Tag("vanish");
		}
	}
	else
	{
		// player
		const f32 speed = SHARK_SPEED * 2.0f;
		Vec2f vel = this.getVelocity();
		Vec2f move_vel = Vec2f_zero;
		if (this.isKeyPressed(key_up))
		{
			move_vel.y -= 1;
		}
		if (this.isKeyPressed(key_down))
		{
			move_vel.y += 1;
		}
		if (this.isKeyPressed(key_left))
		{
			move_vel.x -= 1;
		}
		if (this.isKeyPressed(key_right))
		{
			move_vel.x += 1;
		}
		move_vel.Normalize();
		move_vel *= speed;
		MoveTo(this, vel + move_vel);
		
		this.getSprite().SetAnimation("default");
	}
}

//sprite update
void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	if (this.isAnimation("out") && this.isAnimationEnded())
		this.SetAnimation("default");

	if (blob.hasTag("vanish"))
		this.SetAnimation("in");
}

Random _anglerandom(0x9090); //clientside

void MoveTo(CBlob@ this, const Vec2f&in vel)
{
	Vec2f pos = this.getPosition();	

	// move

	Vec2f moveVel = vel;
	const f32 angle = moveVel.Angle();
	moveVel *= SHARK_SPEED;

	if (this.isMyPlayer())
	{
		Vec2f fat = vel;
		fat.Normalize();
		fat *= 16;
		if (isTouchingLand(pos + fat))
		{
			moveVel = Vec2f_zero;
		}
	}

	this.setVelocity(moveVel);
	if (moveVel.Length() > 0.1f)
	{
		this.setAngleDegrees(-angle);	

		// water effect
		if ((getGameTime() + this.getNetworkID()) % (v_fastrender ? 13 : 9) == 0)
		{
			MakeWaterWave(pos, Vec2f_zero, -angle + (_anglerandom.NextRanged(100) > 50 ? 180 : 0)); 
		}
	}
}

Vec2f getTargetVel(CBlob@ this)
{
	CBlob@[] blobsInRadius;
	Vec2f pos = this.getPosition();
	Vec2f target = this.getVelocity();
	u8 humansInWater = 0;
	if (getMap().getBlobsInRadius(pos, 150.0f, @blobsInRadius))
	{
		f32 maxDistance = 9999999.9f;
		const u16 blobsLength = blobsInRadius.length;
		for (u16 i = 0; i < blobsLength; i++)
		{
			CBlob@ b = blobsInRadius[i];
			if (!b.get_bool("onGround") && b.getName() == "human")
			{
				humansInWater++;
				f32 dist = (pos - b.getPosition()).getLength();
				if (dist < maxDistance)
				{
					target = b.getPosition() - pos;
					maxDistance = dist;
				}
			}
		}
	}

	if (humansInWater == 0)
	{
		this.Tag("vanish");
		this.set_u32("vanishtime", getGameTime() + 15);
	}

	target.Normalize();
	return target;
}

void onDie(CBlob@ this)
{
	MakeWaterParticle(this.getPosition(), Vec2f_zero); 
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob is null) return;
	CPlayer@ ply = this.getPlayer();
	if (blob.getName() == "human" && !blob.get_bool("onGround") && !(ply !is null && this.getTeamNum() == blob.getTeamNum())) // dont kill your own people if you are a shark
	{
		MakeWaterParticle(point1, Vec2f_zero); 
		directionalSoundPlay("ZombieBite", point1);
		this.server_Hit(blob, point1, Vec2f_zero, 9000, 69); // 69 will be shark hitter from now on! :)
		
		if (ply is null)
			this.server_Die();
	}
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	this.Untag("vanish");
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (isClient())
	{
		ParticleBloodSplat(worldPoint, true);
		directionalSoundPlay("BodyGibFall", worldPoint);
	}

	if (this.getHealth() - damage <= 0 && hitterBlob !is this)
	{
		CPlayer@ owner = hitterBlob.getDamageOwnerPlayer();
		if (owner !is null)
		{
			string pName = owner.getUsername();
			if (owner.isMyPlayer())
				directionalSoundPlay("coinpick.ogg", worldPoint, 0.75f);

			if (isServer())
				server_addPlayerBooty(pName, 10);
		}
	}
	
	return damage;
}
