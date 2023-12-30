//#define CLIENT_ONLY
#include "ShipsCommon.as";
#include "TileCommon.as";

shared class WalkInfo
{
	s32 shipID;
	f32 shipOldAngle;
	Vec2f shipOldPos;
	
	WalkInfo()
	{
		shipID = 0;
		shipOldAngle = 0;
		shipOldPos = Vec2f_zero;
	}
};

void onInit(CBlob@ this)
{
	WalkInfo walk;
	this.set("WalkInfo", @walk);

	this.getShape().getConsts().net_threshold_multiplier = -1.0f; //stop engine shape sync, because we do our own superior synchronization.

	this.addCommandID("sync player");
}

void onTick(CBlob@ this)
{	
	WalkInfo@ walk;
	if (!this.get("WalkInfo", @walk)) return;
	
	bool ship_server_sync = false;
	Vec2f pos = this.getPosition();
	const s32 overlappingShipID = this.get_s32("shipID");
	if (this.get_bool("onGround"))
	{
		Ship@ ship = overlappingShipID > 0 ? getShipSet().getShip(overlappingShipID) : null;
		if (ship !is null)
		{
			if (ship.id != walk.shipID || !this.wasOnGround()) //ship changed: change cached values to current
			{
				ship_server_sync = true; //sync client's position to server to avoid desync
				walk.shipID = ship.id;
				walk.shipOldAngle = ship.angle;
				walk.shipOldPos = ship.origin_pos;
			}

			const Vec2f shipDisplacement = ship.origin_pos - walk.shipOldPos;
			const f32 shipAngleDelta = ship.angle - walk.shipOldAngle;
			Vec2f shipToBlob = pos - ship.origin_pos + shipDisplacement;
			shipToBlob.RotateBy(shipAngleDelta);

			walk.shipOldPos = ship.origin_pos;
			walk.shipOldAngle = ship.angle;

			CBlob@ shipBlock = getMap().getBlobAtPosition(ship.origin_pos + shipToBlob);
			if (isTouchingLand(pos) ? shipBlock !is null : true) //only move player if there is a block to move onto
				this.setPosition(ship.origin_pos + shipToBlob);

			pos = shipToBlob;
			pos.RotateBy(-ship.angle);
		}
	}
	
	if (this.isMyPlayer())
	{
		CBitStream params;
		params.write_f32(getCamera().getRotation());
		params.write_s32(overlappingShipID);
		params.write_bool(ship_server_sync);
		params.write_Vec2f(pos);
		this.SendCommand(this.getCommandID("sync player"), params);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (this.getCommandID("sync player") != cmd) return;
	
	//sync camera rotation to other clients and server
	const f32 camRotation = params.read_f32();
	this.set_f32("camera rotation", camRotation);

	if (this.isMyPlayer()) return; //our client has already calculated our position

	//sync pos to other clients (and server when off ship/when necessary)
	const s32 overlappingShipID = params.read_s32();
	const bool ship_server_sync = params.read_bool();
	Vec2f offset = params.read_Vec2f();
	if (overlappingShipID > 0)
	{
		Ship@ ship = getShipSet().getShip(overlappingShipID);
		if (ship is null || (isServer() && !ship_server_sync)) return;

		offset.RotateBy(ship.angle);
		offset += ship.origin_pos;
	}

	this.setPosition(offset);
}
