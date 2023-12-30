//Tile Common
#include "CustomTiles.as";

shared bool isTouchingLand(const Vec2f&in pos)
{
	CMap@ map = getMap();
	const u16 tileType = map.getTile(pos).type;

	return ((tileType >= CMap::sand_inland && tileType <= CMap::grass_sand_border_diagonal_L1)
			||	((tileType >= CMap::sand_shoal_border_convex_RU1 && tileType <= CMap::sand_shoal_border_diagonal_L1)&&(tileType)%2 == 0));
}

shared bool isTouchingRock(const Vec2f&in pos)
{
	CMap@ map = getMap();
	const u16 tileType = map.getTile(pos).type;

	return tileType >= CMap::rock_inland && tileType <= CMap::rock_shoal_border_diagonal_L1;
}

shared bool isTouchingShoal(const Vec2f&in pos)
{
	CMap@ map = getMap();
	const u16 tileType = map.getTile(pos).type;

	return tileType >= CMap::shoal_inland && tileType <= CMap::shoal_shore_diagonal_L1;
}

shared bool isInWater(const Vec2f&in pos)
{
	CMap@ map = getMap();
	const u16 tileType = map.getTile(pos).type;

	return tileType == 0 || (tileType >= CMap::shoal_inland && tileType <= CMap::shoal_shore_diagonal_L1);
}