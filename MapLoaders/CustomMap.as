Random map_random(1569815698);

#include "LoadMapUtils.as";
#include "CustomTiles.as";

namespace CMap
{
	// tiles
	const SColor 
	color_water(255, 77, 133, 188),
	color_sand(255, 236, 213, 144),
	color_grass(255, 100, 155, 13),
	color_rock(255, 161, 161, 161),
	color_shoal(255, 100, 170, 180);
	
	// objects
	enum color
	{
		color_main_spawn = 0xff00ffff,
		color_station = 0xffff0000,
		color_palmtree = 0xff009600
	};
	
	//
	void SetupMap(CMap@ map, int width, int height)
	{
		map.CreateTileMap(width, height, 8.0f, "LandTiles.png");
		SetScreenFlash(255, 0, 0, 0, 0.5f); // has to be done on this when map is loading, it will be synced in engine to new joined people.
		#ifndef STAGING
			map.CreateSky(SColor(255, 41, 100, 176)); //water color
		#endif
		map.topBorder = map.bottomBorder = map.rightBorder = map.leftBorder = true;
	}
	
	SColor
	pixel_R = color_water,
	pixel_RU = color_water,
	pixel_U = color_water,
	pixel_LU = color_water,
	pixel_L = color_water,
	pixel_LD = color_water,
	pixel_D = color_water,
	pixel_RD = color_water;

	//
	void handlePixel(CMap@ map, CFileImage@ image, SColor&in pixel, const int&in offset, Vec2f&in pixelPos)
	{	
		if (pixel == color_water)
			return;
		
		// ** NON-TILES **
		
		switch (pixel.color)
		{
			case color_main_spawn:
			{
				AddMarker(map, offset, "spawn");
				return;
			}
			case color_station:
			{
				CBlob@ stationBlob = spawnBlob(map, "station", offset, 255, false);	
				stationBlob.getSprite().SetFrame(0);
				
				map.SetTile(offset, CMap::sand_inland);	
				map.AddTileFlag(offset, Tile::BACKGROUND);
				map.AddTileFlag(offset, Tile::LIGHT_PASSES);
				return;
			}
			case color_palmtree:
			{
				CBlob@ palmtreeBlob = spawnBlob(map, "palmtree", offset, 255, false);	
			
				map.SetTile(offset, CMap::grass_inland + map_random.NextRanged(5));
				map.AddTileFlag(offset, Tile::BACKGROUND);
				map.AddTileFlag(offset, Tile::LIGHT_PASSES);
				return;
			}
		}
		
		// ** TILES **
		
		//declare nearby pixels
		if (image !is null && image.isLoaded() && image.canRead())
		{
			image.setPixelPosition(pixelPos + Vec2f(1, 0));
			pixel_R = image.readPixel();
			
			if (image.getPixelPosition().y > 0)
			{
				image.setPixelPosition(pixelPos + Vec2f(1, -1));
				pixel_RU = image.readPixel();

				image.setPixelPosition(pixelPos + Vec2f(0, -1));
				pixel_U = image.readPixel();
				
				image.setPixelPosition(pixelPos + Vec2f(-1, -1));
				pixel_LU = image.readPixel();
			}
			
			image.setPixelPosition(pixelPos + Vec2f(-1, 0));
			pixel_L = image.readPixel();
			
			image.setPixelPosition(pixelPos + Vec2f(-1, 1));
			pixel_LD = image.readPixel();
			
			image.setPixelPosition(pixelPos + Vec2f(0, 1));
			pixel_D = image.readPixel();
			
			image.setPixelPosition(pixelPos + Vec2f(1, 1));
			pixel_RD = image.readPixel();
				
			image.setPixelOffset(offset);
		}
		
		//calculate bools prior
		
		const bool
		U_Shoal = pixel_U == color_shoal,
		R_Shoal = pixel_R == color_shoal,
		L_Shoal = pixel_L == color_shoal,
		D_Shoal = pixel_D == color_shoal,
		RU_Shoal = pixel_RU == color_shoal,
		RD_Shoal = pixel_RD == color_shoal,
		LU_Shoal = pixel_LU == color_shoal,
		LD_Shoal = pixel_LD == color_shoal,
		
		U_Sand = pixel_U == color_sand,
		R_Sand = pixel_R == color_sand,
		L_Sand = pixel_L == color_sand,
		D_Sand = pixel_D == color_sand,
		RU_Sand = pixel_RU == color_sand,
		RD_Sand = pixel_RD == color_sand,
		LU_Sand = pixel_LU == color_sand,
		LD_Sand = pixel_LD == color_sand,
		
		U_Water = pixel_U == color_water,
		R_Water = pixel_R == color_water,
		L_Water = pixel_L == color_water,
		D_Water = pixel_D == color_water,
		RU_Water = pixel_RU == color_water,
		RD_Water = pixel_RD == color_water,
		LU_Water = pixel_LU == color_water,
		LD_Water = pixel_LD == color_water;
		
		
		if (pixel == color_sand) 
		{
			//SAND AND SHOAL BORDERS
			//completely surrounded island
			if (R_Shoal && U_Shoal && L_Shoal && D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_island1);
				
			//four way crossing
			else if (RU_Shoal && LU_Shoal && LD_Shoal && RD_Shoal
						&& !R_Shoal && !U_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_cross1);		
		
			//peninsula shorelines
			else if (R_Shoal && U_Shoal && D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_peninsula_R1);
			else if (R_Shoal && U_Shoal && L_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_peninsula_U1);
			else if (U_Shoal && L_Shoal && D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_peninsula_L1);
			else if (L_Shoal && D_Shoal && R_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_peninsula_D1);
				
			//three way T crossings
			else if (R_Shoal && LU_Shoal && LD_Shoal
						&& !U_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_T_R1);
			else if (U_Shoal && RD_Shoal && LD_Shoal
						&& !R_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_T_U1);
			else if (RU_Shoal && L_Shoal && RD_Shoal
						&& !R_Shoal && !U_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_T_L1);
			else if (RU_Shoal && LU_Shoal && D_Shoal
						&& !R_Shoal && !U_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_T_D1);
				
			//left handed panhandle
			else if (R_Shoal && LU_Shoal
						&& !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleL_R1);
			else if (U_Shoal && LD_Shoal 
						&& !R_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleL_U1);
			else if (L_Shoal && RD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleL_L1);
			else if (RU_Shoal && D_Shoal
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Shoal && LD_Shoal 
						&& !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleR_R1);
			else if (U_Shoal && RD_Shoal
						&& !R_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleR_U1);
			else if (RU_Shoal && L_Shoal
						&& !R_Shoal && !U_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleR_L1);
			else if (LU_Shoal && D_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_panhandleR_D1);
				
			//splitting strips
			else if (RU_Shoal && LU_Shoal && RD_Shoal
						&& !R_Shoal && !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_split_RU1);
			else if (RU_Shoal && LU_Shoal && LD_Shoal 
						&& !R_Shoal && !U_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_split_LU1);
			else if (LU_Shoal && LD_Shoal && RD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_split_LD1);
			else if (RU_Shoal && LD_Shoal && RD_Shoal 
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_split_RD1);
				
			//choke points
			else if (RU_Shoal && RD_Shoal 
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_choke_R1);
			else if (RU_Shoal && LU_Shoal 
						&& !R_Shoal && !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_choke_U1);
			else if (LU_Shoal && LD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_choke_L1);
			else if (LD_Shoal && RD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_choke_D1);
				
			//strip shorelines
			else if (U_Shoal && D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_strip_H1);
			else if (R_Shoal && L_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_strip_V1);	

			//bend shorelines
			else if (R_Shoal && RU_Shoal && U_Shoal && LD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_bend_RU1);
			else if (L_Shoal && LU_Shoal && U_Shoal && RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_bend_LU1);
			else if (L_Shoal && LD_Shoal && D_Shoal && RU_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_bend_LD1);
			else if (R_Shoal && RD_Shoal && D_Shoal && LU_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_bend_RD1);		

			//diagonal choke points
			else if (RU_Shoal && LD_Shoal
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_diagonal_R1);	
			else if (LU_Shoal && RD_Shoal
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_diagonal_L1);				

			//straight edge shorelines
			else if (R_Shoal 
						&& !U_Shoal && !LU_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_straight_R1);	
			else if (U_Shoal
						&& !R_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_straight_U1);	
			else if (L_Shoal
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_straight_L1);	
			else if (D_Shoal
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_straight_D1);	
				
			//convex shorelines
			else if (R_Shoal && U_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_convex_RU1);
			else if (L_Shoal && U_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_convex_LU1);
			else if (L_Shoal && D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_convex_LD1);
			else if (R_Shoal && D_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_convex_RD1);
				
			//concave shorelines		
			else if (RU_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_concave_RU1);	
			else if (LU_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_concave_LU1);	
			else if (LD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_concave_LD1);	
			else if (RD_Shoal)
				map.SetTile(offset, CMap::sand_shoal_border_concave_RD1);
		
			//SAND SHORES
			//completely surrounded island
			else if (R_Water && U_Water && L_Water && D_Water)
				map.SetTile(offset, CMap::sand_shore_island1);
				
			//four way crossing
			else if (RU_Water && LU_Water && LD_Water && RD_Water
						&& !R_Water && !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_cross1);		
		
			//peninsula shorelines
			else if (R_Water && U_Water && D_Water)
				map.SetTile(offset, CMap::sand_shore_peninsula_R1);
			else if (R_Water && U_Water && L_Water)
				map.SetTile(offset, CMap::sand_shore_peninsula_U1);
			else if (U_Water && L_Water && D_Water)
				map.SetTile(offset, CMap::sand_shore_peninsula_L1);
			else if (L_Water && D_Water && R_Water)
				map.SetTile(offset, CMap::sand_shore_peninsula_D1);
				
			//three way T crossings
			else if (R_Water && LU_Water && LD_Water
						&& !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_T_R1);
			else if (U_Water && RD_Water && LD_Water
						&& !R_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_T_U1);
			else if (RU_Water && L_Water && RD_Water
						&& !R_Water && !U_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_T_L1);
			else if (RU_Water && LU_Water && D_Water
						&& !R_Water && !U_Water && !L_Water)
				map.SetTile(offset, CMap::sand_shore_T_D1);
				
			//left handed panhandle
			else if (R_Water && LU_Water
						&& !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleL_R1);
			else if (U_Water && LD_Water 
						&& !R_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleL_U1);
			else if (L_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleL_L1);
			else if (RU_Water && D_Water
						&& !R_Water && !U_Water && !LU_Water && !L_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Water && LD_Water 
						&& !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleR_R1);
			else if (U_Water && RD_Water
						&& !R_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleR_U1);
			else if (RU_Water && L_Water
						&& !R_Water && !U_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleR_L1);
			else if (LU_Water && D_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water)
				map.SetTile(offset, CMap::sand_shore_panhandleR_D1);
				
			//splitting strips
			else if (RU_Water && LU_Water && RD_Water
						&& !R_Water && !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_split_RU1);
			else if (RU_Water && LU_Water && LD_Water 
						&& !R_Water && !U_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_split_LU1);
			else if (LU_Water && LD_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_split_LD1);
			else if (RU_Water && LD_Water && RD_Water 
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_split_RD1);
				
			//choke points
			else if (RU_Water && RD_Water 
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_choke_R1);
			else if (RU_Water && LU_Water 
						&& !R_Water && !U_Water && !L_Water && !LD_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_choke_U1);
			else if (LU_Water && LD_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_choke_L1);
			else if (LD_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_choke_D1);
				
			//strip shorelines
			else if (U_Water && D_Water)
				map.SetTile(offset, CMap::sand_shore_strip_H1);
			else if (R_Water && L_Water)
				map.SetTile(offset, CMap::sand_shore_strip_V1);	

			//bend shorelines
			else if (R_Water && RU_Water && U_Water && LD_Water)
				map.SetTile(offset, CMap::sand_shore_bend_RU1);
			else if (L_Water && LU_Water && U_Water && RD_Water)
				map.SetTile(offset, CMap::sand_shore_bend_LU1);
			else if (L_Water && LD_Water && D_Water && RU_Water)
				map.SetTile(offset, CMap::sand_shore_bend_LD1);
			else if (R_Water && RD_Water && D_Water && LU_Water)
				map.SetTile(offset, CMap::sand_shore_bend_RD1);		

			//diagonal choke points
			else if (RU_Water && LD_Water
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_diagonal_R1);	
			else if (LU_Water && RD_Water
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_diagonal_L1);				

			//straight edge shorelines
			else if (R_Water 
						&& !U_Water && !LU_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::sand_shore_straight_R1);	
			else if (U_Water
						&& !R_Water && !L_Water && !LD_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_straight_U1);	
			else if (L_Water
						&& !R_Water && !RU_Water && !U_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::sand_shore_straight_L1);	
			else if (D_Water
						&& !R_Water && !RU_Water && !U_Water && !LU_Water && !L_Water)
				map.SetTile(offset, CMap::sand_shore_straight_D1);	
				
			//convex shorelines
			else if (R_Water && U_Water)
				map.SetTile(offset, CMap::sand_shore_convex_RU1);
			else if (L_Water && U_Water)
				map.SetTile(offset, CMap::sand_shore_convex_LU1);
			else if (L_Water && D_Water)
				map.SetTile(offset, CMap::sand_shore_convex_LD1);
			else if (R_Water && D_Water)
				map.SetTile(offset, CMap::sand_shore_convex_RD1);
				
			//concave shorelines		
			else if (RU_Water)
				map.SetTile(offset, CMap::sand_shore_concave_RU1);	
			else if (LU_Water)
				map.SetTile(offset, CMap::sand_shore_concave_LU1);	
			else if (LD_Water)
				map.SetTile(offset, CMap::sand_shore_concave_LD1);	
			else if (RD_Water)
				map.SetTile(offset, CMap::sand_shore_concave_RD1);
			else
				map.SetTile(offset, CMap::sand_inland + map_random.NextRanged(5));	
			
			map.AddTileFlag(offset, Tile::BACKGROUND);
			map.AddTileFlag(offset, Tile::LIGHT_PASSES);
		}
		else if (pixel == color_grass) 
		{
			//grass SURROUNDED BY SAND
			//completely surrounded island
			if (R_Sand && U_Sand && L_Sand && D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_island1);
				
			//four way crossing
			else if (RU_Sand && LU_Sand && LD_Sand && RD_Sand
						&& !R_Sand && !U_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_cross1);		
		
			//peninsula shorelines
			else if (R_Sand && U_Sand && D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_peninsula_R1);
			else if (R_Sand && U_Sand && L_Sand)
				map.SetTile(offset, CMap::grass_sand_border_peninsula_U1);
			else if (U_Sand && L_Sand && D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_peninsula_L1);
			else if (L_Sand && D_Sand && R_Sand)
				map.SetTile(offset, CMap::grass_sand_border_peninsula_D1);
				
			//three way T crossings
			else if (R_Sand && LU_Sand && LD_Sand
						&& !U_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_T_R1);
			else if (U_Sand && RD_Sand && LD_Sand
						&& !R_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_T_U1);
			else if (RU_Sand && L_Sand && RD_Sand
						&& !R_Sand && !U_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_T_L1);
			else if (RU_Sand && LU_Sand && D_Sand
						&& !R_Sand && !U_Sand && !L_Sand)
				map.SetTile(offset, CMap::grass_sand_border_T_D1);
				
			//left handed panhandle
			else if (R_Sand && LU_Sand
						&& !U_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleL_R1);
			else if (U_Sand && LD_Sand 
						&& !R_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleL_U1);
			else if (L_Sand && RD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleL_L1);
			else if (RU_Sand && D_Sand
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Sand && LD_Sand 
						&& !U_Sand && !LU_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleR_R1);
			else if (U_Sand && RD_Sand
						&& !R_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleR_U1);
			else if (RU_Sand && L_Sand
						&& !R_Sand && !U_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleR_L1);
			else if (LU_Sand && D_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand)
				map.SetTile(offset, CMap::grass_sand_border_panhandleR_D1);
				
			//splitting strips
			else if (RU_Sand && LU_Sand && RD_Sand
						&& !R_Sand && !U_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_split_RU1);
			else if (RU_Sand && LU_Sand && LD_Sand 
						&& !R_Sand && !U_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_split_LU1);
			else if (LU_Sand && LD_Sand && RD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_split_LD1);
			else if (RU_Sand && LD_Sand && RD_Sand 
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_split_RD1);
				
			//choke points
			else if (RU_Sand && RD_Sand 
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_choke_R1);
			else if (RU_Sand && LU_Sand 
						&& !R_Sand && !U_Sand && !L_Sand && !LD_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_choke_U1);
			else if (LU_Sand && LD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_choke_L1);
			else if (LD_Sand && RD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !LU_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_choke_D1);
				
			//strip shorelines
			else if (U_Sand && D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_strip_H1);
			else if (R_Sand && L_Sand)
				map.SetTile(offset, CMap::grass_sand_border_strip_V1);	

			//bend shorelines
			else if (R_Sand && RU_Sand && U_Sand && LD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_bend_RU1);
			else if (L_Sand && LU_Sand && U_Sand && RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_bend_LU1);
			else if (L_Sand && LD_Sand && D_Sand && RU_Sand)
				map.SetTile(offset, CMap::grass_sand_border_bend_LD1);
			else if (R_Sand && RD_Sand && D_Sand && LU_Sand)
				map.SetTile(offset, CMap::grass_sand_border_bend_RD1);		

			//diagonal choke points
			else if (RU_Sand && LD_Sand
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_diagonal_R1);	
			else if (LU_Sand && RD_Sand
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_diagonal_L1);				

			//straight edge shorelines
			else if (R_Sand 
						&& !U_Sand && !LU_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_straight_R1);	
			else if (U_Sand
						&& !R_Sand && !L_Sand && !LD_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_straight_U1);	
			else if (L_Sand
						&& !R_Sand && !RU_Sand && !U_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_straight_L1);	
			else if (D_Sand
						&& !R_Sand && !RU_Sand && !U_Sand && !LU_Sand && !L_Sand)
				map.SetTile(offset, CMap::grass_sand_border_straight_D1);	
				
			//convex shorelines
			else if (R_Sand && U_Sand)
				map.SetTile(offset, CMap::grass_sand_border_convex_RU1);
			else if (L_Sand && U_Sand)
				map.SetTile(offset, CMap::grass_sand_border_convex_LU1);
			else if (L_Sand && D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_convex_LD1);
			else if (R_Sand && D_Sand)
				map.SetTile(offset, CMap::grass_sand_border_convex_RD1);
				
			//concave shorelines		
			else if (RU_Sand)
				map.SetTile(offset, CMap::grass_sand_border_concave_RU1);	
			else if (LU_Sand)
				map.SetTile(offset, CMap::grass_sand_border_concave_LU1);	
			else if (LD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_concave_LD1);	
			else if (RD_Sand)
				map.SetTile(offset, CMap::grass_sand_border_concave_RD1);		
				

			else
			map.SetTile(offset, CMap::grass_inland + 1 + map_random.NextRanged(4));
			map.AddTileFlag(offset, Tile::BACKGROUND);
			map.AddTileFlag(offset, Tile::LIGHT_PASSES);
		}	
		else if (pixel == color_rock) 
		{
			//ROCK SURROUNDED BY SAND
			//completely surrounded island
			if (R_Sand && U_Sand && L_Sand && D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_island1);
				
			//four way crossing
			else if (RU_Sand && LU_Sand && LD_Sand && RD_Sand
						&& !R_Sand && !U_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_cross1);		
		
			//peninsula shorelines
			else if (R_Sand && U_Sand && D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_peninsula_R1);
			else if (R_Sand && U_Sand && L_Sand)
				map.SetTile(offset, CMap::rock_sand_border_peninsula_U1);
			else if (U_Sand && L_Sand && D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_peninsula_L1);
			else if (L_Sand && D_Sand && R_Sand)
				map.SetTile(offset, CMap::rock_sand_border_peninsula_D1);
				
			//three way T crossings
			else if (R_Sand && LU_Sand && LD_Sand
						&& !U_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_T_R1);
			else if (U_Sand && RD_Sand && LD_Sand
						&& !R_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_T_U1);
			else if (RU_Sand && L_Sand && RD_Sand
						&& !R_Sand && !U_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_T_L1);
			else if (RU_Sand && LU_Sand && D_Sand
						&& !R_Sand && !U_Sand && !L_Sand)
				map.SetTile(offset, CMap::rock_sand_border_T_D1);
				
			//left handed panhandle
			else if (R_Sand && LU_Sand
						&& !U_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleL_R1);
			else if (U_Sand && LD_Sand 
						&& !R_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleL_U1);
			else if (L_Sand && RD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleL_L1);
			else if (RU_Sand && D_Sand
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Sand && LD_Sand 
						&& !U_Sand && !LU_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleR_R1);
			else if (U_Sand && RD_Sand
						&& !R_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleR_U1);
			else if (RU_Sand && L_Sand
						&& !R_Sand && !U_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleR_L1);
			else if (LU_Sand && D_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand)
				map.SetTile(offset, CMap::rock_sand_border_panhandleR_D1);
				
			//splitting strips
			else if (RU_Sand && LU_Sand && RD_Sand
						&& !R_Sand && !U_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_split_RU1);
			else if (RU_Sand && LU_Sand && LD_Sand 
						&& !R_Sand && !U_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_split_LU1);
			else if (LU_Sand && LD_Sand && RD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_split_LD1);
			else if (RU_Sand && LD_Sand && RD_Sand 
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_split_RD1);
				
			//choke points
			else if (RU_Sand && RD_Sand 
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_choke_R1);
			else if (RU_Sand && LU_Sand 
						&& !R_Sand && !U_Sand && !L_Sand && !LD_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_choke_U1);
			else if (LU_Sand && LD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_choke_L1);
			else if (LD_Sand && RD_Sand 
						&& !R_Sand && !RU_Sand && !U_Sand && !LU_Sand && !L_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_choke_D1);
				
			//strip shorelines
			else if (U_Sand && D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_strip_H1);
			else if (R_Sand && L_Sand)
				map.SetTile(offset, CMap::rock_sand_border_strip_V1);	

			//bend shorelines
			else if (R_Sand && RU_Sand && U_Sand && LD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_bend_RU1);
			else if (L_Sand && LU_Sand && U_Sand && RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_bend_LU1);
			else if (L_Sand && LD_Sand && D_Sand && RU_Sand)
				map.SetTile(offset, CMap::rock_sand_border_bend_LD1);
			else if (R_Sand && RD_Sand && D_Sand && LU_Sand)
				map.SetTile(offset, CMap::rock_sand_border_bend_RD1);		

			//diagonal choke points
			else if (RU_Sand && LD_Sand
						&& !R_Sand && !U_Sand && !LU_Sand && !L_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_diagonal_R1);	
			else if (LU_Sand && RD_Sand
						&& !R_Sand && !RU_Sand && !U_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_diagonal_L1);				

			//straight edge shorelines
			else if (R_Sand 
						&& !U_Sand && !LU_Sand && !L_Sand && !LD_Sand && !D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_straight_R1);	
			else if (U_Sand
						&& !R_Sand && !L_Sand && !LD_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_straight_U1);	
			else if (L_Sand
						&& !R_Sand && !RU_Sand && !U_Sand && !D_Sand && !RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_straight_L1);	
			else if (D_Sand
						&& !R_Sand && !RU_Sand && !U_Sand && !LU_Sand && !L_Sand)
				map.SetTile(offset, CMap::rock_sand_border_straight_D1);	
				
			//convex shorelines
			else if (R_Sand && U_Sand)
				map.SetTile(offset, CMap::rock_sand_border_convex_RU1);
			else if (L_Sand && U_Sand)
				map.SetTile(offset, CMap::rock_sand_border_convex_LU1);
			else if (L_Sand && D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_convex_LD1);
			else if (R_Sand && D_Sand)
				map.SetTile(offset, CMap::rock_sand_border_convex_RD1);
				
			//concave shorelines		
			else if (RU_Sand)
				map.SetTile(offset, CMap::rock_sand_border_concave_RU1);	
			else if (LU_Sand)
				map.SetTile(offset, CMap::rock_sand_border_concave_LU1);	
			else if (LD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_concave_LD1);	
			else if (RD_Sand)
				map.SetTile(offset, CMap::rock_sand_border_concave_RD1);		
				
			//ROCK SURROUNDED BY SHOAL
			//completely surrounded island
			else if (R_Shoal && U_Shoal && L_Shoal && D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_island1);
				
			//four way crossing
			else if (RU_Shoal && LU_Shoal && LD_Shoal && RD_Shoal
						&& !R_Shoal && !U_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_cross1);		
		
			//peninsula shorelines
			else if (R_Shoal && U_Shoal && D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_peninsula_R1);
			else if (R_Shoal && U_Shoal && L_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_peninsula_U1);
			else if (U_Shoal && L_Shoal && D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_peninsula_L1);
			else if (L_Shoal && D_Shoal && R_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_peninsula_D1);
				
			//three way T crossings
			else if (R_Shoal && LU_Shoal && LD_Shoal
						&& !U_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_T_R1);
			else if (U_Shoal && RD_Shoal && LD_Shoal
						&& !R_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_T_U1);
			else if (RU_Shoal && L_Shoal && RD_Shoal
						&& !R_Shoal && !U_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_T_L1);
			else if (RU_Shoal && LU_Shoal && D_Shoal
						&& !R_Shoal && !U_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_T_D1);
				
			//left handed panhandle
			else if (R_Shoal && LU_Shoal
						&& !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleL_R1);
			else if (U_Shoal && LD_Shoal 
						&& !R_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleL_U1);
			else if (L_Shoal && RD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleL_L1);
			else if (RU_Shoal && D_Shoal
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Shoal && LD_Shoal 
						&& !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleR_R1);
			else if (U_Shoal && RD_Shoal
						&& !R_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleR_U1);
			else if (RU_Shoal && L_Shoal
						&& !R_Shoal && !U_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleR_L1);
			else if (LU_Shoal && D_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_panhandleR_D1);
				
			//splitting strips
			else if (RU_Shoal && LU_Shoal && RD_Shoal
						&& !R_Shoal && !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_split_RU1);
			else if (RU_Shoal && LU_Shoal && LD_Shoal 
						&& !R_Shoal && !U_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_split_LU1);
			else if (LU_Shoal && LD_Shoal && RD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_split_LD1);
			else if (RU_Shoal && LD_Shoal && RD_Shoal 
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_split_RD1);
				
			//choke points
			else if (RU_Shoal && RD_Shoal 
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_choke_R1);
			else if (RU_Shoal && LU_Shoal 
						&& !R_Shoal && !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_choke_U1);
			else if (LU_Shoal && LD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_choke_L1);
			else if (LD_Shoal && RD_Shoal 
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_choke_D1);
				
			//strip shorelines
			else if (U_Shoal && D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_strip_H1);
			else if (R_Shoal && L_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_strip_V1);	

			//bend shorelines
			else if (R_Shoal && RU_Shoal && U_Shoal && LD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_bend_RU1);
			else if (L_Shoal && LU_Shoal && U_Shoal && RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_bend_LU1);
			else if (L_Shoal && LD_Shoal && D_Shoal && RU_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_bend_LD1);
			else if (R_Shoal && RD_Shoal && D_Shoal && LU_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_bend_RD1);		

			//diagonal choke points
			else if (RU_Shoal && LD_Shoal
						&& !R_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_diagonal_R1);	
			else if (LU_Shoal && RD_Shoal
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_diagonal_L1);				

			//straight edge shorelines
			else if (R_Shoal 
						&& !U_Shoal && !LU_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_straight_R1);	
			else if (U_Shoal
						&& !R_Shoal && !L_Shoal && !LD_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_straight_U1);	
			else if (L_Shoal
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !D_Shoal && !RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_straight_L1);	
			else if (D_Shoal
						&& !R_Shoal && !RU_Shoal && !U_Shoal && !LU_Shoal && !L_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_straight_D1);	
				
			//convex shorelines
			else if (R_Shoal && U_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_convex_RU1);
			else if (L_Shoal && U_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_convex_LU1);
			else if (L_Shoal && D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_convex_LD1);
			else if (R_Shoal && D_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_convex_RD1);
				
			//concave shorelines		
			else if (RU_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_concave_RU1);	
			else if (LU_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_concave_LU1);	
			else if (LD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_concave_LD1);	
			else if (RD_Shoal)
				map.SetTile(offset, CMap::rock_shoal_border_concave_RD1);
		
			//ROCK SURROUNDED BY WATER
			//completely surrounded island
			else if (R_Water && U_Water && L_Water && D_Water)
				map.SetTile(offset, CMap::rock_shore_island1);
				
			//four way crossing
			else if (RU_Water && LU_Water && LD_Water && RD_Water
						&& !R_Water && !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_cross1);		
		
			//peninsula shorelines
			else if (R_Water && U_Water && D_Water)
				map.SetTile(offset, CMap::rock_shore_peninsula_R1);
			else if (R_Water && U_Water && L_Water)
				map.SetTile(offset, CMap::rock_shore_peninsula_U1);
			else if (U_Water && L_Water && D_Water)
				map.SetTile(offset, CMap::rock_shore_peninsula_L1);
			else if (L_Water && D_Water && R_Water)
				map.SetTile(offset, CMap::rock_shore_peninsula_D1);
				
			//three way T crossings
			else if (R_Water && LU_Water && LD_Water
						&& !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_T_R1);
			else if (U_Water && RD_Water && LD_Water
						&& !R_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_T_U1);
			else if (RU_Water && L_Water && RD_Water
						&& !R_Water && !U_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_T_L1);
			else if (RU_Water && LU_Water && D_Water
						&& !R_Water && !U_Water && !L_Water)
				map.SetTile(offset, CMap::rock_shore_T_D1);
				
			//left handed panhandle
			else if (R_Water && LU_Water
						&& !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleL_R1);
			else if (U_Water && LD_Water 
						&& !R_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleL_U1);
			else if (L_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleL_L1);
			else if (RU_Water && D_Water
						&& !R_Water && !U_Water && !LU_Water && !L_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Water && LD_Water 
						&& !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleR_R1);
			else if (U_Water && RD_Water
						&& !R_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleR_U1);
			else if (RU_Water && L_Water
						&& !R_Water && !U_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleR_L1);
			else if (LU_Water && D_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water)
				map.SetTile(offset, CMap::rock_shore_panhandleR_D1);
				
			//splitting strips
			else if (RU_Water && LU_Water && RD_Water
						&& !R_Water && !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_split_RU1);
			else if (RU_Water && LU_Water && LD_Water 
						&& !R_Water && !U_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_split_LU1);
			else if (LU_Water && LD_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_split_LD1);
			else if (RU_Water && LD_Water && RD_Water 
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_split_RD1);
				
			//choke points
			else if (RU_Water && RD_Water 
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_choke_R1);
			else if (RU_Water && LU_Water 
						&& !R_Water && !U_Water && !L_Water && !LD_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_choke_U1);
			else if (LU_Water && LD_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_choke_L1);
			else if (LD_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_choke_D1);
				
			//strip shorelines
			else if (U_Water && D_Water)
				map.SetTile(offset, CMap::rock_shore_strip_H1);
			else if (R_Water && L_Water)
				map.SetTile(offset, CMap::rock_shore_strip_V1);	

			//bend shorelines
			else if (R_Water && RU_Water && U_Water && LD_Water)
				map.SetTile(offset, CMap::rock_shore_bend_RU1);
			else if (L_Water && LU_Water && U_Water && RD_Water)
				map.SetTile(offset, CMap::rock_shore_bend_LU1);
			else if (L_Water && LD_Water && D_Water && RU_Water)
				map.SetTile(offset, CMap::rock_shore_bend_LD1);
			else if (R_Water && RD_Water && D_Water && LU_Water)
				map.SetTile(offset, CMap::rock_shore_bend_RD1);		

			//diagonal choke points
			else if (RU_Water && LD_Water
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_diagonal_R1);	
			else if (LU_Water && RD_Water
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_diagonal_L1);				

			//straight edge shorelines
			else if (R_Water 
						&& !U_Water && !LU_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::rock_shore_straight_R1);	
			else if (U_Water
						&& !R_Water && !L_Water && !LD_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_straight_U1);	
			else if (L_Water
						&& !R_Water && !RU_Water && !U_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::rock_shore_straight_L1);	
			else if (D_Water
						&& !R_Water && !RU_Water && !U_Water && !LU_Water && !L_Water)
				map.SetTile(offset, CMap::rock_shore_straight_D1);	
				
			//convex shorelines
			else if (R_Water && U_Water)
				map.SetTile(offset, CMap::rock_shore_convex_RU1);
			else if (L_Water && U_Water)
				map.SetTile(offset, CMap::rock_shore_convex_LU1);
			else if (L_Water && D_Water)
				map.SetTile(offset, CMap::rock_shore_convex_LD1);
			else if (R_Water && D_Water)
				map.SetTile(offset, CMap::rock_shore_convex_RD1);
				
			//concave shorelines		
			else if (RU_Water)
				map.SetTile(offset, CMap::rock_shore_concave_RU1);	
			else if (LU_Water)
				map.SetTile(offset, CMap::rock_shore_concave_LU1);	
			else if (LD_Water)
				map.SetTile(offset, CMap::rock_shore_concave_LD1);	
			else if (RD_Water)
				map.SetTile(offset, CMap::rock_shore_concave_RD1);
			else
				map.SetTile(offset, CMap::rock_inland + map_random.NextRanged(5));	
			
			map.AddTileFlag(offset, Tile::SOLID | Tile::COLLISION | Tile::LIGHT_PASSES);
		}
		else if (pixel == color_shoal) 
		{
			//completely surrounded island
			if (R_Water && U_Water && L_Water && D_Water)
				map.SetTile(offset, CMap::shoal_shore_island1);
				
			//four way crossing
			else if (RU_Water && LU_Water && LD_Water && RD_Water
						&& !R_Water && !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_cross1);		
		
			//peninsula shorelines
			else if (R_Water && U_Water && D_Water)
				map.SetTile(offset, CMap::shoal_shore_peninsula_R1);
			else if (R_Water && U_Water && L_Water)
				map.SetTile(offset, CMap::shoal_shore_peninsula_U1);
			else if (U_Water && L_Water && D_Water)
				map.SetTile(offset, CMap::shoal_shore_peninsula_L1);
			else if (L_Water && D_Water && R_Water)
				map.SetTile(offset, CMap::shoal_shore_peninsula_D1);
				
			//three way T crossings
			else if (R_Water && LU_Water && LD_Water
						&& !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_T_R1);
			else if (U_Water && RD_Water && LD_Water
						&& !R_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_T_U1);
			else if (RU_Water && L_Water && RD_Water
						&& !R_Water && !U_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_T_L1);
			else if (RU_Water && LU_Water && D_Water
						&& !R_Water && !U_Water && !L_Water)
				map.SetTile(offset, CMap::shoal_shore_T_D1);
				
			//left handed panhandle
			else if (R_Water && LU_Water
						&& !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleL_R1);
			else if (U_Water && LD_Water 
						&& !R_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleL_U1);
			else if (L_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleL_L1);
			else if (RU_Water && D_Water
						&& !R_Water && !U_Water && !LU_Water && !L_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleL_D1);
				
			//right handed panhandle
			else if (R_Water && LD_Water 
						&& !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleR_R1);
			else if (U_Water && RD_Water
						&& !R_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleR_U1);
			else if (RU_Water && L_Water
						&& !R_Water && !U_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleR_L1);
			else if (LU_Water && D_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water)
				map.SetTile(offset, CMap::shoal_shore_panhandleR_D1);
				
			//splitting strips
			else if (RU_Water && LU_Water && RD_Water
						&& !R_Water && !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_split_RU1);
			else if (RU_Water && LU_Water && LD_Water 
						&& !R_Water && !U_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_split_LU1);
			else if (LU_Water && LD_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_split_LD1);
			else if (RU_Water && LD_Water && RD_Water 
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_split_RD1);
				
			//choke points
			else if (RU_Water && RD_Water 
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_choke_R1);
			else if (RU_Water && LU_Water 
						&& !R_Water && !U_Water && !L_Water && !LD_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_choke_U1);
			else if (LU_Water && LD_Water 
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_choke_L1);
			else if (LD_Water && RD_Water 
						&& !R_Water && !RU_Water && !U_Water && !LU_Water && !L_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_choke_D1);
				
			//strip shorelines
			else if (U_Water && D_Water)
				map.SetTile(offset, CMap::shoal_shore_strip_H1);
			else if (R_Water && L_Water)
				map.SetTile(offset, CMap::shoal_shore_strip_V1);	

			//bend shorelines
			else if (R_Water && RU_Water && U_Water && LD_Water)
				map.SetTile(offset, CMap::shoal_shore_bend_RU1);
			else if (L_Water && LU_Water && U_Water && RD_Water)
				map.SetTile(offset, CMap::shoal_shore_bend_LU1);
			else if (L_Water && LD_Water && D_Water && RU_Water)
				map.SetTile(offset, CMap::shoal_shore_bend_LD1);
			else if (R_Water && RD_Water && D_Water && LU_Water)
				map.SetTile(offset, CMap::shoal_shore_bend_RD1);		

			//diagonal choke points
			else if (RU_Water && LD_Water
						&& !R_Water && !U_Water && !LU_Water && !L_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_diagonal_R1);	
			else if (LU_Water && RD_Water
						&& !R_Water && !RU_Water && !U_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_diagonal_L1);				

			//straight edge shorelines
			else if (R_Water 
						&& !U_Water && !LU_Water && !L_Water && !LD_Water && !D_Water)
				map.SetTile(offset, CMap::shoal_shore_straight_R1);	
			else if (U_Water
						&& !R_Water && !L_Water && !LD_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_straight_U1);	
			else if (L_Water
						&& !R_Water && !RU_Water && !U_Water && !D_Water && !RD_Water)
				map.SetTile(offset, CMap::shoal_shore_straight_L1);	
			else if (D_Water
						&& !R_Water && !RU_Water && !U_Water && !LU_Water && !L_Water)
				map.SetTile(offset, CMap::shoal_shore_straight_D1);	
				
			//convex shorelines
			else if (R_Water && U_Water)
				map.SetTile(offset, CMap::shoal_shore_convex_RU1);
			else if (L_Water && U_Water)
				map.SetTile(offset, CMap::shoal_shore_convex_LU1);
			else if (L_Water && D_Water)
				map.SetTile(offset, CMap::shoal_shore_convex_LD1);
			else if (R_Water && D_Water)
				map.SetTile(offset, CMap::shoal_shore_convex_RD1);
				
			//concave shorelines		
			else if (RU_Water)
				map.SetTile(offset, CMap::shoal_shore_concave_RU1);	
			else if (LU_Water)
				map.SetTile(offset, CMap::shoal_shore_concave_LU1);	
			else if (LD_Water)
				map.SetTile(offset, CMap::shoal_shore_concave_LD1);	
			else if (RD_Water)
				map.SetTile(offset, CMap::shoal_shore_concave_RD1);		
			else
				map.SetTile(offset, CMap::shoal_inland + map_random.NextRanged(5));	
			
			map.AddTileFlag(offset, Tile::BACKGROUND);
			map.AddTileFlag(offset, Tile::LIGHT_PASSES);
		}
	}
}
