#define CLIENT_ONLY

#include "WaterEffects.as"
#include "TileCommon.as"

Random _r(157681529);
Vec2f wind_direction;

void onTick(CRules@ this)
{
	if (getGameTime() % (v_fastrender ? 8 : 3) == 0)
	{
		//randomly permute the wind direction
		wind_direction.RotateBy((_r.NextFloat() - 0.5f) * 3.0f, Vec2f());

		CCamera@ camera = getCamera();
		Driver@ d = getDriver();
		if (camera is null || d is null) return;
		
		Vec2f wavepos = camera.getPosition() + Vec2f(-d.getScreenWidth()/2 + _r.NextRanged(d.getScreenWidth()), -d.getScreenHeight()/2 + _r.NextRanged(d.getScreenHeight()));
		
		// return if wavepos outside map bounds
		Vec2f dim = getMap().getMapDimensions();
		if (wavepos.x < 0 || wavepos.x > dim.x || wavepos.y < 0 || wavepos.y > dim.y)
			return;
		
		CBlob@ whirlpool = getBlobByName("whirlpool");
		if (whirlpool is null || (whirlpool.getPosition() - wavepos).Length() > 250.0f)
		{
			if (isInWater(wavepos))
			{
				if (v_fastrender)
					MakeWaterWave(wavepos, wind_direction, wind_direction.Angle());
				else
					MakeWaterWaveRender(wavepos);
			}
		}
	}
}

// Water rendering by GoldenGuy

void onInit(CRules@ this)
{
	Render::addScript(Render::layer_background, "WaterRendering.as", "water_render", 1);
	WavesPool waves;
	this.set("waterwaves", @waves);
}

SColor water_color = SColor(255, 41, 100, 176);

void water_render(int id)
{
	Render::SetTransformWorldspace();

	#ifdef STAGING

	CMap@ map = getMap();
	Vertex[] verts = {
		Vertex(0, 0, -800, 0, 0, water_color),
		Vertex(map.tilemapwidth*8, 0, -800, 1, 0, water_color),
		Vertex(map.tilemapwidth*8, map.tilemapheight*8, -800, 1, 1, water_color),
		Vertex(0, map.tilemapheight*8, -800, 0, 1, water_color)};
	Render::RawQuads("pixel.png", verts);

	#endif

	// get wavespool from rules
	CRules@ rules = getRules();
	WavesPool@ waves;
	rules.get("waterwaves", @waves);
	waves.Update(getCamera().getRotation()-90);
	waves.Render();
}

const int MAX_WAVES = 42;

class WavesPool
{
	float[] timers;
	Vec2f[] positions;
	float[] scales;
	Vertex[] verts;

	WavesPool()
	{
		timers = float[](MAX_WAVES);
		positions = Vec2f[](MAX_WAVES);
		scales = float[](MAX_WAVES);
		verts = Vertex[](MAX_WAVES * 4);
	}

	void AddWave(Vec2f pos)
	{
		int i = FindFreeWave();
		if(i != -1)
		{
			timers[i] = 16;
			positions[i] = pos;
			scales[i] = 1.0f + (XORRandom(100) / 100.0f * 0.25f);
			float scale = scales[i];

			Vec2f top_left = Vec2f(-8, -8)*scale;
			Vec2f top_right = Vec2f(8, -8)*scale;
			Vec2f bottom_right = Vec2f(8, 8)*scale;
			Vec2f bottom_left = Vec2f(-8, 8)*scale;

			float angle = getCamera().getRotation()-90;
			top_left.RotateBy(angle);
			top_right.RotateBy(angle);
			bottom_right.RotateBy(angle);
			bottom_left.RotateBy(angle);

			int animation_frame = 0;
			Vec2f uv1 = Vec2f(0, float(animation_frame)/16.0f);
			Vec2f uv2 = Vec2f(1, uv1.y + 1.0f/16.0f);

			verts[i*4] = Vertex(pos.x + bottom_right.x, pos.y + bottom_right.y, -800, uv1.x, uv1.y, color_white);
			verts[i*4+1] = Vertex(pos.x + top_right.x, pos.y + top_right.y, -800, uv2.x, uv1.y, color_white);
			verts[i*4+2] = Vertex(pos.x + top_left.x, pos.y + top_left.y, -800, uv2.x, uv2.y, color_white);
			verts[i*4+3] = Vertex(pos.x + bottom_left.x, pos.y + bottom_left.y, -800, uv1.x, uv2.y, color_white);
		}
	}

	// find first free wave in timers list
	int FindFreeWave()
	{
		for (int i = 0; i < MAX_WAVES; i++)
		{
			if (timers[i] <= 0)
				return i;
		}
		return -1;
	}

	// update all waves
	void Update(float angle)
	{
		for (int i = 0; i < MAX_WAVES; i++)
		{
			if (timers[i] > 0)
			{
				// update timer
				timers[i] -= (getRenderExactDeltaTime() * getTicksASecond()) / 4.0f; // 4 ticks per frame

				if(timers[i] <= 0)
				{
					// if wave is dead, set all vertices to 0
					timers[i] = 0;
					for (int j = 0; j < 4; j++)
					{
						verts[i*4+j].x = 0; verts[i*4+j].y = 0;
					}
					continue;
				}
				
				// update quad angle and uvs
				float scale = scales[i];

				Vec2f top_left = Vec2f(-8, -8)*scale;
				Vec2f top_right = Vec2f(8, -8)*scale;
				Vec2f bottom_right = Vec2f(8, 8)*scale;
				Vec2f bottom_left = Vec2f(-8, 8)*scale;

				top_left.RotateBy(angle);
				top_right.RotateBy(angle);
				bottom_right.RotateBy(angle);
				bottom_left.RotateBy(angle);

				int animation_frame = int(16 - timers[i]);
				Vec2f uv1 = Vec2f(0, float(animation_frame)/16.0f);
				Vec2f uv2 = Vec2f(1, uv1.y + 1.0f/16.0f);

				Vec2f pos = positions[i];
				int vert_id = i*4;
				verts[vert_id].x = pos.x + bottom_right.x;
				verts[vert_id].y = pos.y + bottom_right.y;
				verts[vert_id].u = uv1.x;
				verts[vert_id].v = uv1.y;
				vert_id++;
				verts[vert_id].x = pos.x + top_right.x;
				verts[vert_id].y = pos.y + top_right.y;
				verts[vert_id].u = uv2.x;
				verts[vert_id].v = uv1.y;
				vert_id++;
				verts[vert_id].x = pos.x + top_left.x;
				verts[vert_id].y = pos.y + top_left.y;
				verts[vert_id].u = uv2.x;
				verts[vert_id].v = uv2.y;
				vert_id++;
				verts[vert_id].x = pos.x + bottom_left.x;
				verts[vert_id].y = pos.y + bottom_left.y;
				verts[vert_id].u = uv1.x;
				verts[vert_id].v = uv2.y;
			}
		}
	}

	void Render()
	{
		Render::RawQuads("water_wave.png", verts);
	}
}

void MakeWaterWaveRender(Vec2f pos)
{
	// get WaterWaves array from rules
	CRules@ rules = getRules();
	WavesPool@ waves;
	rules.get("waterwaves", @waves);
	if (waves is null) return;

	waves.AddWave(pos);
}