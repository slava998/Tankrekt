#include "MapVotesCommon.as"
#include "ShipsCommon.as"

#define CLIENT_ONLY

f32 zoomTarget = 1.0f;
float timeToScroll = 0.0f;

bool justClicked = false;
string _targetPlayer;
s32 _shipID;
bool waitForRelease = false;

CPlayer@ targetPlayer()
{
	return getPlayerByUsername(_targetPlayer);
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

	const Vec2f dim = map.getMapDimensions();
	f32 camSpeed = getRenderApproximateCorrectionFactor() * 15.0f / zoomTarget;

	//Zoom in and out using mouse wheel
	if (timeToScroll <= 0)
	{
		if (controls.mouseScrollUp)
		{
			timeToScroll = 7;

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
			const bool isSpectator = getLocalPlayer().getTeamNum() == this.getSpectatorTeamNum();
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
	
	if (this.get_bool("set new target"))
    {
        string newTarget = this.get_string("new target");
        _targetPlayer = newTarget;
        if (targetPlayer() !is null)
        {
			if (zoomTarget >= 0.2f)
				zoomTarget = 0.5f; //keep zoom within bounds
            waitForRelease = true;
            this.set_bool("set new target", false);
        }
    }

	Vec2f pos = camera.getPosition();

	//Move the camera using the action movement keys
	if (controls.ActionKeyPressed(AK_MOVE_LEFT))
	{
		pos.x -= camSpeed;
		SetTargetPlayer(null);
	}
	if (controls.ActionKeyPressed(AK_MOVE_RIGHT))
	{
		pos.x += camSpeed;
		SetTargetPlayer(null);
	}
	if (controls.ActionKeyPressed(AK_MOVE_UP))
	{
		pos.y -= camSpeed;
		SetTargetPlayer(null);
	}
	if (controls.ActionKeyPressed(AK_MOVE_DOWN))
	{
		pos.y += camSpeed;
		SetTargetPlayer(null);
	}

    if (controls.isKeyJustReleased(KEY_LBUTTON))
    {
        waitForRelease = false;
    }

	//Click on players to track them or set camera to mousePos
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
				zoomTarget = 0.5f; //keep zoom within bounds
		}
	}
	else if (!waitForRelease && controls.isKeyPressed(KEY_LBUTTON) && camera.getTarget() is null && !u_showtutorial) //classic-like held mouse moving
	{
		// HACK: this is terrible and we need proper GUI and cursor capture shit
		// ofc this is still an issue with the queue stuff now :upside_down:
		MapVotesMenu@ mvm = null;
		this.get("MapVotesMenu", @mvm);

		if (mvm is null || !isMapVoteActive() || !mvm.screenPositionOverlaps(controls.getMouseScreenPos()))
        {
		    pos += (mousePos - pos) / 8.0f * getRenderApproximateCorrectionFactor();
        }
	}

	if (targetPlayer() !is null)
	{
		if (camera.getTarget() !is targetPlayer().getBlob())
		{
			camera.setTarget(targetPlayer().getBlob());
		}
	}
	else if (_shipID > 0)
	{
		Ship@ ship = getShipSet(this).getShip(_shipID);
		if (ship !is null && ship.centerBlock !is null)
		{
			camera.setTarget(ship.centerBlock);
		}
		else
			_shipID = 0;
	}
	else
	{
		camera.setTarget(null);
	}
	
	if (Maths::Abs(camera.targetDistance - zoomTarget) > 0.001f)
	{
		camera.targetDistance = (camera.targetDistance * (3 - getRenderApproximateCorrectionFactor() + 1.0f) + (zoomTarget * getRenderApproximateCorrectionFactor())) / 4.0f;
	}
	else
	{
		camera.targetDistance = zoomTarget;
	}

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
	pos.x = Maths::Clamp(pos.x, borderMarginX, dim.x - borderMarginX);
	pos.y = Maths::Clamp(pos.y, borderMarginY, dim.y - borderMarginY);

	camera.setPosition(pos);
}
