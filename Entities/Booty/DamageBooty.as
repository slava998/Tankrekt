//Give booty from damaging with weaponry

#include "Booty.as";
#include "ShipsCommon.as";

shared class BootyRewards
{
	TagReward[] tag_rewards;
	
	void addTagReward(const string tag, const u16 reward)
	{
		TagReward tag_reward(tag, reward);
		tag_rewards.push_back(tag_reward);
	}
}

shared class TagReward
{
	string tag;
	u16 reward;
	
	TagReward(const string _tag, const u16 _reward)
	{
		tag = _tag;
		reward = _reward;
	}
}

void rewardBooty(CPlayer@ attacker, CBlob@ victim, BootyRewards@ booty_reward, const string&in sound = "Pinball_0")
{
	if (isServer() || attacker.isMyPlayer())
	{
		if (booty_reward is null)
		{
			warn("Booty Reward null!");
			return;
		}
		
		const int col = victim.getShape().getVars().customData;
		if (col <= 0) return;
		
		Ship@ victimShip = getShipSet().getShip(col);
		if (victimShip is null || (victimShip.owner.isEmpty() && !victimShip.isMothership) || victim.getTeamNum() == attacker.getTeamNum())
			return;
		
		u16 reward = 0;
		
		const u8 tagsLength = booty_reward.tag_rewards.length;
		for (u8 i = 0; i < tagsLength; i++)
		{
			TagReward@ tag_reward = booty_reward.tag_rewards[i];
			if (victim.hasTag(tag_reward.tag))
			{
				reward = tag_reward.reward;
				break;
			}
		}
		
		if (reward <= 0) return;
		
		if (isClient() && attacker.getBlob() !is null)
			Sound::Play(sound, attacker.getBlob().getPosition(), 0.8f);
		
		if (isServer())
		{
			const u16 bFactor = getRules().get_bool("whirlpool") ? 3 : 1;
			reward *= bFactor;
			
			server_addPlayerBooty(attacker.getUsername(), reward);
			server_updateTotalBooty(attacker.getTeamNum(), reward);
		}
	}
}
