#include "RedBarrierCommon.as"
#include "ShipsCommon.as";

////  VARS  ////

// Server owners should edit the value inside RedBarrierVars.cfg
f32 BARRIER_PERCENT = 0.175;
f32 VEL_PUSHBACK = 1.35;

const u32 ticksTillNextBounce = 4;
const u8 torpedo_size_max = 2;

s32[] shipIDs;
u32[] shipTimes;

// Var to know if the barrier is currently up 
// (used for clearing the barrier once when its game time)
// 
// Defaults to true because we want clients to remove the barrier
// if they join and its no longer warm up (fixes some rare bug)
bool IS_BARRIER_SET = true; 

// Gets toggled to true when we know the 
// config has different values
bool SYNC_CUSTOM_VARS = false;

////  HOOKS  ////

void onInit(CRules@ this)
{
	this.addCommandID("set_barrier_pos");
	this.addCommandID("set_barrier_vars");

	onRestart(this);
}

void onRestart(CRules@ this)
{
	if (!isServer())
	{
		IS_BARRIER_SET = true;
		return;
	}

	LoadConfigVars();

	SetBarrierPosition(this);

	const int playerCount = getPlayerCount();
	for (int a = 0; a < playerCount; a++)
	{
		CPlayer@ player = getPlayer(a);

		if (player is null)
			continue;

		SyncToPlayer(this, player);

		if (SYNC_CUSTOM_VARS)
			SyncVarsToPlayer(this, player);
	}
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	if (!isServer() && !shouldBarrier(this))
		return;

	SyncToPlayer(this, player);

	if (SYNC_CUSTOM_VARS)
		SyncVarsToPlayer(this, player);
}


void onTick(CRules@ this)
{
	if (!shouldBarrier(this))
	{
		IS_BARRIER_SET = false;
		return;
	}

	CMap@ map = getMap();

	Vec2f tl, br;
	getBarrierRect(@this, tl, br);

	CBlob@[] blobsInBox;
	if (map.getBlobsInBox(tl, br, @blobsInBox))
	{
		for (uint i = 0; i < blobsInBox.length; i++)
		{
			CBlob @b = blobsInBox[i];

			if (!b.getShape().isStatic() && 
				(b.getTeamNum() < 100 || b.hasTag("no barrier pass") || 
				 b.hasTag("material") || b.getName() == "spikes"))
			{
				PushBlob(b, (tl.x + br.x) * 0.5, tl.x, br.x);
			}
		}
	}
	
	u16 middle = (tl.x + br.x) * 0.5;
	
	//push ships
	CBlob@[] blobsAtBorder;
	map.getBlobsInBox(tl, br, @blobsAtBorder);
	const u8 borderBlobsLength = blobsAtBorder.length;

	ShipDictionary@ ShipSet = getShipSet(this);
	
	for (u8 i = 0; i < borderBlobsLength; i++)
	{
		CBlob@ b = blobsAtBorder[i];
		const int bCol = b.getShape().getVars().customData;
		if (bCol <= 0) continue;
			
		Ship@ ship = ShipSet.getShip(bCol);
		if (ship is null) continue;
		const Vec2f pos = b.getPosition();
		const Vec2f vel = ship.vel;
		
		if(pos.x > middle && vel.x < 5 && br.x > pos.x) ship.vel = Vec2f(vel.x + (br.x - pos.x) * 0.05, vel.y);
		else if(pos.x < middle && vel.x > -5 && tl.x < pos.x) ship.vel = Vec2f(vel.x - (pos.x - tl.x) * 0.05, vel.y);
	}
}

void onRender(CRules@ this)
{
	if (!shouldBarrier(this))
		return;
	Vertex[] Verts;
	CMap@ map = getMap();
	
	const u16 x1 = this.get_u16("barrier_x1");
	const u16 x2 = this.get_u16("barrier_x2");
	const u16 map_height = map.tilemapheight * map.tilesize;
	
	Verts.push_back(Vertex(x1, map_height,   0, 0, 0, SColor(100, 235, 0, 0))); // top left
	Verts.push_back(Vertex(x2, map_height,   0, 1, 0, SColor(100, 235, 0, 0))); // top right
	Verts.push_back(Vertex(x2, 0, 0, 1, 1, SColor(100, 235, 0, 0))); // bot right
	Verts.push_back(Vertex(x1, 0, 0, 0, 1, SColor(100, 235, 0, 0))); // bot left
	
	Render::RawQuads("WhitePixel.png", Verts);
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if (!isClient())
		return;

	if (cmd == this.getCommandID("set_barrier_pos"))
	{
		const u16 x1 = params.read_u16();
		const u16 x2 = params.read_u16();

		this.set_u16("barrier_x1", x1);
		this.set_u16("barrier_x2", x2);
	}
	else if (cmd == this.getCommandID("set_barrier_vars"))
	{
		VEL_PUSHBACK = params.read_f32();
	}
}

////  FUNCTIONS  ////

void PushBlob(CBlob@ blob, const u16 &in middle, const u16 &in x1, const u16 &in x2)
{
	Vec2f vel = blob.getVelocity();
	Vec2f pos = blob.getPosition();
	
	//players clamped to edge
	if (blob.getPlayer() !is null)
	{
		if (pos.x >= x1 && pos.x <= x2)
		{
			const f32 margin = 0.01f;
			const f32 vel_base = 0.01f;
			if (pos.x < middle)
			{
				pos.x = Maths::Min(x1 - margin, pos.x) - margin;
				vel.x = Maths::Min(-vel_base, -Maths::Abs(vel.x));
			}
			else
			{
				pos.x = Maths::Max(x2 + margin, pos.x) + margin;
				vel.x = Maths::Max(vel_base, Maths::Abs(vel.x));
			}
			blob.setPosition(pos);
		}
	}
	else
	{
		vel.x += pos.x < middle ? -VEL_PUSHBACK : VEL_PUSHBACK;
	}

	blob.setVelocity(vel);
}

void LoadConfigVars()
{
	ConfigFile cfg;
	if (!cfg.loadFile("RedBarrierVars.cfg"))
		return; // We tried :(

	BARRIER_PERCENT = cfg.read_f32("barrier_percent", 0.175f);

	// Check that we have edited the var
	// and that the client needs said value
	const f32 pushback = cfg.read_f32("blob_pushback", 1.35f);

	if (pushback != VEL_PUSHBACK)
	{
		SYNC_CUSTOM_VARS = true;
		VEL_PUSHBACK = pushback;
	}
}

// Only used server side, client doesnt normally have info required
void SetBarrierPosition(CRules@ this)
{
	IS_BARRIER_SET = true;

	Vec2f[] barrierPositions;
	CMap@ map = getMap();
	u16 x1, x2;

	// Are there barrier markers?
	if (map.getMarkers("red barrier", barrierPositions) 
		&& barrierPositions.length() == 2)
	{
		const int left = barrierPositions[0].x < barrierPositions[1].x ? 0 : 1;
		x1 = barrierPositions[left].x;
		x2 = barrierPositions[1 - left].x + map.tilesize;
	}
	else // No? Okay lets make our own!
	{
		const f32 mapWidth = map.tilemapwidth * map.tilesize;
		const f32 mapMiddle = mapWidth * 0.5f;
		const f32 barrierWidth = Maths::Floor(BARRIER_PERCENT * map.tilemapwidth) * map.tilesize;
		const f32 extraWidth = ((map.tilemapwidth % 2 == 1) ? 0.5f : 0.0f) * map.tilesize;

		x1 = mapMiddle - (barrierWidth + extraWidth);
		x2 = mapMiddle + (barrierWidth + extraWidth);
	}

	this.set_u16("barrier_x1", x1);
	this.set_u16("barrier_x2", x2);
}

// Sync barrier to said player
// Only send x as we dont have horizontal barriers (mods will add that in manually anyhow)
void SyncToPlayer(CRules@ this, CPlayer@ player)
{
	CBitStream stream;
	stream.write_u16(this.get_u16("barrier_x1"));
	stream.write_u16(this.get_u16("barrier_x2"));

	this.SendCommand(this.getCommandID("set_barrier_pos"), stream, player);
}

// Server will send its vars to the current player
// We only send this if we know that the cfg has been edited
void SyncVarsToPlayer(CRules@ this, CPlayer@ player)
{
	// Only send pushback as its the only one client needs
	CBitStream stream;
	stream.write_f32(VEL_PUSHBACK);

	this.SendCommand(this.getCommandID("set_barrier_vars"), stream, player);
}
