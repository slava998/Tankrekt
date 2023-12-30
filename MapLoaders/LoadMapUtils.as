Vec2f getSpawnPosition(CMap@ map, const int&in offset)
{
	Vec2f pos = map.getTileWorldPosition(offset);
	f32 tile_offset = map.tilesize * 0.5f;
	pos.x += tile_offset;
	pos.y += tile_offset;
	return pos;
}

CBlob@ spawnBlob(CMap@ map, const string&in name, const int&in offset, const int&in team, const bool&in attached_to_map = false)
{
	CBlob@ blob = server_CreateBlob(name, team, getSpawnPosition(map, offset));

	if (blob !is null && attached_to_map)
	{
		blob.getShape().SetStatic(true);
	}

	return blob;
}

void AddMarker(CMap@ map, const int&in offset, const string&in name)
{
	map.AddMarker(map.getTileWorldPosition(offset), name);
}
