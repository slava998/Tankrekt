// Station
#include "ShipsCommon.as";
#include "SpawnPointIDs.as"
#include "ShiprektTranslation.as";

void onInit(CBlob@ this)
{
	this.Tag("station");
	this.Tag("build_station");
	this.Tag("noRenderHealth");
	this.Tag("spawnPoint");
	this.set_u8("capture time", 25);
	this.set_u8("seat icon", 7);
	this.addCommandID("SetSpawn");
	this.addCommandID("ResetSpawn");
	
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.addSpriteLayer("station", "Station.png", 16, 16);
	if (layer !is null)
	{
		layer.SetRelativeZ(1);
		layer.SetFrame(0);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > 8
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum())
		return;

	CBitStream params;
	params.write_netid(caller.getNetworkID());
	CButton@ button = caller.CreateGenericButton(this.get_u8("seat icon"), Vec2f_zero, this, MakeMenu, "");
	if (button !is null)
	{
		button.radius = 10.0f;
		button.enableRadius = 14.0f;
	}
}

// Open the tools menu
void MakeMenu(CBlob@ this, CBlob@ caller)
{
	CGridMenu@ menu = CreateGridMenu(this.getScreenPos(), this, Vec2f(4,2), "");
	if (menu is null) return;
	
	CBitStream params;
	params.write_netid(caller.getNetworkID());
	
	menu.deleteAfterClick = true;
	
	{ //Set Spawn
		CGridButton@ button = menu.AddButton("$HERE$", Trans::SetSpawn, this.getCommandID("SetSpawn"), params);
		button.SetHoverText(Trans::SetSpawn);
	}
	{ //Reset Spawn
		CGridButton@ button = menu.AddButton("$CROSS$", Trans::ResetSpawn, this.getCommandID("ResetSpawn"), params);
		button.SetHoverText(Trans::ResetSpawn);
	}
}

void onChangeTeam(CBlob@ this, const int oldTeam)
{
	CPlayer@ ourply = getLocalPlayer();
	if (ourply !is null)
	{
		if (this.getTeamNum() == ourply.getTeamNum())
		{
			Sound::Play("Captured.ogg");
		}
		else
		{
			Sound::Play("Captured2.ogg");
		}
	}
	
	Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
	if (ship !is null && !ship.isMothership)
		server_setShipTeam(ship, this.getTeamNum());
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	return 0.0f;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("SetSpawn"))
    {
		if(!isServer()) return;

		if(this is null) return;

		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		if(caller is null) return;

		CPlayer@ player = caller.getPlayer();
		if(player is null) return;

		server_setSpawnPoint(player.getUsername(), this.getNetworkID());
	}
	if (cmd == this.getCommandID("ResetSpawn"))
    {
		if(!isServer()) return;

		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		if(caller is null) return;

		CPlayer@ player = caller.getPlayer();
		if(player is null) return;
		
		const u32 mothershipID = getMothership(player.getTeamNum()).getNetworkID();
		print("" + mothershipID);
		server_setSpawnPoint(player.getUsername(), mothershipID);
	}
}