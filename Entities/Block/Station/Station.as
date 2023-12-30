// Station
#include "ShipsCommon.as";

void onInit(CBlob@ this)
{
	this.Tag("station");
	this.Tag("noRenderHealth");
	this.set_u8("capture time", 25);
	
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.addSpriteLayer("station", "Station.png", 16, 16);
	if (layer !is null)
	{
		layer.SetRelativeZ(1);
		layer.SetFrame(0);
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
