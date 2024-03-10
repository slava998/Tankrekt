Random _punchr(0xfecc);

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	if (blob.isAttached())
	{
		this.SetAnimation("default");
	}
	else if(blob.get_bool("currently_reloading")) this.SetAnimation("reload");
	else if (blob.get_bool("onGround"))
	{
		if(blob.isKeyPressed(key_action2) && blob.getVelocity().Length() < 0.1f && blob.get_string("current tool") == "pistol") //aiming imitation
		{
			if(blob.get_string("gunName") != "rpg")
			{
				if (!this.isAnimation("shoot"))
					this.SetAnimation("shoot");
			}
			else if (!this.isAnimation("rpgshoot"))
				this.SetAnimation("rpgshoot");
		}
		else if (this.isAnimationEnded() ||
			!(this.isAnimation("punch1") || this.isAnimation("punch2") || this.isAnimation("shoot") || this.isAnimation("rpgshoot")))
		{
			if (blob.isKeyPressed(key_action2) && (blob.get_string("current tool") == "deconstructor") && !blob.isKeyPressed(key_action1))
			{
				this.SetAnimation("reclaim");
			}
			else if (blob.isKeyPressed(key_action2) && (blob.get_string("current tool") == "reconstructor") && !blob.isKeyPressed(key_action1))
			{
				this.SetAnimation("repair");
			}
			else if (blob.isKeyPressed(key_action1))
			{
				this.SetAnimation("punch"+(_punchr.NextRanged(2)+1));
			}
			else if (blob.getShape().vellen > 0.1f)
			{
				this.SetAnimation("walk");
			}
			else
			{
				this.SetAnimation("default");
			}
		}
	}
	else //in water
	{
		if (this.isAnimationEnded() || !((this.isAnimation("shoot") || this.isAnimation("rpgshoot")) && !this.isAnimation("reload")))
		{
			if (blob.isKeyPressed(key_action2) && (blob.get_string("current tool") == "deconstructor"))
			{
				this.SetAnimation("reclaim");
			}
			else if (blob.isKeyPressed(key_action2) && (blob.get_string("current tool") == "reconstructor"))
			{
				this.SetAnimation("repair");
			}
			else if (blob.getShape().vellen > 0.1f)
			{
				this.SetAnimation("swim");
			}
			else
			{
				this.SetAnimation("float");
			}
		}
	}
	this.SetZ(320.0f);
}
