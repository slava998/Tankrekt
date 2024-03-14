#include "ShipsCommon.as";
#include "AccurateSoundPlay.as"
#include "ShiprektTranslation.as";
#include "CustomSync.as";
#include "ParticleSpark.as";
#include "ExplosionEffects.as";;
#include "Hitters.as"

const u8 INTERACTION_RANGE = 20;
const u16 PRODUCTION_RATE = 3600; //30 ticks = 1 second
const u8 MAX_PRODUCT_STORED = 10;
const f32 EXPLODE_RADIUS = 15.0f;

void onInit(CBlob@ this)
{
	this.set_f32("weight", 3.5f);
	
	this.Tag("solid");
	this.Tag("factory");
	this.addCommandID("take");
	this.addCommandID("store");
	this.getCurrentScript().tickFrequency = 60; //tick once in 2 seconds
	
	CSpriteLayer@ layer = this.getSprite().addSpriteLayer("factory", "RocketFactory.png", 20, 20);
	if (layer !is null)
    {
		layer.SetRelativeZ(2);
		layer.ScaleBy(Vec2f(0.6f, 0.6f));
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > INTERACTION_RANGE
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum()
		|| caller.get_string("gunName") != "rpg") //only player with rpg can take rockets
		return;

	CBitStream params;
	params.write_netid(caller.getNetworkID());
	CButton@ button = caller.CreateGenericButton(0 , Vec2f_zero, this, MakeMenu, "");
	if (button !is null)
	{
		button.radius = 8.0f;
		button.enableRadius = INTERACTION_RANGE * 1.2f;
	}
}

void onTick(CBlob@ this)
{
	//print("num " + this.get_u8("product_stored") + " || " + this.get_bool("active") + " | this.get_bool(updateBlock) " + this.get_bool("updateBlock"));
		
	if (this.get_bool("updateBlock"))
		DoUpdate(this); //turn it on/off when placed or ship becomes/stops being station
		
	if(!this.get_bool("active") || this.get_u8("product_stored") >= MAX_PRODUCT_STORED)
		return;
	
	const bool client = isClient();
	
	const s32 last_produce = this.get_u32("last_produce_time");
	const s32 time = getGameTime();
	
	const Vec2f pos = this.getPosition();
	if(time - last_produce >= PRODUCTION_RATE - 520) //520 is the length of the sound
	{
		if(!this.get_bool("sound_played"))
		{
			this.getCurrentScript().tickFrequency = 2;
			if(client) directionalSoundPlay("produce_sound", pos);
			this.set_bool("sound_played", true);
		}
		if(client) Shake(this);
	}
	
	if(time - last_produce >= PRODUCTION_RATE)
	{
		this.add_u8("product_stored", 1);
		this.set_u32("last_produce_time", time);
		this.set_bool("sound_played", false);
		if(client && this.get_u8("product_stored") >= MAX_PRODUCT_STORED) 
			directionalSoundPlay("propellerStall.ogg", pos, 6.0f);

		this.getCurrentScript().tickFrequency = 60; //tick once in 2 seconds
	}
}

void DoUpdate(CBlob@ this)
{
	this.set_bool("updateBlock", false);
	const int color = this.getShape().getVars().customData;
	Ship@ ship = getShipSet().getShip(color);
	if(ship is null) return;
	
	const bool active = this.get_bool("active");
	const bool should_activate = ship.isBuildStation;

	if(active && !should_activate)
		directionalSoundPlay("propellerStall.ogg", this.getPosition(), 6.0f);
	this.set_bool("active", should_activate);
	this.set_u32("last_produce_time", getGameTime());
	SyncU32(this.getNetworkID(), "last_produce_time");
	SyncBool(this.getNetworkID(), "active");
}

void MakeMenu(CBlob@ this, CBlob@ caller)
{
	CGridMenu@ menu = CreateGridMenu(this.getScreenPos(), this, Vec2f(4,2), "");
	if (menu is null) return;
	
	CBitStream params;
	params.write_netid(caller.getNetworkID());
	
	menu.deleteAfterClick = true;
	
	{ //Set Spawn
		CGridButton@ button = menu.AddButton("$HERE$", Trans::Take, this.getCommandID("take"), params);
		button.SetHoverText(Trans::Take);
	}
	{ //Reset Spawn
		CGridButton@ button = menu.AddButton("$UP$", Trans::Store, this.getCommandID("store"), params);
		button.SetHoverText(Trans::Store);
	}
}

void Shake(CBlob@ this)
{
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.getSpriteLayer("factory");
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
		Vec2f pos = Vec2f((XORRandom(4) - XORRandom(2)), ((XORRandom(4) - XORRandom(2)))) *  0.2f;
		layer.SetOffset(pos);
		
		Vec2f smoke_pos = Vec2f(this.getPosition().x + (XORRandom(4) - XORRandom(2)) * 0.5, this.getPosition().y + (XORRandom(4) - XORRandom(2)) * 0.5);
		Vec2f smoke_vel = Vec2f(velraw.x + (XORRandom(4) - XORRandom(2)) * 0.25, velraw.y + (XORRandom(4) - XORRandom(2)) * 0.25);

		if(!v_fastrender) //no smoke if faster graphics is enabled
		{
			if(getGameTime() % Maths::Floor((Maths::Clamp(32 / Maths::Max(vel * 2, 1), 2, 32))) == 0)
			{
				smoke(smoke_pos, smoke_vel);
			}
		}
    }
}

//Display the number of rockets inside
void onRender(CSprite@ this)
{
	CBlob@ local = getLocalPlayerBlob();
	CBlob@ b = this.getBlob();
	if(local !is null && local.isMyPlayer() && b.getTeamNum() == local.getTeamNum())
	{
		GUI::SetFont("MENU");
		GUI::DrawText(Trans::RocketsProduced + b.get_u8("product_stored"), b.getInterpolatedScreenPos() + Vec2f(8,-12), SColor(255,255,255,255));
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("take"))
    {
		if(this is null) return;

		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		if(caller is null) return;
		
		if(this.get_u8("product_stored") > 0 && caller.get_u16("total_ammo") < caller.get_u16("total_ammo_max"))
		{
			this.sub_u8("product_stored", 1);
			caller.add_u16("total_ammo", 1);
			if(isClient() && caller.isMyPlayer())
				directionalSoundPlay("Pickup_standard.ogg",  caller.getPosition(), 4.0f);
		}
		else if(isClient() && caller.isMyPlayer())
			directionalSoundPlay("NoAmmo.ogg",  caller.getPosition(), 4.0f);
	}
	else if (cmd == this.getCommandID("store"))
    {
		if(this is null) return;

		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		if(caller is null) return;
		
		if(this.get_u8("product_stored") < MAX_PRODUCT_STORED && caller.get_u16("total_ammo") > 0)
		{
			caller.sub_u16("total_ammo", 1);
			this.add_u8("product_stored", 1);
			if(isClient() && caller.isMyPlayer())
			{
				directionalSoundPlay("Pickup_standard.ogg",  caller.getPosition(), 4.0f);
				if(this.get_u8("product_stored") >= MAX_PRODUCT_STORED) 
					directionalSoundPlay("propellerStall.ogg", this.getPosition(), 6.0f);
			}
		}
		else if(isClient() && caller.isMyPlayer())
			directionalSoundPlay("NoAmmo.ogg",  caller.getPosition(), 4.0f);
	}
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();

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
				if (b.hasTag("solid") || b.hasTag("door") || b.hasTag("seat") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("core") || b.hasTag("bomb") || (b.hasTag("player") && !b.isAttached()))
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
	if (hitBlob.hasTag("engineblock") || hitBlob.hasTag("factory"))
		return 40.0f; //chain explosion
	if (hitBlob.hasTag("rocket"))
		return 1.25f; 
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("plank"))
		return 1.5f;
	if (hitBlob.hasTag("ramengine"))
		return 3.0f;
	if (hitBlob.hasTag("door"))
		return 1.0f;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 1.0f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon") || hitBlob.hasTag("bomb"))
		return 2.0f;
	if (hitBlob.hasTag("core"))
		return 0.2f;
	return 1.0f;
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