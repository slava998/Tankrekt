//Gingerbeard @ 12/20/2023
//Converts a block to the player's team after some attached

#include "ShipsCommon.as";

const u8 checkFrequency = 15;
const u8 checkFrequencyIdle = 60;

void onInit(CBlob@ this)
{
	this.getCurrentScript().tickFrequency = checkFrequencyIdle;
	this.set_u8("capture time", 10);
	this.set_u8("convertTime", this.get_u8("capture time"));
	this.set_u8("convertTeam", this.getTeamNum());
}

void onTick(CBlob@ this)
{
	if (!isServer()) return;
	
	const int color = this.getShape().getVars().customData;
	if (color <= 0) return;
	
	Ship@ ship = getShipSet().getShip(color);
	if (ship is null) return;
	
	u8 convertTime = this.get_u8("convertTime");
	u8 convertTeam = this.get_u8("convertTeam");
	
	const u8 capture_time = this.get_u8("capture time"); //time it takes to capture
	const u8 thisTeamNum = this.getTeamNum();
	
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null && occupier.getTeamNum() != thisTeamNum &&
		!ship.isMothership && !ship.isStation)
	{
		//start counting upwards
		convertTime = Maths::Max(0, convertTime - 1);
		convertTeam = occupier.getTeamNum();
		this.getCurrentScript().tickFrequency = checkFrequency;
		
		if (convertTime <= 0)
		{
			//capture!
			server_setShipTeam(ship, convertTeam);
		
			convertTime = capture_time;
			this.getCurrentScript().tickFrequency = checkFrequencyIdle;
		}
	}
	else if (convertTime < capture_time)
	{
		//start counting backwards
		convertTime++;
		this.getCurrentScript().tickFrequency = checkFrequency;
	}
	else if (convertTime >= capture_time)
	{
		//reset
		this.getCurrentScript().tickFrequency = checkFrequencyIdle;
		convertTeam = thisTeamNum;
	}
	
	if (convertTeam != this.get_u8("convertTeam"))
	{
		//sync convertTeam for use in onRender
		this.set_u8("convertTeam", convertTeam);
		this.Sync("convertTeam", true); //-1380000415 HASH
	}
	
	if (convertTime != this.get_u8("convertTime"))
	{
		//sync convertTime for use in onRender
		this.set_u8("convertTime", convertTime);
		this.Sync("convertTime", true); //-1321747407 HASH
	}
}

/*void onChangeTeam(CBlob@ this, const int oldTeam)
{
	if (this.get_u8("convertTime") == 1)
		Sound::Play("snes_coin.ogg", this.getPosition());
}*/
