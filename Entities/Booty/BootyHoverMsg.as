// thanks to Splittingred
#define CLIENT_ONLY
#include "HoverMessageShiprekt.as";
#include "ActorHUDStartPos.as"
int oldBooty = 0;

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	CPlayer@ player = blob.getPlayer();
	
	if (player is null || !player.isMyPlayer())
		return;
	
	CRules@ rules = getRules();
	const string userName = player.getUsername();
	const u16 currentBooty = rules.get_u16("booty" + userName);
	const int diff = currentBooty - oldBooty;
	oldBooty = currentBooty;

	if (diff > 0)
		bootyIncrease(blob, diff);
	else if (diff < 0)
		bootyDecrease(blob, diff);
	
	HoverMessageShiprekt2[]@ messages;
	if (blob.get("messages", @messages))
	{
		for (u16 i = 0; i < messages.length; i++)
		{
			HoverMessageShiprekt2@ message = messages[i];
			message.draw(getActorHUDStartPosition(blob, 6) +  Vec2f(70 , -4));

			if (message.isExpired())
			{
				messages.removeAt(i);
			}
		}
	}
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	HoverMessageShiprekt2[]@ messages;
	if (blob.get("messages", @messages))
	{
		u16 messagesLength = messages.length;
		for (u16 i = 0; i < messagesLength; i++)
		{
			HoverMessageShiprekt2@ message = messages[i];
			message.draw(getActorHUDStartPosition(blob, 6) +  Vec2f(70 , -4));
		}
	}
}

void bootyIncrease(CBlob@ this, const int&in amount)
{
	if (!this.exists("messages"))
	{
		HoverMessageShiprekt2[] messages;
		this.set("messages", messages);
	}

	this.clear("messages");
	HoverMessageShiprekt2 m("", amount, SColor(255, 0, 255, 0), 50, 3, false, "+");
	this.push("messages", m);
}

void bootyDecrease(CBlob@ this, const int&in amount)
{
	if (!this.exists("messages"))
	{
		HoverMessageShiprekt2[] messages;
		this.set("messages", messages);
	}

	this.clear("messages");
	HoverMessageShiprekt2 m("", amount, SColor(255,255,0,0), 50, 3);
	this.push("messages", m);
}
