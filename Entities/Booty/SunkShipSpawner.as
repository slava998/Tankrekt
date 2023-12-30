#define SERVER_ONLY
//Spawn booty randomly
const u16 FREQUENCY = 2*30;//30 = 1 second
const f32 CLEAR_RADIUS_FACTOR = 2.5f;
const f32 MAX_CLEAR_RADIUS = 700.0f;
const u32 PADDING = 80;//border spawn padding
const u32 MAX_PENALTY_TIME = 90 * 30 * 60;//time where the area of spawning is reduced to the centermap

void onTick(CRules@ this)
{
	if (getGameTime() % FREQUENCY > 0 || getRules().get_bool("whirlpool")) return;
	
	CMap@ map = getMap();
	const f32 mWidth = map.tilemapwidth * map.tilesize;
	const f32 mHeight = map.tilemapheight * map.tilesize;
	Vec2f center = Vec2f(mWidth/2, mHeight/2);
	const u16 totalB = totalBooty();
	const f32 timePenalty = Maths::Max(0.0f, 1.0f - getGameTime()/MAX_PENALTY_TIME);
	const u16 MAX_AMOUNT = this.get_u16("booty_x_max");
	const u16 MIN_AMOUNT = this.get_u16("booty_x_min");
	const f32 PER_PLAYER_AMMONT = 2.5f * MAX_AMOUNT;
	//print("<> " + getGameTime()/30/60 + " minutes penalty%: " + timePenalty);

	if (totalB < getPlayersCount() * PER_PLAYER_AMMONT)
	{
		for (u8 tries = 0; tries < 5; tries++)
		{
			Vec2f spot = Vec2f (center.x + 0.4f * (XORRandom(2) == 0 ? -1 : 1) * XORRandom(center.x - PADDING),
											center.y + 0.4f * (XORRandom(2) == 0 ? -1 : 1) * XORRandom(center.y - PADDING));
			if (zoneClear(map, spot, timePenalty < 0.2f))
			{
				f32 centerDist = (center - spot).Length();
				u16 amount = Maths::Max(MIN_AMOUNT, (1.0f - centerDist/Maths::Min(mWidth, mHeight)) * MAX_AMOUNT);
				createBooty(spot, amount);
				return;
			}
		}
		
		if (timePenalty > 0.4f)
		{
			for (u8 tries = 0; tries < 10; tries++)
			{
				Vec2f spot = Vec2f (center.x + timePenalty * (XORRandom(2) == 0 ? -1 : 1) * XORRandom(center.x - PADDING),
												center.y + timePenalty * (XORRandom(2) == 0 ? -1 : 1) * XORRandom(center.y - PADDING));
				if (zoneClear(map, spot))
				{
					f32 centerDist = (center - spot).Length();
					u16 amount = Maths::Max(MIN_AMOUNT, (1.0f - centerDist/Maths::Min(mWidth, mHeight)) * MAX_AMOUNT);
					createBooty(spot, amount);
					break;
				}
			}
		}
	}
}

void createBooty(const Vec2f&in pos, const u16&in amount)
{
	CBlob@ booty = server_CreateBlobNoInit("booty");
	if (booty !is null)
	{
		booty.Tag("booty");
		booty.set_u16("amount", amount);
		booty.set_u16("prevAmount", amount);
		booty.server_setTeamNum(-1);
		booty.setPosition(pos);
		booty.Init();
	}
}

const int totalBooty()
{
	CBlob@[] booty;
	getBlobsByName("booty", @booty);
	u16 totalBooty = 0;

	const u8 bootyLength = booty.length;
	for (u8 b = 0; b < bootyLength; b++)
		totalBooty += booty[b].get_u16("amount");

	return totalBooty;
}

const bool zoneClear(CMap@ map, const Vec2f&in spot, const bool&in onlyBooty = false)
{
	const f32 clearRadius = Maths::Min(Maths::Sqrt(map.tilemapwidth * map.tilemapheight) * CLEAR_RADIUS_FACTOR, MAX_CLEAR_RADIUS);
	const bool mothership = map.isBlobWithTagInRadius("mothership", spot, clearRadius * 0.5f);
	const bool booty = map.isBlobWithTagInRadius("booty", spot, clearRadius);

	return !booty && (onlyBooty || !mothership);
}
