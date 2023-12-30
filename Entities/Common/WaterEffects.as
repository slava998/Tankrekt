#include "TileCommon.as";
Random _waterparticlerandom(0x1a73a);

CParticle@ MakeWaterParticle(const Vec2f&in pos, const Vec2f&in vel)
{
	if (isInWater(pos))
	{
		CParticle@ p = ParticleAnimated("Sprites/water_splash.png",
												  pos, vel,
												  _waterparticlerandom.NextFloat() * 360.0f, //angle
												  0.5f+_waterparticlerandom.NextFloat() * 0.5f, //scale
												  5, //animtime
												  0.0f, //gravity
												  true); //selflit
		if (p !is null)
			p.Z = 2.0f;

		return p;
	}
	return null;
}

CParticle@ MakeWaterWave(const Vec2f&in pos, const Vec2f&in vel, const f32&in angle)
{
	CParticle@ p = ParticleAnimated("Sprites/water_wave.png",
											  pos, vel,
											  angle, //angle
											  0.8f+_waterparticlerandom.NextFloat() * 0.4f, //scale
											  7, //animtime
											  0.0f, //gravity
											  true); //selflit
	if (p !is null)
		p.Z = 2.0f;

	return p;
}

CParticle@ MakeWhirlpoolParticle(const Vec2f&in pos, const Vec2f&in vel, const int&in animtime)
{
	CParticle@ p = ParticleAnimated("Sprites/water_whirl.png",
											  pos, vel,
											  _waterparticlerandom.NextFloat() * 360.0f, //angle
											  0.5f+_waterparticlerandom.NextFloat() * 0.5f, //scale
											  animtime, //animtime
											  0.0f, //gravity
											  true); //selflit
	if (p !is null)
		p.Z = -21.0f;

	return p;
}

void makeWaveRing(Vec2f&in center, const f32&in speed = 4.0f, const u8&in animtime = 10)
{
	Vec2f pos = Vec2f(0.0f, 1.0f);
	u16 step = 7;
	for (u16 i = 0; i < 360; i += step)
	{
		CParticle@ p = ParticleAnimated("Sprites/water_whirl.png",
											  center + pos * 8, pos * speed,
											  _waterparticlerandom.NextFloat() * 360.0f, //angle
											  0.5f+_waterparticlerandom.NextFloat() * 0.5f, //scale
											  animtime, //animtime
											  0.0f, //gravity
											  true); //selflit
		if (p !is null)
			p.Z = -21.0f;
			
		pos.RotateBy(step);
	}
}
