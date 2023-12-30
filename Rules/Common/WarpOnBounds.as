#include "ShipsCommon.as";

void onTick(CRules@ this)
{
	/*if (getGameTime() % 200 > 0) return;
	
	Vec2f dim = getMap().getMapDimensions();
	
	ShipDictionary@ ShipSet = getShipSet(this);
	Ship@[] ships = ShipSet.getShips();
	
	const u16 shipsLength = ships.length;
	for (u16 i = 0; i < shipsLength; ++i)
	{
		Ship@ ship = ships[i];
		if (ship is null) continue;
		
		if (ship.pos.y <= 0.0f) ship.pos.Set(ship.pos.x, 20.0f); //top border
		else if (dim.y <= ship.pos.y) ship.pos.Set(ship.pos.x, dim.y - 20.0f); //bottom border
		else if (dim.x <= ship.pos.x) ship.pos.Set(dim.x - 20.0f, ship.pos.y); //right border
		else if (ship.pos.x <= 0.0f) ship.pos.Set(20.0f, ship.pos.y); //left border
	}*/
	
	//warp ships to other border
	/*
	
	for (u16 i = 0; i < shipsLength; ++i)
	{
		Ship@ ship = ships[i];
		if (ship is null) continue;
		
		if (ship.vel.x > 0.0f && ship.pos.x > dim.x)
		{
			ship.old_pos.x = ship.pos.x;
			ship.old_pos.x -= ship.vel.x;
			ship.pos.x -= dim.x;			
		}
		if (ship.vel.y > 0.0f && ship.pos.y > dim.y)
		{
			ship.old_pos.y = ship.pos.y;
			ship.old_pos.y -= ship.vel.y;
			ship.pos.y -= dim.y;
		}
		if (ship.vel.x < 0.0f && ship.pos.x < 0)
		{
			ship.old_pos.x = ship.pos.x;
			ship.old_pos.x -= ship.vel.x;
			ship.pos.x += dim.x;
		}
		if (ship.vel.y < 0.0f && ship.pos.y < 0)
		{
			ship.old_pos.y = ship.pos.y;
			ship.old_pos.y -= ship.vel.y;
			ship.pos.y += dim.y;
		}
	}*/
}
