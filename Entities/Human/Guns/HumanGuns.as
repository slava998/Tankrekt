#include "WeaponCommon.as";
#include "GunStandard.as";
#include "HumanCommon.as";
#include "ParticleSpark.as";
#include "AccurateSoundPlay.as";
#include "ShiprektTranslation.as";

//Parameters of all guns are here
void ChangeGun(CBlob@ this, const string gun)
{
	if(!isServer()) return; //set only on server, will be synced for clients

	// TODO: Make better damage system where damage depends on hitter, like in TC

	//30 ticks = 1 second
	if(this.get_string("gunName") == "rifle") 		//Rifle
	{
		//Fire parameters
		this.set_f32("bullet_damage", 0.25f);		//Bullet damage
		this.set_u16("fire_rate", 45); 				//Delay after shoot (in ticks)
		this.set_u8("clip_size", 8); 				//Max ammo in clip
		this.set_u8("TTL", 16);						//How long bullet will live (in ticks)
		this.set_u8("speed", 31);					//Bullet speed
		this.set_u8("shot_spread", 0); 				//Shooting spread angle
		this.set_u16("reloading_time", 60);			//Reloading duration (in ticks)
		this.set_u8("b_count", 1);					//Bullets per shot count
		this.set_f32("human_damage_mod", 1.0f);		//Multipiller of damage to players
		
		//Cosmetic
		this.set_string("fire_sound", "rifle_fire");		//Fire sound
		this.set_u8("sounds_random_length", 2);				//The number of sounds the gun can make. For it to work, all sounds must have the same name and have a number at the end (starting from 0). Set to 0 to disable
		this.set_string("reload_sound", "rifle_reload");	//Reloading sound
		this.set_bool("no_smoke", false);					//No smoke when shooting
		this.set_string("gun_icon", "RIFLE");				//Icon in tools menu
		this.set_string("gun_menu_name", Trans::Rifle);		//Gun name in tools menu
		this.set_string("gun_desc", Trans::RifleDesc);		//Gun description in tools menu

	}
	else if(this.get_string("gunName") == "smg") 	//SMG
	{
		//Fire parameters
		this.set_f32("bullet_damage", 0.09f); 		//Bullet damage
		this.set_u16("fire_rate", 3); 				//Delay after shoot (in ticks)
		this.set_u8("clip_size", 30); 				//Max ammo in clip
		this.set_u8("TTL", 11); 					//How long bullet will live (in ticks)
		this.set_u8("speed", 27); 					//Bullet speed
		this.set_u8("shot_spread", 5); 				//Shooting spread angle
		this.set_u16("reloading_time", 60);		//Reloading duration (in ticks)
		this.set_u8("b_count", 1);					//Bullets per shot count
		this.set_f32("human_damage_mod", 1.0f);		//Multipiller of damage to players
				
		this.set_string("fire_sound", "smg_fire");			//Fire sound
		this.set_u8("sounds_random_length", 0);				//The number of sounds the gun can make. For it to work, all sounds must have the same name and have a number at the end (starting from 0). Set to 0 to disable
		this.set_string("reload_sound", "smg_reload");		//Reloading sound
		this.set_bool("no_smoke", true);					//No smoke when shooting
		this.set_string("gun_icon", "SMG");					//Icon in tools menu
		this.set_string("gun_menu_name", Trans::SMG);		//Gun name in tools menu
		this.set_string("gun_desc", Trans::SMGDesc);		//Gun description in tools menu
	}
	else if(this.get_string("gunName") == "shotgun") 	//Shotgun
	{
		//Fire parameters
		this.set_f32("bullet_damage", 0.06f); 		//Bullet damage
		this.set_u16("fire_rate", 60); 				//Delay after shoot (in ticks)
		this.set_u8("clip_size", 8); 				//Max ammo in clip
		this.set_u8("TTL", 7); 						//How long bullet will live (in ticks)
		this.set_u8("speed", 27); 					//Bullet speed
		this.set_u8("shot_spread", 7); 				//Shooting spread angle
		this.set_u16("reloading_time", 100);		//Reloading duration (in ticks)
		this.set_u8("b_count", 9);					//Bullets per shot count
		this.set_f32("human_damage_mod", 1.0f);		//Multipiller of damage to players
				
		this.set_string("fire_sound", "shotgun_fire");		//Fire sound
		this.set_u8("sounds_random_length", 2);				//The number of sounds the gun can make. For it to work, all sounds must have the same name and have a number at the end (starting from 0). Set to 0 to disable
		this.set_string("reload_sound", "shotgun_reload");	//Reloading sound
		this.set_bool("no_smoke", false);					//No smoke when shooting
		this.set_string("gun_icon", "SHOTGUN");				//Icon in tools menu
		this.set_string("gun_menu_name", Trans::Shotgun);	//Gun name in tools menu
		this.set_string("gun_desc", Trans::ShotgunDesc);//Gun description in tools menu
	}
	else if(this.get_string("gunName") == "carbine") //carbine
	{
		//Fire parameters
		this.set_f32("bullet_damage", 0.0468f); 	//Bullet damage
		this.set_u16("fire_rate", 55); 				//Delay after shoot (in ticks)
		this.set_u8("clip_size", 5); 				//Max ammo in clip
		this.set_u8("TTL", 13); 					//How long bullet will live (in ticks)
		this.set_u8("speed", 32); 					//Bullet speed
		this.set_u8("shot_spread", 2); 				//Shooting spread angle
		this.set_u16("reloading_time", 90);			//Reloading duration (in ticks)
		this.set_u8("b_count", 8);					//Bullets per shot count
		this.set_f32("human_damage_mod", 1.0f);		//Multipiller of damage to players
				
		this.set_string("fire_sound", "carbine_fire");		//Fire sound
		this.set_u8("sounds_random_length", 0);				//The number of sounds the gun can make. For it to work, all sounds must have the same name and have a number at the end (starting from 0). Set to 0 to disable
		this.set_string("reload_sound", "rifle_reload");	//Reloading sound
		this.set_bool("no_smoke", false);					//No smoke when shooting
		this.set_string("gun_icon", "CARBINE");				//Icon in tools menu
		this.set_string("gun_menu_name", Trans::Carbine);		//Gun name in tools menu
		this.set_string("gun_desc", Trans::CarbineDesc);	//Gun description in tools menu
	}

	this.set_bool("shotgun", this.get_u8("b_count") > 1 ? true : false);
	this.set_u8("ammo", this.get_u8("clip_size")); 

	SyncGunVars(this);
}

void onInit(CBlob@ this)
{
	this.addCommandID("updateGun");
	this.addCommandID("SyncGun");
	this.addCommandID("SyncShootVars");
	this.addCommandID("reload");
	
	this.set_string("gunName", "rifle"); //starting gun
	this.SendCommand(this.getCommandID("updateGun"));
}

void onTick(CBlob@ this)
{
	if(!isServer()) return;
	if(!this.get_bool("currently_reloading")) return;

	if(this.get_u32("fire time") + this.get_u16("reloading_time") < getGameTime())
	{
		this.set_u8("ammo", this.get_u8("clip_size"));
		this.set_bool("currently_reloading", false);

		CBitStream params;
		params.write_u32(this.get_u32("fire time"));
		params.write_u8(this.get_u8("clip_size"));
		params.write_bool(false);
		
		this.SendCommand(this.getCommandID("SyncShootVars"), params);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if(this is null) return; //just in case

	else if (cmd == this.getCommandID("SyncShootVars")) //sync ammo and fire time
	{
		if(isClient())
		{
			printf("syncing shoot vars");
			this.set_u32("fire time", params.read_u32());
			this.set_u8("ammo", params.read_u8()); 
			this.set_bool("currently_reloading", params.read_bool());
		}
	}
	else if (cmd == this.getCommandID("reload"))
	{
		printf("reloading");
		this.set_bool("currently_reloading", true);
		this.set_u32("fire time", getGameTime());

		directionalSoundPlay(this.get_string("reload_sound"),  this.getPosition(), 2.0f);
		
		CBitStream params;
		params.write_u32(this.get_u32("fire time"));
		params.write_u8(this.get_u8("ammo"));
		params.write_bool(this.get_bool("currently_reloading"));
			
		this.SendCommand(this.getCommandID("SyncShootVars"), params);
	}
	else if(this.getCommandID("updateGun") == cmd)
	{
		printf("recieved update gun command");
		ChangeGun(this, this.get_string("gunName"));
	}
	else if (cmd == this.getCommandID("SyncGun"))
	{
		if(isClient())
		{
			printf("syncing gun");
			this.set_u8("ammo",  params.read_u8());
			this.set_string("gunName", params.read_string());
			this.set_u8("TTL",  params.read_u8());
			this.set_u8("speed",  params.read_u8());
			this.set_u16("fire_rate",  params.read_u16());
			this.set_u8("shot_spread", params.read_u8());
			this.set_u8("clip_size", params.read_u8()); 
			this.set_u16("reloading_time", params.read_u16()); 
			this.set_bool("shotgun", params.read_bool());
			this.set_u8("b_count", params.read_u8()); 
			this.set_string("fire_sound", params.read_string());
			this.set_u8("sounds_random_length", params.read_u8());
			this.set_string("reload_sound", params.read_string());
			this.set_bool("no_smoke", params.read_bool());
			this.set_string("gun_icon", params.read_string());
			this.set_string("gun_menu_name", params.read_string());
			this.set_string("gun_desc", params.read_string());
			this.set_f32("human_damage_mod", params.read_f32());
		}
	}
}

void SyncGunVars(CBlob@ this)
{
	printf("sending gun sync");
	CBitStream params;
	params.write_u8(this.get_u8("ammo"));
	params.write_string(this.get_string("gunName"));
	params.write_u8(this.get_u8("TTL"));
	params.write_u8(this.get_u8("speed"));
	params.write_u16(this.get_u16("fire_rate"));
	params.write_u8(this.get_u8("shot_spread"));
	params.write_u8(this.get_u8("clip_size"));
	params.write_u16(this.get_u16("reloading_time"));
	params.write_bool(this.get_bool("shotgun"));
	params.write_u8(this.get_u8("b_count"));
	params.write_string(this.get_string("fire_sound"));
	params.write_u8(this.get_u8("sounds_random_length"));
	params.write_string(this.get_string("reload_sound"));
	params.write_bool(this.get_bool("no_smoke"));
	params.write_string(this.get_string("gun_icon"));
	params.write_string(this.get_string("gun_menu_name"));
	params.write_string(this.get_string("gun_desc"));
	params.write_f32(this.get_f32("human_damage_mod"));
	this.SendCommand(this.getCommandID("SyncGun"), params);
}