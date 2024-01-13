#include "ShipsCommon.as";
#include "Hitters.as";
#include "AccurateSoundPlay.as";
#include "ExplosionEffects.as";;
#include "ParticleSpark.as";

const f32 EXPLODE_RADIUS = 30.0f;

void onInit(CBlob@ this)
{
    this.Tag("engineblock");
    this.Tag("solid");
	this.set_f32("weight", 3.0f);
}

void onInit(CSprite@ this)
{
	CSpriteLayer@ layer = this.addSpriteLayer("engine", "EngineBlock.png", 8, 8);
	if (layer !is null)
    {
		layer.SetRelativeZ(2);
		layer.ScaleBy(Vec2f(0.9f, 0.9f));
	}
	this.SetEmitSound("Engine_loop.ogg");
	this.SetEmitSoundPaused(false);
}

void onTick(CBlob@ this)
{
	if(!isClient()) return;

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.getSpriteLayer("engine");
	if (layer !is null)
    {
		const int color = this.getShape().getVars().customData;
		if (color <= 0) return;
		
		CRules@ rules = getRules();
		ShipDictionary@ ShipSet = getShipSet(rules);
		
		Ship@ ship = ShipSet.getShip(color);

		if (ship is null) return;

		Vec2f velraw = ship.vel;
		f32 vel = velraw.Length();

		layer.ResetTransform();
		Vec2f pos = Vec2f((XORRandom(4) - XORRandom(2)), ((XORRandom(4) - XORRandom(2)))) * Maths::Clamp(0.2f * vel, 0.15, 0.75);
		layer.SetOffset(pos);
		
		Vec2f smoke_pos = Vec2f(this.getPosition().x + (XORRandom(4) - XORRandom(2)) * 0.5, this.getPosition().y + (XORRandom(4) - XORRandom(2)) * 0.5);
		Vec2f smoke_vel = Vec2f(velraw.x + (XORRandom(4) - XORRandom(2)) * 0.25, velraw.y + (XORRandom(4) - XORRandom(2)) * 0.25);

		if(v_fastrender) //less smoke if faster graphics is enabled
		{
			if(getGameTime() % Maths::Floor((Maths::Clamp(64 / Maths::Max(vel * 2, 1), 2, 64))) == 0)
			{
				smoke(smoke_pos, smoke_vel);
			}
		}
		else if(getGameTime() % Maths::Floor((Maths::Clamp(32 / Maths::Max(vel * 2, 1), 2, 32))) == 0)
		{
			smoke(smoke_pos, smoke_vel);
		}
		sprite.SetEmitSoundVolume(2 * Maths::Clamp(vel, 1, 2.0f));
		sprite.SetEmitSoundSpeed(Maths::Clamp(vel * 0.3, 1, 1.5f));
    }
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();

	//if (isServer())
	//	explode(this);
		
	if (this.getShape().getVars().customData > 0 && !this.hasTag("disabled"))
	{
		if (isServer()) explode(this);
			
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

void explode(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	CMap@ map = getMap();
	CBlob@[] blobs;
	map.getBlobsInRadius(pos, EXPLODE_RADIUS, @blobs);
	
	if (blobs.length < 2) return;
		
	f32 angle = XORRandom(360);

	for (u8 s = 0; s < 12; s++)
	{
		HitInfo@[] hitInfos;
		if (map.getHitInfosFromRay(pos, angle, EXPLODE_RADIUS, this, @hitInfos))
		{
			const u8 hitLength = hitInfos.length;
			for (u8 i = 0; i < hitLength; i++)//sharpnel trail
			{
				CBlob@ b = hitInfos[i].blob;
				if (b is null || b is this) continue;
				
				const bool sameTeam = b.getTeamNum() == this.getTeamNum();
				if (b.hasTag("solid") || b.hasTag("door") || (!sameTeam
					&& (b.hasTag("seat") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("core") || b.hasTag("bomb") || (b.hasTag("player") && !b.isAttached()))))
				{
					this.server_Hit(b, hitInfos[i].hitpos, Vec2f_zero, getDamage(b), Hitters::bomb, true);
					break;
				}
			}
		}
		
		angle = (angle + 30.0f) % 360;
	}
}

const f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("rocket"))
		return 0.25f; 
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("plank"))
		return 0.4f;
	if (hitBlob.hasTag("ramengine"))
		return 0.4f;
	if (hitBlob.hasTag("door"))
		return 0.3f;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 0.3f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon") || hitBlob.hasTag("bomb") || hitBlob.hasTag("core"))
		return 0.2f;
	return 0.09f;
}

Random _smokerandom(0x15125); //clientside
void smoke(const Vec2f&in pos, const Vec2f&in vel)
{
	CParticle@ p = ParticleAnimated("SmallSmoke1.png",
											  pos,
											  vel, //velocity
											  _smokerandom.NextFloat() * 360.0f, //angle
											  1.0f, //scale
											  3+_smokerandom.NextRanged(2), //animtime
											  0.0f, //gravity
											  true); //selflit
	if (p !is null)
		p.Z = 640.0f;
}