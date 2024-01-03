#include "CinematicCommon.as"
#include "MapVotesCommon.as"
#include "ShipsCommon.as"

#define CLIENT_ONLY

const bool FOCUS_ON_IMPORTANT_BLOBS = true;						//whether camera should focus on important blobs

const float CINEMATIC_PAN_X_EASE = 6.0f;						//amount of ease along the x-axis while cinematic
const float CINEMATIC_PAN_Y_EASE = 6.0f;						//amount of ease along the y-axis while cinematic

const float CINEMATIC_ZOOM_EASE = 16.0f;						//amount of ease when zooming while cinematic
const float CINEMATIC_CLOSEST_ZOOM = 1.0f;						//how close the camera can zoom in while cinematic (default is 2.0f)
const float CINEMATIC_FURTHEST_ZOOM = 0.5f;						//how far the camera can zoom out while cinematic (default is 0.5f)

const float AUTO_CINEMATIC_TIME = 3.0f;							//time until camera automatically becomes cinematic. set to zero to disable

Vec2f posActual;
Vec2f posTarget;												//position which cinematic camera moves towards
float zoomTarget = 1.0f;										//zoom level which camera zooms towards
float timeToScroll = 0.0f;										//time until next able to scroll to zoom camera
float timeToCinematic = 0.0f;									//time until camera automatically becomes cinematic
float panEaseModifier = 1.0f;                                   //by how much the x/y ease values are multiplied
float zoomEaseModifier = 1.0f;                                  //by how much the zoom ease values are multiplied
uint currentTarget;											    //the current target blob
uint switchTarget;												//time when camera can move onto new target

string _targetPlayer;
s32 _shipID;
bool waitForRelease = false;

CPlayer@ targetPlayer()
{
	return getPlayerByUsername(_targetPlayer);
}

const Vec2f[] easePosLerpTable = {
	Vec2f(0.0,   1.0),
	Vec2f(8.0,   1.0),
	Vec2f(16.0,  0.8),
	Vec2f(64.0,  0.6),
	Vec2f(96.0,  0.8),
	Vec2f(128.0, 1.0),
};

float ease(float current, float target, float factor)
{
	const float diff = target - current;
	const float linearCorrection = diff * factor * panEaseModifier;

	const float x = Maths::Abs(diff);

	float cubicCorrectionMod = 1.0;
	for (int i = 1; i < easePosLerpTable.size(); ++i)
	{
		Vec2f a = easePosLerpTable[i-1];
		Vec2f b = easePosLerpTable[i];
		if (x >= a.x && x < b.x)
		{
			const float f = (x - a.x) / (b.x - a.x);
			cubicCorrectionMod = Maths::Lerp(a.y, b.y, f);
			break;
		}
	}

	const float finalCorrection = linearCorrection * cubicCorrectionMod;

	return current + linearCorrection * cubicCorrectionMod;
}

void SetTargetPlayer(CPlayer@ p)
{
	_shipID = 0;
	_targetPlayer = "";
	if (p is null) return;
	_targetPlayer = p.getUsername();
}

void Spectator(CRules@ this)
{	
	CCamera@ camera = getCamera();
	CControls@ controls = getControls();
	CMap@ map = getMap();

	if (camera is null || controls is null || map is null)
	{
		return;
	}

	//variables
	const Vec2f dim = map.getMapDimensions();
	float camSpeed = getRenderApproximateCorrectionFactor() * 15.0f / zoomTarget;

    if (this.get_bool("set new target"))
    {
        string newTarget = this.get_string("new target");
        _targetPlayer = newTarget;
        if (targetPlayer() !is null)
        {
            waitForRelease = true;
            this.set_bool("set new target", false);
        }
    }

	//scroll to zoom
	if (timeToScroll <= 0)
	{
		if (controls.mouseScrollUp)
		{
			timeToScroll = 7;
			setCinematicEnabled(false);

			if (zoomTarget <= 0.2f)
				zoomTarget = 0.5f;
			else if (zoomTarget <= 0.5f)
				zoomTarget = 1.0f;
			else if (zoomTarget <= 1.0f)
				zoomTarget = 2.0f;
		}
		else if (controls.mouseScrollDown)
		{
			timeToScroll = 7;
			setCinematicEnabled(false);
			
			CPlayer@ localPlayer = getLocalPlayer();
			const bool isSpectator = localPlayer !is null ? localPlayer.getTeamNum() == this.getSpectatorTeamNum() : false;
			const bool allowMegaZoom = isSpectator && dim.x > 900 && camera.getTarget() is null; //map must be large enough, player has to be spectator team

			if (zoomTarget >= 2.0f)
				zoomTarget = 1.0f;
			else if (zoomTarget >= 1.0f)
				zoomTarget = 0.5f;
			else if (zoomTarget >= 0.5f && allowMegaZoom)
				zoomTarget = 0.2f;
		}
	}
	else
	{
		timeToScroll -= getRenderApproximateCorrectionFactor();
	}

	//move camera using action movement keys
	if (controls.ActionKeyPressed(AK_MOVE_LEFT))
	{
		posActual.x -= camSpeed;
		SetTargetPlayer(null);
		setCinematicEnabled(false);
	}
	if (controls.ActionKeyPressed(AK_MOVE_RIGHT))
	{
		posActual.x += camSpeed;
		SetTargetPlayer(null);
		setCinematicEnabled(false);
	}
	if (controls.ActionKeyPressed(AK_MOVE_UP))
	{
		posActual.y -= camSpeed;
		SetTargetPlayer(null);
		setCinematicEnabled(false);
	}
	if (controls.ActionKeyPressed(AK_MOVE_DOWN))
	{
		posActual.y += camSpeed;
		SetTargetPlayer(null);
		setCinematicEnabled(false);
	}

    if (controls.isKeyJustReleased(KEY_LBUTTON))
    {
        waitForRelease = false;
    }

	if (!isCinematicEnabled() || targetPlayer() !is null) //player-controlled zoom
	{
		if (Maths::Abs(camera.targetDistance - zoomTarget) > 0.001f)
		{
			camera.targetDistance = (camera.targetDistance * (3.0f - getRenderApproximateCorrectionFactor() + 1.0f) + (zoomTarget * getRenderApproximateCorrectionFactor())) / 4.0f;
		}
		else
		{
			camera.targetDistance = zoomTarget;
		}

		if (AUTO_CINEMATIC_TIME > 0)
		{
			timeToCinematic -= getRenderSmoothDeltaTime();
			if (timeToCinematic <= 0)
			{
				setCinematicEnabled(true);
			}
		}
	}
	else //cinematic camera
	{
		const float corrFactor = getRenderApproximateCorrectionFactor();
		camera.targetDistance += (zoomTarget - camera.targetDistance) / CINEMATIC_ZOOM_EASE * corrFactor * zoomEaseModifier;

		posActual.x = ease(posActual.x, posTarget.x, corrFactor / CINEMATIC_PAN_X_EASE);
		posActual.y = ease(posActual.y, posTarget.y, corrFactor / CINEMATIC_PAN_Y_EASE);
	}

	//click on players to track them or set camera to mousePos
	Vec2f mousePos = controls.getMouseWorldPos();
	if (controls.isKeyJustPressed(KEY_LBUTTON) && !waitForRelease)
	{
		bool foundTarget = false;
		SetTargetPlayer(null);

		CBlob@[] candidates;
		map.getBlobsInRadius(controls.getMouseWorldPos(), 10.0f, @candidates);

		const u16 playersLength = candidates.length;
		for (u16 i = 0; i < playersLength; i++) //search for a player to target
		{
			CBlob@ blob = candidates[i];
			if (!blob.hasTag("player")) continue;
			
			SetTargetPlayer(blob.getPlayer());
			camera.setTarget(blob);
			camera.setPosition(blob.getInterpolatedPosition());
			foundTarget = true;
			break;
		}

		if (!foundTarget) //didn't find a player? search for a ship to target
		{
			ShipDictionary@ ShipSet = getShipSet(this);
			for (u16 i = 0; i < playersLength; i++)
			{
				CBlob@ blob = candidates[i];
				if (!blob.hasTag("block") || camera.getTarget() is blob) continue;
				
				const int bCol = blob.getShape().getVars().customData;
				if (bCol <= 0) continue;

				Ship@ ship = ShipSet.getShip(bCol);
				if (ship is null || ship.centerBlock is null) continue;

				_shipID = bCol;
				camera.setTarget(ship.centerBlock);
				camera.setPosition(ship.centerBlock.getInterpolatedPosition());
				foundTarget = true;
				break;
			}
		}

		if (foundTarget)
		{
			if (zoomTarget >= 0.2f)
				zoomTarget = 0.5f;

			waitForRelease = true;
			setCinematicEnabled(false);
		}
	}
	else if (!waitForRelease && controls.isKeyPressed(KEY_LBUTTON) && camera.getTarget() is null) //classic-like held mouse moving
	{
		// HACK: this is terrible and we need proper GUI and cursor capture shit
		// ofc this is still an issue with the queue stuff now :upside_down:
		MapVotesMenu@ mvm = null;
		this.get("MapVotesMenu", @mvm);

		if (mvm is null || !isMapVoteActive() || !mvm.screenPositionOverlaps(controls.getMouseScreenPos()))
        {
		    posActual += (mousePos - posActual) / 8.0f * getRenderApproximateCorrectionFactor();
            setCinematicEnabled(false);
        }
	}

	if (targetPlayer() !is null)
	{
		if (camera.getTarget() !is targetPlayer().getBlob())
		{
			camera.setTarget(targetPlayer().getBlob());
		}
		posActual = camera.getPosition();
	}
	else if (_shipID > 0)
	{
		Ship@ ship = getShipSet(this).getShip(_shipID);
		if (ship !is null && ship.centerBlock !is null)
		{
			camera.setTarget(ship.centerBlock);
			posActual = camera.getPosition();
		}
		else
			_shipID = 0;
	}
	else
		camera.setTarget(null);

	//set specific zoom if we have a target
	if (camera.getTarget() !is null)
	{
		camera.mousecamstyle = 1;
		camera.mouseFactor = 0.5f;
		return;
	}

	//keep camera within map boundaries
	const f32 borderMarginX = map.tilesize * (zoomTarget == 0.2f ? 15 : 2) / zoomTarget;
	const f32 borderMarginY = map.tilesize * (zoomTarget == 0.2f ? 5 : 2) / zoomTarget;
	posActual.x = Maths::Clamp(posActual.x, borderMarginX, dim.x - borderMarginX);
	posActual.y = Maths::Clamp(posActual.y, borderMarginY, dim.y - borderMarginY);

	//set camera position
	camera.setPosition(posActual);
}
