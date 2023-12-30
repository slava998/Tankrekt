// loads a .PNG map
// PNG loader base class - extend this to add your own PNG loading functionality!

bool LoadMap(CMap@ map, const string&in fileName)
{
	PNGLoader loader();
	return loader.loadShiprektMap(map, fileName);
}

// --------------------------------------

#include "MapBanner.as";
#include "CustomMap.as";
#include "Booty.as"

class PNGLoader
{
	PNGLoader()	{}

	CFileImage@ image;
	CMap@ map;

	bool loadShiprektMap(CMap@ _map, const string&in filename)
	{
		@map = _map;

		if (!isServer())
		{
			CMap::SetupMap(map, 0, 0);
			return true;
		} 
		SetupBooty(getRules());

		@image = CFileImage(filename);
		if (image.isLoaded())
		{
			CMap::SetupMap(map, image.getWidth(), image.getHeight());

			while (image.nextPixel())
			{
				SColor pixel = image.readPixel();
				int offset = image.getPixelOffset();
				Vec2f pixelPos = image.getPixelPosition();
				CMap::handlePixel(map, image, pixel, offset, pixelPos);
				getNet().server_KeepConnectionsAlive();
			}

			return true;
		}
		return false;
	}
}

void onInit(CMap@ this)
{
    this.legacyTileMinimap = false;
	this.legacyTileVariations = false;
	this.legacyTileEffects = false;
	this.legacyTileDestroy = false;
	this.MakeMiniMap();
}
