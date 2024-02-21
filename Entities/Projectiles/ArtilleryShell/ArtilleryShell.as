#include "ExplosionEffects.as";;
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

const f32 EXPLODE_RADIUS = 20.0f;
const f32 BOMB_BASE_DAMAGE = 3.5f;

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 8);
		_booty_reward.addTagReward("engine", 6);
		_booty_reward.addTagReward("weapon", 8);
		_booty_reward.addTagReward("core", 12);
		@booty_reward = _booty_reward;
	}
	
	this.Tag("flak shell");
	this.Tag("projectile");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;

	CSprite@ sprite = this.getSprite();
	//CSpriteLayer@ layer = sprite.addSpriteLayer("layer", "flakBullet.png", 15, 5);
	//if (layer !is null)
	//{
	//	layer.ScaleBy(Vec2f(0.5,0.8));
	//	layer.setRenderStyle(RenderStyle::additive);
	//}
	sprite.SetZ(550.0f);
	sprite.SetEmitSound("Shell_Whistle.ogg");
	sprite.SetEmitSoundPaused(false);
	sprite.SetEmitSoundVolume(4);
	sprite.ScaleBy(Vec2f(0.7,0.8));
	
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

	if (b.getTeamNum() == this.getTeamNum()) return;
	
	if (!isServer()) return;
	
	if (b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity()))
		return;
	
	//blow up inside the target (big damage)
	const bool sameTeam = this.getTeamNum() == b.getTeamNum();
	if ((b.hasTag("solid")) || b.hasTag("door") || 
		(!sameTeam && ((b.hasTag("core") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("bomb")) || (b.hasTag("player") && !b.isAttached()))))
		this.server_Die();
}

void flak(CBlob@ this)
{
	const Vec2f pos = this.getPosition();

	//hit blobs
	CBlob@[] blobs;
	if (!getMap().getBlobsInRadius(pos, EXPLODE_RADIUS, @blobs))
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
		
			const f32 distanceFactor = Maths::Min(1.0f, Maths::Max(0.0f, EXPLODE_RADIUS - this.getDistanceTo(hit_blob) + 8.0f) / EXPLODE_RADIUS);

			//hit the object
			this.server_Hit(hit_blob, hit_blob_pos, Vec2f_zero, BOMB_BASE_DAMAGE * distanceFactor, Hitters::bomb, true);
			//print(hit_blob.getNetworkID() + " for: " + BOMB_BASE_DAMAGE * distanceFactor + " dFctr: " + distanceFactor + ", dist: " + this.getDistanceTo(hit_blob));
		}
		
		CPlayer@ owner = this.getDamageOwnerPlayer();
		if (owner !is null && hitCol > 0)
		{
			rewardBooty(owner, hit_blob, booty_reward, "Pinball_3");
		}
	}
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	
	if (isClient())
	{
		directionalSoundPlay("ArtilleryShellExplode", pos, 10.0f);
		const u8 particleAmount = v_fastrender ? 1 : 3;
		for (u8 i = 0; i < particleAmount; i++)
		{
			makeSmallExplosionParticle(pos + getRandomVelocity(90, 12, 360));
		}
		makeHugeExplosionParticle(pos);
		ShakeScreen(4 * EXPLODE_RADIUS, 45, pos);
	}

	if (isServer() && !this.hasTag("noFlakBoom"))
		flak(this);
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
