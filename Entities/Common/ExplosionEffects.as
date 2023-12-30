shared void makeSmallExplosionParticle(const Vec2f&in pos)
{
    CParticle@ p = ParticleAnimated("Entities/Effects/Sprites/SmallExplosion"+(XORRandom(3)+1)+".png",
                      pos, Vec2f_zero, 0.0f, 1.0f,
                      3+XORRandom(3),
                      0.0f, true);
    if (p !is null)
        p.Z = 650.0f;
}

shared void makeBrightExplosionParticle(const Vec2f&in pos)
{
    CParticle@ p = ParticleAnimated("Entities/Effects/Sprites/explosion_old.png",
                      pos, Vec2f_zero, 0.0f, 1.0f,
                      2+XORRandom(2),
                      0.0f, true);
    if (p !is null)
        p.Z = 650.0f;
}

shared void makeLargeExplosionParticle(const Vec2f&in pos)
{
    CParticle@ p = ParticleAnimated("Entities/Effects/Sprites/Explosion.png",
                      pos, Vec2f_zero, 0.0f, 1.0f,
                      3+XORRandom(3),
                      0.0f, true);
    if (p !is null)
        p.Z = 650.0f;
}

shared void makeHugeExplosionParticle(const Vec2f&in pos)
{
    CParticle@ p = ParticleAnimated("Entities/Effects/Sprites/Explosion.png",
                      pos, Vec2f_zero, 0.0f, 2.0f,
                      8,
                      0.0f, true);
    if (p !is null)
        p.Z = 650.0f;
}
