#define CLIENT_ONLY
#include "MakeDustParticle.as";

//Block damage frames
//NOTICE: put this script before the block's script in the CFG if the block adds more frames in it's onInit

void onInit(CBlob@ this)
{
	if (this.hasTag("noDamageAnim")) return;
	
	CSprite@ sprite = this.getSprite();
	Animation@ animation = sprite.addAnimation("default", 0, false);
	int[] frames = {0, 1, 2}; //blocks require atleast three frames
	animation.AddFrames(frames);
	sprite.SetAnimation("default");

	updateFrame(this);
}

void onHealthChange(CBlob@ this, float old)
{
	updateFrame(this);
}

void updateFrame(CBlob@ this)
{
	if (this.hasTag("noDamageAnim")) return;
	
	CSprite@ sprite = this.getSprite();
	if (sprite.animation is null) return; //not required
	
	const u8 frames = sprite.animation.getFramesCount();
	const u8 step = frames - ((this.getHealth() / this.getInitialHealth()) * frames);
	
	if (sprite.animation.frame < step && !v_fastrender)
	{
		const Vec2f pos = this.getPosition();
		
		for (u8 i = 0; i < 2; ++i) //wood chips on frame change
		{
			CParticle@ p = makeGibParticle("Woodparts", pos, getRandomVelocity(0, 0.3f, XORRandom(360)),
											0, XORRandom(6), Vec2f(8, 8), 0.0f, 0, "");
			if (p !is null)
			{
				//p.Z = 550.0f;
				p.damping = 0.98f;
			}
		}
		
		MakeDustParticle(pos, "/dust2.png");
	}
	
	sprite.animation.frame = step;
}
