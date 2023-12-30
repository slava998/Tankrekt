// GoldenGuy @ 4/1/2022

#include "CustomTiles.as";
//Show custom image on server-browsing where the map is shown

//CFileImage@ map_image = CFileImage("Whirlpool.png");
Noise noise(69420);

void CalculateMinimapColour(CMap@ this, u32 offset, TileType type, SColor &out col)
{
	//Draw image

	Vec2f pos = this.getTileSpacePosition(offset);
	f32 noise_value = 0.7f+(noise.Sample(pos/10)*noise.Fractal(pos/10))*0.3f;
	SColor interpolation_col = SColor(0xFF87623B);
	
	SColor water = SColor(0xFFEAD6BB).getInterpolated(interpolation_col, noise_value);
	SColor shoal = SColor(0xFFD2BA9C);//.getInterpolated(interpolation_col, noise_value);
	SColor sand = SColor(0xFFC6A075);//.getInterpolated(interpolation_col, noise_value);
	SColor rock = SColor(0xFF999186);//.getInterpolated(interpolation_col, noise_value);

	SColor water_shoal = shoal.getInterpolated(color_black, 0.9f);
	SColor water_sand = sand.getInterpolated(color_black, 0.9f);
	SColor water_rock = rock.getInterpolated(color_black, 0.9f);

	if (type == CMap::tile_empty)
	{
		//col = SColor(255, 41, 100, 176);
		TileType t_up = offset - this.tilemapwidth > 0 ? this.getTile(offset - this.tilemapwidth).type : CMap::tile_empty;
		TileType t_down = offset + this.tilemapwidth < this.tilemapwidth*this.tilemapheight ? this.getTile(offset + this.tilemapwidth).type : CMap::tile_empty;
		TileType t_left = offset - 1 > 0 ? this.getTile(offset - 1).type : CMap::tile_empty;
		TileType t_right = offset + 1 < this.tilemapwidth*this.tilemapheight ? this.getTile(offset + 1).type : CMap::tile_empty;

		// if one of neighbour tiles are one of rock types, use water_rock color
		if((t_up >= CMap::rock_inland && t_up <= CMap::rock_shoal_border_diagonal_L1)
		|| (t_down >= CMap::rock_inland && t_down <= CMap::rock_shoal_border_diagonal_L1)
		|| (t_left >= CMap::rock_inland && t_left <= CMap::rock_shoal_border_diagonal_L1)
		|| (t_right >= CMap::rock_inland && t_right <= CMap::rock_shoal_border_diagonal_L1))
		{
			col = water_rock;
		}
		// else, then same for shoal
		else if((t_up >= CMap::shoal_inland && t_up <= CMap::sand_shoal_border_diagonal_L1)
		|| (t_down >= CMap::shoal_inland && t_down <= CMap::sand_shoal_border_diagonal_L1)
		|| (t_left >= CMap::shoal_inland && t_left <= CMap::sand_shoal_border_diagonal_L1)
		|| (t_right >= CMap::shoal_inland && t_right <= CMap::sand_shoal_border_diagonal_L1))
		{
			col = water_shoal;
		}
		// same for sand
		else if((t_up >= CMap::sand_inland && t_up <= CMap::sand_shoal_border_diagonal_L1)
		|| (t_down >= CMap::sand_inland && t_down <= CMap::sand_shoal_border_diagonal_L1)
		|| (t_left >= CMap::sand_inland && t_left <= CMap::sand_shoal_border_diagonal_L1)
		|| (t_right >= CMap::sand_inland && t_right <= CMap::sand_shoal_border_diagonal_L1))
		{
			col = water_sand;
		}
		else
		{
			col = water;
		}

		return;
	}
	else if (type >= CMap::sand_inland && type <= CMap::grass_sand_border_diagonal_L1)
	{
		//col = SColor(255, 236, 213, 144);
		col = sand;
		return;
	}
	else if (type >= CMap::rock_inland && type <= CMap::rock_shoal_border_diagonal_L1)
	{
		//col = SColor(255, 161, 161, 161);
		col = rock;
		return;
	}
	else if (type >= CMap::shoal_inland && type <= CMap::sand_shoal_border_diagonal_L1)
	{
		//col = SColor(255, 100, 170, 180);
		col = shoal;
		return;
	}
	
	/*map_image.setPixelOffset(offset);
	SColor col_temp = map_image.readPixel();
	if (col_temp.getAlpha() >= 255) col = col_temp;
	else col = SColor(255, 41, 100, 176); //water color
	return;*/
	
	/*const int w = this.tilemapwidth;
	const int x = offset % w;
	const int y = offset / w;

	//stolen from pirate-rob >:)
	int imageX = (w - map_image.getWidth())/2;
	int imageY = 10;
	if (x >= imageX && x < imageX + map_image.getWidth())
	{
		if (y >= imageY && y < imageY + map_image.getHeight())
		{
			map_image.setPixelPosition(Vec2f(x - imageX,y-imageY));
			SColor col_temp = map_image.readPixel();
			if (col_temp.getAlpha() >= 255)
			{
				col = col_temp;
				return;
			}
		}
	}
	col = SColor(255, 41, 100, 176); //anything else is colored water*/
}
