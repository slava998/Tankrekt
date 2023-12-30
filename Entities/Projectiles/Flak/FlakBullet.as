#include "ExplosionEffects.as";;
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

const f32 EXPLODE_RADIUS = 30.0f;
const f32 FLAK_REACH = 50.0f;

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 4);
		_booty_reward.addTagReward("engine", 2);
		_booty_reward.addTagReward("mothership", 8);
		_booty_reward.addTagReward("secondarycore", 6);
		_booty_reward.addTagReward("weapon", 5);
		@booty_reward = _booty_reward;
	}
	
	this.Tag("flak shell");
	this.Tag("projectile");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;

	this.getSprite().SetZ(550.0f);
	
	//shake screen (onInit accounts for firing latency)
	CPlayer@ localPlayer = getLocalPlayer();
	if (localPlayer !is null && localPlayer is this.getDamageOwnerPlayer())
		ShakeScreen(4, 4, this.getPosition());
}

void onCollision(CBlob@ this, CBlob@ b, bool solid, Vec2f normal, Vec2f point1)
{
	if (b is null) //solid tile collision
	{
		this.server_Die();
		return;
	}
	
	if (!isServer()) return;
	
	if (b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity()))
		return;
	
	//blow up inside the target (big damage)
	const bool sameTeam = this.getTeamNum() == b.getTeamNum();
	if ((b.hasTag("solid")) || b.hasTag("door") || 
		(!sameTeam && ((b.hasTag("core") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("bomb")) || (b.hasTag("player") && !b.isAttached()))))
	{
		this.server_Hit(b, point1, Vec2f_zero, getDamage(b) * 7, Hitters::bomb, true);
		this.Tag("noFlakBoom");
		
		this.server_Die();
	}
}

void flak(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	CMap@ map = getMap();
	CBlob@[] blobs;
	map.getBlobsInRadius(pos, FLAK_REACH, @blobs);
	
	if (blobs.length < 2) return;
		
	f32 angle = XORRandom(360);

	for (u8 s = 0; s < 12; s++)
	{
		HitInfo@[] hitInfos;
		if (map.getHitInfosFromRay(pos, angle, FLAK_REACH, this, @hitInfos))
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

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	
	if (isClient())
	{
		directionalSoundPlay("FlakExp"+XORRandom(2), pos, 2.0f);
		const u8 particleAmount = v_fastrender ? 1 : 3;
		for (u8 i = 0; i < particleAmount; i++)
		{
			makeSmallExplosionParticle(pos + getRandomVelocity(90, 12, 360));
		}
	}

	if (isServer() && !this.hasTag("noFlakBoom"))
		flak(this);
}

const f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("rocket"))
		return 0.25f; 
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("plank"))
		return 0.2f;
	if (hitBlob.hasTag("ramengine"))
		return 0.4f;
	if (hitBlob.hasTag("door"))
		return 0.3f;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 0.3f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon") || hitBlob.hasTag("bomb") || hitBlob.hasTag("core"))
		return 0.1f;
	return 0.06f;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null)
	{
		rewardBooty(owner, hitBlob, booty_reward);
	}
	
	if (!isClient()) return;
	
	if (hitBlob.hasTag("block"))
	{
		Vec2f vel = worldPoint - hitBlob.getPosition();
		ShrapnelParticle(worldPoint, vel);
		directionalSoundPlay("Ricochet" +  (XORRandom(3) + 1) + ".ogg", worldPoint, 0.35f);
	}
}
