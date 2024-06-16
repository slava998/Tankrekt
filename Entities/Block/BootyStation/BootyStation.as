// Station
#include "ShipsCommon.as";

void onInit(CBlob@ this)
{
	this.Tag("booty_station");
	this.Tag("station");
	this.Tag("noRenderHealth");
	this.set_u8("capture time", 25);

}

void onInit(CSprite@ this)
{
	CSpriteLayer@ layer = this.addSpriteLayer("station", "BootyStation.png", 16, 16);
	if (layer !is null)
	{
		layer.SetRelativeZ(1);
		layer.SetFrame(0);
	}
	CSpriteLayer@ upper = this.addSpriteLayer("upper", "BootyStationUpper.png", 6, 6);
	if (upper !is null)
	{
		upper.SetRelativeZ(3);
		upper.SetFrame(0);
	}
	CSpriteLayer@ gear = this.addSpriteLayer("gear", "BootyStationDrill.png" , 16, 16);
	if (gear !is null)
	{
		gear.SetRelativeZ(2);
	}
	this.SetEmitSound("Grinder_Loop.ogg");
	this.SetEmitSoundPaused(true);
	this.SetEmitSoundVolume(0.15f);
	
}

void onTick(CSprite@ this)
{
	if (!isClient()) return;
	if(this.getBlob().getTeamNum() < 2) //do not rotate if not captured
	{
		if(this.getSpriteLayer("gear") !is null)
			this.getSpriteLayer("gear").RotateBy((5.0f), Vec2f(0.0f,0.0f));
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
	print((this.getTeamNum() >= 2) + "");
	this.getSprite().SetEmitSoundPaused(this.getTeamNum() >= 2);
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	return 0.0f;
}
