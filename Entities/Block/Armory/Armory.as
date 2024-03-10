#include "ShiprektTranslation.as";

void onInit(CBlob@ this)
{
	this.addCommandID("selectGun");
	this.set_u8("seat icon", 1);
	
	this.set_f32("weight", 3.5f);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if(caller is null || this is null) return;

	if (this.getDistanceTo(caller) > 6
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum())
		return;
	
	CBitStream params;
	params.write_u16(caller.getNetworkID());
	
	CButton@ button = caller.CreateGenericButton(this.get_u8("seat icon"), Vec2f_zero, this, BuildShopMenu, "Set Item");

	if (button !is null)
	{
		button.radius = 8.0f;
		button.enableRadius = 12.0f;
	}
}

void BuildShopMenu(CBlob@ this, CBlob@ caller)
{
	CGridMenu@ menu = CreateGridMenu(this.getScreenPos(), this, Vec2f(8, 2), "Select Gun");
	if (menu is null) return;
	
	const bool warmup = getRules().isWarmup();
	menu.deleteAfterClick = true;
	
	AddOption(this, caller, menu, "rifle", "$RIFLE$", Trans::Rifle, Trans::RifleDesc);
	
	AddOption(this, caller, menu, "smg", "$SMG$", Trans::SMG, Trans::SMGDesc);
	
	AddOption(this, caller, menu, "shotgun", "$SHOTGUN$", Trans::Shotgun, Trans::ShotgunDesc);
	
	AddOption(this, caller, menu, "rpg", "$RPG$", Trans::RPG, Trans::RPGDesc);
	
	//AddOption(this, caller, menu, "carbine", "$CARBINE$", Trans::Carbine, Trans::CarbineDesc);
}

CGridButton@ AddOption(CBlob@ this, CBlob@ caller, CGridMenu@ menu, const string&in weapon, const string&in icon, const string&in bname, const string&in desc)
{
	//const u16 cost = getCost(block);
	
	CBitStream params;
	params.write_netid(caller.getNetworkID());
	params.write_string(weapon);
	//params.write_u16(cost);
	
	CGridButton@ button = menu.AddButton(icon, bname, this.getCommandID("selectGun"), params);
	
	button.SetHoverText(desc);
	return button;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if(cmd == this.getCommandID("selectGun"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		if(caller is null || this is null) return;

		if(isServer())
		{
			const string newGun = params.read_string();
			caller.set_string("gunName", newGun);
			caller.SendCommand(caller.getCommandID("updateGun"));
		}
	}
}