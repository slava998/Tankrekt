//////////////////////////////////////////////////////
//
//  BulletMain.as - Vamist
//
//  CORE FILE
//  
//  A bit messy, stuff gets removed and added as time 
//  goes on. Handles spawning bullets and making sure
//  clients can render bullets
//
//  Try not poke around here unless you need to
//  Some code here is messy
//

#include "BulletClass.as";
#include "ParticleSpark.as";
#include "AccurateSoundPlay.as";

// I would use blob.getNetworkID, but without some major changes
// It would be the same pattern every time
// This value resets every time a new player joins
//
// TODO-> SERVER SENDS RANDOM VALUE ON NEW PLAYER JOIN (DIFFERENT SEED)
Random@ r = Random(12345);

// Core vars
BulletHolder@ BulletGrouped = BulletHolder();

Vertex[] v_r_bullet;

SColor white = SColor(255,255,255,255);

int FireGunID;
int FireShotgunID;

f32 FRAME_TIME = 0;
//

// Set commands, add render:: (only do this once)
void onInit(CRules@ this)
{
	Reset(this);

	if (isClient())
	{
		Render::addScript(Render::layer_prehud, "BulletMain", "GunRender", 0.0f);
	}
	
	/*if (!isClient()) //idk what it does but it need to be commented for dedicated server to work
	{
		string[] rand = (m_seed+"").split(m_seed == 1 ? "\\" : "\%");
		this.set("bullet deviation", rand);
    }*/
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void onReload(CRules@ this)
{
	Reset(this);
}

void Reset(CRules@ this)
{
	r.Reset(12345);
	FireGunID     = this.addCommandID("fireGun");
	FireShotgunID = this.addCommandID("fireShotgun");
	v_r_bullet.clear();
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	r.Reset(12345);
}

// Handles making every bullet go weeee
void onTick(CRules@ this)
{
	FRAME_TIME = 0;
	BulletGrouped.FakeOnTick(this);
}

void GunRender(int id)
{
	FRAME_TIME += getRenderDeltaTime() * getTicksASecond();  // We are using this because ApproximateCorrectionFactor is lerped
	RenderingBullets();
}

void RenderingBullets() // Bullets
{
	BulletGrouped.FillArray(); // Fill up v_r_bullets
	if (v_r_bullet.length() > 0) // If there are no bullets on our screen, dont render
	{
		Render::RawQuads("bullet_long.png", v_r_bullet);

		//if (g_debug == 0) // useful for lerp testing
		{
			v_r_bullet.clear();
		}
	}
}

void onCommand(CRules@ this, u8 cmd, CBitStream @params) 
{
	if (cmd == FireGunID)
	{
		CBlob@ gunBlob = getBlobByNetworkID(params.read_netid());
		if (gunBlob is null) return;

		const f32 angle = params.read_f32();
		Vec2f pos = params.read_Vec2f();
		BulletObj@ bullet = BulletObj(gunBlob, angle, pos);

		u32 timeSpawnedAt = params.read_u32(); // getGameTime() it spawned at
		CMap@ map = getMap(); 
		for (;timeSpawnedAt < getGameTime(); timeSpawnedAt++) // Catch up to everybody else
		{
			bullet.onFakeTick(map);
		}

		BulletGrouped.AddNewObj(bullet);

		if(gunBlob.hasTag("player"))
		{
			printf("recieved fire cmd");
			if(isClient())
			{
				printf("making smoke & sound");

				Vec2f offset = Vec2f(0.5f ,0).RotateBy(angle)*6.0f;
				if(!params.read_bool()) offset *= -1;  //for some reason offset becomes negative when standing on ship
				
				shotParticles(pos + offset, -angle, !gunBlob.get_bool("no_smoke"), 0.02f , 0.6f);

				const u8 srandom = gunBlob.get_u8("sounds_random_length");
				if(srandom > 0)
				{
					directionalSoundPlay(gunBlob.get_string("fire_sound") + XORRandom(srandom), pos, 3.0f);
				}
				else directionalSoundPlay(gunBlob.get_string("fire_sound"), pos, 3.0f);
			}
			
			if(isServer())
			{
				gunBlob.set_u8("ammo", Maths::Max(gunBlob.get_u8("ammo") - 1, 0));
				CBitStream bs;
				bs.write_u32(getGameTime());
				bs.write_u8(gunBlob.get_u8("ammo"));
				bs.write_bool(gunBlob.get_bool("currently_reloading"));
				gunBlob.SendCommand(gunBlob.getCommandID("SyncShootVars"), bs); //sync ammo and fire time
			}
		}
	}
	else if (cmd == FireShotgunID)
	{
		CBlob@ gunBlob = getBlobByNetworkID(params.read_netid());
		if (gunBlob is null) return;

		const f32 angle  = params.read_f32();
		Vec2f pos  = params.read_Vec2f();
		const u8 spread  = gunBlob.get_u8("shot_spread");
		const u8 b_count = gunBlob.get_u8("b_count");
		const bool sFLB  = gunBlob.get_bool("sFLB");
		const u32 timeSpawnedAt = params.read_u32(); // getGameTime() it spawned at
		CMap@ map = getMap(); 

		if (sFLB)
		{
			f32 tempAngle = angle;

			for (u8 a = 0; a < b_count; a++)
			{
				tempAngle += r.NextRanged(2) != 0 ? -r.NextRanged(spread) : r.NextRanged(spread);
				BulletObj@ bullet = BulletObj(gunBlob, tempAngle, pos);

				for (u32 timeSpawned = timeSpawnedAt; timeSpawned < getGameTime(); timeSpawned++) // Catch up to everybody else
				{
					bullet.onFakeTick(map);
				}

				BulletGrouped.AddNewObj(bullet);
			}
		}
		else
		{
			for (u8 a = 0; a < b_count; a++)
			{
				f32 tempAngle = angle;
				tempAngle += r.NextRanged(2) != 0 ? -r.NextRanged(spread) : r.NextRanged(spread);
				BulletObj@ bullet = BulletObj(gunBlob, tempAngle, pos);

				for (u32 timeSpawned = timeSpawnedAt; timeSpawned < getGameTime(); timeSpawned++) // Catch up to everybody else
				{
					bullet.onFakeTick(map);
				}

				BulletGrouped.AddNewObj(bullet);
			}
		}
		if(gunBlob.hasTag("player"))
		{
			printf("recieved fire cmd");
			if(isClient())
			{
				printf("making smoke & sound");

				Vec2f offset = Vec2f(0.5f ,0).RotateBy(angle)*6.0f;
				if(!params.read_bool()) offset *= -1;  //for some reason offset becomes negative when standing on ship
					
				shotParticles(pos + offset, -angle, !gunBlob.get_bool("no_smoke"), 0.02f , 0.6f);

				const u8 srandom = gunBlob.get_u8("sounds_random_length");
				if(srandom > 0)
				{
					directionalSoundPlay(gunBlob.get_string("fire_sound") + XORRandom(srandom), pos, 3.0f);
				}
				else directionalSoundPlay(gunBlob.get_string("fire_sound"), pos, 3.0f);
			}
				
			if(isServer())
			{
				gunBlob.set_u8("ammo", Maths::Max(gunBlob.get_u8("ammo") - 1, 0));
				CBitStream bs;
				bs.write_u32(getGameTime());
				bs.write_u8(gunBlob.get_u8("ammo"));
				bs.write_bool(gunBlob.get_bool("currently_reloading"));
				gunBlob.SendCommand(gunBlob.getCommandID("SyncShootVars"), bs); //sync ammo and fire time
			}
		}
	}
}
