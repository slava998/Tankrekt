//Heal particles

shared void makeHealParticle(CBlob@ this, const string&in particleName = "HealParticle"+(XORRandom(2)+1))
{
	const Vec2f pos = this.getPosition() + getRandomVelocity(0, this.getRadius(), XORRandom(360));

	CParticle@ p = ParticleAnimated(particleName, pos, getRandomVelocity(0, 0.5f, XORRandom(360)), XORRandom(360), 1.0f, 2+XORRandom(3), 0.0f, false);
	if (p !is null)
	{
		p.diesoncollide = true;
		p.fastcollision = true;
		p.lighting = true;
		p.Z = 650.0f;
	}
}
