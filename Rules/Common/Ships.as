#include "ShipsCommon.as";
#include "AccurateSoundPlay.as";
#include "TileCommon.as";

const f32 VEL_DAMPING = 0.96f; //0.96
const f32 ANGLE_VEL_DAMPING = 0.96; //0.96
const u32 FORCE_UPDATE_TICKS = 21;

f32 UPDATE_DELTA_SMOOTHNESS = 32.0f; //~16-64
bool ship_debug = false;

/// Ship Management

void onInit(CRules@ this)
{
	print("-- Initializing Ships --");
	
	CBlob@[][] dirtyBlocks;
	this.set("dirtyBlocks", dirtyBlocks); //blocks that will affect a ship's form
	
	ShipDictionary ShipSet;
	this.set("ShipSet", ShipSet); //contains all ships
	
	this.set_s32("ships id", 0);
	this.set_bool("dirty ships", true);
	
	this.addCommandID("ship collision");
	this.addCommandID("ship bounce");
	this.addCommandID("ships sync");
	this.addCommandID("ships update");
}

void onRestart(CRules@ this)
{
	if (isServer())
		print("-- Resetting Ship Objects:: Last map's total: "+this.get_s32("ships id")+" --");
	
	this.clear("dirtyBlocks");
	getShipSet(this).deleteAll();
	
	this.set_s32("ships id", 0);
	this.set_bool("dirty ships", true);
}

void onTick(CRules@ this)
{
	if (isServer())
	{
		bool full_sync = false;
		const u32 gameTime = getGameTime();
		if (gameTime < 2) return; //issues happen if ships generate on first tick
		
		//configure ship body from placed, dead or existing blocks
		CBlob@[][]@ dirtyBlocks;
		if (this.get("dirtyBlocks", @dirtyBlocks) && dirtyBlocks.length > 0)
		{
			const u8 dirtyLength = dirtyBlocks.length;
			for (u8 i = 0; i < dirtyLength; i++)
			{
				ConfigureToShip(this, dirtyBlocks[i]);
			}
			full_sync = true;
			this.clear("dirtyBlocks");
		}
		
		//initialize ships from unassigned blocks
		if (this.get_bool("dirty ships"))
		{
			GenerateShips(this);
			full_sync = true;
			this.set_bool("dirty ships", false);
		}

		UpdateShips(this);
		Synchronize(this, full_sync);
	}
	else
		UpdateShips(this); //client-side integrate
}

// Generate ships from unassigned blocks
void GenerateShips(CRules@ this)
{
	CBlob@[] blocks;
	if (getBlobsByTag("block", @blocks))
	{
		SetUpdateBlocks();
		ShipDictionary@ ShipSet = getShipSet(this);
		
		const u16 blocksLength = blocks.length;
		for (u16 i = 0; i < blocksLength; ++i)
		{
			CBlob@ b = blocks[i];
			if (b.getShape().getVars().customData == 0)
			{
				Ship@ newShip = CreateShip(this, ShipSet);
				ColorBlocks(b, newShip);
				SetShipOrigin(b, newShip);
			}
		}	
	}
}

// Manage ship creation processes
void ConfigureToShip(CRules@ this, CBlob@[] blocks)
{
	Ship@[] touchingShips;
	ShipDictionary@ ShipSet = getShipSet(this);
	CMap@ map = getMap();
	
	const u8 blocksLength = blocks.length;
	if (blocksLength <= 0)
	{
		warn("ConfigureToShip: no blocks found!");
		return;
	}
	
	for (u8 i = 0; i < blocksLength; i++)
	{
		CBlob@ block = blocks[i];
		
		// Block has been destroyed: Do ship seperation process
		if (block.hasTag("dead"))
		{
			SeperateShip(this, block, ShipSet);
			return;
		}
		
		//find all ships touching our blocks
		CBlob@[] overlapping;
		if (!map.getBlobsInRadius(block.getPosition(), 4.0f, @overlapping)) continue;
		
		const u8 overlappingLength = overlapping.length;
		for (u8 q = 0; q < overlappingLength; q++)
		{
			CBlob@ b = overlapping[q];
			const int bCol = b.getShape().getVars().customData;
			if (bCol <= 0) continue;
			
			Ship@ ship = ShipSet.getShip(bCol);
			if (ship is null || (b.getPosition() - block.getPosition()).LengthSquared() > 78)
				continue;
			
			if (touchingShips.find(ship) == -1)
				touchingShips.push_back(ship);
		}
	}
	
	// No reference ships available: Create a new ship
	if (touchingShips.length <= 0)
	{
		Ship@ newShip = CreateShip(this, ShipSet);
		ColorBlocks(blocks[0], newShip);
		SetShipOrigin(blocks[0], newShip);
		return;
	}
	
	// Two or more reference ships: Combine all touching into one ship
	if (touchingShips.length > 1)
	{
		CombineShips(this, touchingShips, blocks[0]);
		return;
	}
	
	// Only one reference ship: Add blocks to reference ship
	if (blocks[0].getShape().getVars().customData == 0)
	{
		Ship@ ship = touchingShips[0];
		
		for (u8 i = 0; i < blocksLength; i++)
		{
			CBlob@ block = blocks[i];
			AddShipBlock(block, ship);
		}
		
		SetUpdateBlocks(ship.id);
		SetUpdateCores(ship.id);
		@ship.centerBlock = null; //re-initialize ship
	}
}

// Put two or more ships together into one
void CombineShips(CRules@ this, Ship@[] ships, CBlob@ connector)
{
	ShipDictionary@ ShipSet = getShipSet(this);
	
	ships.sortAsc(); //sorts by ship size (refer to opCmp method)
	
	Ship@ largestShip = ships[0];
	ships.erase(0);
	
	//delete other ships
	const u8 shipsLength = ships.length;
	for (u8 i = 0; i < shipsLength; ++i)
	{
		Ship@ ship = ships[i];
		//set all block colors to zero
		const u16 shipBlocks = ship.blocks.length;
		for (u16 q = 0; q < shipBlocks; ++q)
		{
			CBlob@ b = getBlobByNetworkID(ship.blocks[q].blobID);
			if (b is null) continue;
			
			b.set_u16("last color", 0);
			b.getShape().getVars().customData = 0;
		}
		
		ShipSet.delete(ship);
	}
	
	ColorBlocks(connector, largestShip);
	SetUpdateBlocks(largestShip.id);
	SetUpdateCores(largestShip.id);
	@largestShip.centerBlock = null; //recalibrate ship centerblock
}

// Seperate one ship into two or more ships
void SeperateShip(CRules@ this, CBlob@ seperator, ShipDictionary@ ShipSet)
{
	Ship@ ship = ShipSet.getShip(seperator.getShape().getVars().customData);
	if (ship is null) return;
	
	seperator.getShape().getVars().customData = -1; //only neccessary for blocks that arent actually dead yet
	
	CBlob@[] blocks;
	const u16 shipBlocksLength = ship.blocks.length;
	for (u16 i = 0; i < shipBlocksLength; ++i)
	{
		CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
		if (b is null) continue;
		
		blocks.push_back(b);
		b.set_u16("last color", 0);
		if (b.getShape().getVars().customData > 0)
			b.getShape().getVars().customData = 0;
	}
	
	ship.blocks.clear();
	
	const u16 blocksLength = blocks.length;
	for (u16 i = 0; i < blocksLength; ++i)
	{
		CBlob@ b = blocks[i];
		if (b.getShape().getVars().customData == 0)
		{
			if (i == 0) //reference first block
			{
				ColorBlocks(b, ship);
			}
			else //make new branches off our original ship
			{
				Ship@ newShip = CreateShip(this, ShipSet);
				ColorBlocks(b, newShip);
				SetShipOrigin(b, newShip);
				SetUpdateBlocks(newShip.id);
				SetUpdateCores(newShip.id);

				//reference past velocities for a seamless transition
				newShip.vel = ship.vel;
				newShip.angle_vel = ship.angle_vel;
			}
		}
	}
	SetUpdateBlocks(ship.id);
	SetUpdateCores(ship.id);
	@ship.centerBlock = null; //recalibrate ship centerblock
}

// Create a ship object
Ship@ CreateShip(CRules@ this, ShipDictionary@ ShipSet)
{
	this.add_s32("ships id", 1); //set next ID
	
	Ship ship;
	ship.id = this.get_s32("ships id");
	ShipSet.setShip(ship.id, @ship);
	
	return ship;
}

// Set the ship's origin
void SetShipOrigin(CBlob@ this, Ship@ ship)
{
	ship.origin_pos = this.getPosition();
	ship.angle = this.getAngleDegrees();
}

// Set information needed to pair a block to a ship
void AddShipBlock(CBlob@ this, Ship@ ship)
{
	//set color as ship's id
	this.getShape().getVars().customData = ship.id;
	this.set_u16("last color", ship.id);

	//add to ship blocks
	ShipBlock ship_block;
	ship_block.blobID = this.getNetworkID();
	ship.blocks.push_back(ship_block);
}

// Goes through the entirety of connected blobs to determine ship blocks
void ColorBlocks(CBlob@ this, Ship@ ship, CMap@ map = getMap())
{
	const u16 lastCol = this.get_u16("last color");
	const Vec2f pos = this.getPosition();
	const u32 placeTime = this.get_u32("placedTime");
	const bool isCoupling = this.hasTag("coupling");
	const u32 gameTime = getGameTime();
	
	if (lastCol != ship.id) //can do infinite loop- if you don't know what you're doing
	{
		AddShipBlock(this, ship);
	}
	
	CBlob@[] overlapping;
	map.getBlobsInRadius(pos, 4.0f, @overlapping);
	
	const u8 overlappingLength = overlapping.length;
	for (u8 i = 0; i < overlappingLength; i++)
	{
		CBlob@ b = overlapping[i];
		if (b.getShape().getVars().customData == 0 && b.hasTag("block") // is uncolored block
			&& (b.getPosition() - pos).LengthSquared() < 78 //avoid corner overlaps
			&& (b.get_u16("last color") == lastCol || b.hasTag("coupling") || isCoupling
			|| gameTime - b.get_u32("placedTime") < 10 || gameTime - placeTime < 10)) //just placed block
		{
			ColorBlocks(b, ship, map); //continue the cycle
		}
	}
}

// Sets information that doesn't need to be set every tick (centerblock, mass etc)
void InitShip(Ship@ ship)
{	
	Vec2f center;
	const u16 blocksLength = ship.blocks.length;
	if (ship.centerBlock is null) //when clients InitShip(), they should have key values pre-synced. no need to calculate
	{
		f32 totalMass = 0.0f;
		ship.isMothership = ship.isStation = ship.isSecondaryCore = false; //recheck ship types
		
		for (u16 i = 0; i < blocksLength; ++i)
		{
			CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
			if (b is null) continue;
			
			//centerblock calculation
			center += b.getPosition();
			
			//mass calculation
			totalMass += b.get_f32("weight");
			
			//determine the ship type
			if (b.hasTag("mothership"))     ship.isMothership = true;
			if (b.hasTag("station"))        ship.isStation = true;
			if (b.hasTag("secondaryCore"))  ship.isSecondaryCore = true;
		}
		center /= blocksLength;
		
		//print(ship.id + " mass: " + totalMass + "; effective: " + ship.mass);
		ship.mass = totalMass; //linear mass growth

		//determine center block
		if (blocksLength == 2)
		{
			//use an engine as centerblock for 2 block ships (this is used for torpedo border bounce)
			for (u16 i = 0; i < blocksLength; ++i)
			{
				CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
				if (b is null || !b.hasTag("engine")) continue;

				@ship.centerBlock = b;
				break;
			}
		}
		if (ship.centerBlock is null)
		{
			//find the center of ship and label it as the centerBlock
			f32 maxDistance = 999999.9f;
			for (u16 i = 0; i < blocksLength; ++i)
			{
				CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
				if (b is null) continue;
				
				Vec2f vec = b.getPosition() - center;
				const f32 dist = vec.LengthSquared();
				if (dist < maxDistance)
				{
					maxDistance = dist;
					@ship.centerBlock = b;
				}
			}
		}
		
		if (ship.centerBlock !is null)
		{
			ship.pos = ship.centerBlock.getPosition();
		}
	}
	
	if (ship.centerBlock is null)
	{
		if (!isClient() || sv_test)
			warn("InitShip: ship.centerBlock is null! ID ["+ship.id+"]");
		return;
	}

	center = ship.centerBlock.getPosition();
	
	ship.origin_offset = ship.origin_pos - center;
	ship.origin_offset.RotateBy(-ship.angle);
	
	//update block positions/angle array
	for (u16 i = 0; i < blocksLength; ++i)
	{
		ShipBlock@ ship_block = ship.blocks[i];
		CBlob@ b = getBlobByNetworkID(ship_block.blobID);
		if (b is null) continue;
		
		ship_block.offset = b.getPosition() - center;
		ship_block.offset.RotateBy(-ship.angle);
		ship_block.angle_offset = loopAngle(b.getAngleDegrees() - ship.angle);
	}
}

// Called every tick, this is what makes the ships move and function
void UpdateShips(CRules@ this, const bool&in integrate = true)
{
	CMap@ map = getMap();
	ShipDictionary@ ShipSet = getShipSet(this);
	Ship@[] ships = ShipSet.getShips();
	
	const u16 shipsLength = ships.length;
	for (u16 i = 0; i < shipsLength; ++i)
	{
		Ship@ ship = ships[i];
		if (ship is null) continue;
		
		const u16 blocksLength = ship.blocks.length;
		if (blocksLength <= 0)
		{
			warn("UpdateShips: no ship blocks found! Removing ID ["+ship.id+"]");
			ShipSet.delete(ship);
			continue;
		}

		ship.soundsPlayed = 0;
		ship.carryMass = 0;
		ship.colliding = false;
		
		if (ship.centerBlock is null) //initialize or re-calibrate ship
		{
			InitShip(ship);
		}

		if (ship.isStation)
		{
			//stations don't move
			ship.vel = Vec2f(0, 0);
			ship.angle_vel = 0.0f;
		}
		else if (integrate)
		{
			ship.old_pos = ship.pos;
			ship.old_angle = ship.angle;
			ship.pos += ship.vel;
			ship.angle = loopAngle(ship.angle + ship.angle_vel);
			ship.vel *= VEL_DAMPING;
			ship.angle_vel *= ANGLE_VEL_DAMPING;
			
			Vec2f offset = ship.origin_offset;
			offset.RotateBy(ship.angle);
			ship.origin_pos = ship.pos + offset;
			
			//check for beached or slowed ships
			
			u16 beachedBlocks = 0;
			u16 slowedBlocks = 0;
			
			for (u16 q = 0; q < blocksLength; ++q)
			{
				CBlob@ b = getBlobByNetworkID(ship.blocks[q].blobID);
				if (b is null) continue;
				
				Vec2f bPos = b.getPosition();	
				Tile bTile = map.getTile(bPos);
				
				if (map.isTileSolid(bTile) && bPos.Length() > 15.0f) //are we on rock
				{
					TileCollision(ship, bPos);
					if (!b.hasTag("mothership") || this.get_bool("whirlpool"))
						b.server_Hit(b, bPos, Vec2f_zero, 1.0f, 0, true);
				}
				else if (isTouchingLand(bPos))  beachedBlocks++;
				else if (isTouchingShoal(bPos)) slowedBlocks++;
			}
			
			if (beachedBlocks > 0)
			{
				const f32 velocity = Maths::Clamp(beachedBlocks / ship.mass, 0.0f, 0.4f);
				ship.vel *= 1.0f - velocity;
				ship.angle_vel *= 1.0f - velocity;
			}
			else if (slowedBlocks > 0)
			{
				const f32 velocity = Maths::Clamp(slowedBlocks / (ship.mass * 2), 0.0f, 0.08f);
				ship.vel *= 1.0f - velocity;
				ship.angle_vel *= 1.0f - velocity;
			}
		}
		
		if (!isServer() || (getGameTime() + ship.id * 33) % 45 != 0)
		{
			for (u16 q = 0; q < blocksLength; ++q)
			{
				ShipBlock@ ship_block = ship.blocks[q];
				CBlob@ b = getBlobByNetworkID(ship_block.blobID);
				if (b is null) continue;
				
				UpdateShipBlob(b, ship, ship_block);
			}
		}
		else //(server) find the ship's owner
		{
			CBlob@ core = null;
			bool multiTeams = false;
			bool multiCores = false;
			u8 teamComp = 255;	
			u16[] seatIDs;
			
			for (u16 q = 0; q < blocksLength; ++q)
			{
				ShipBlock@ ship_block = ship.blocks[q];
				CBlob@ b = getBlobByNetworkID(ship_block.blobID);
				if (b is null) continue;
				
				UpdateShipBlob(b, ship, ship_block);
				
				if (b.hasTag("seat") && !b.get_string("playerOwner").isEmpty())
				{
					seatIDs.push_back(ship_block.blobID);
					
					if (teamComp == 255)
						teamComp = b.getTeamNum();
					else if (b.getTeamNum() != teamComp)
						multiTeams = true;
				} 
				else if (b.hasTag("mothership"))
				{
					if (core !is null)
						multiCores = true;
					@core = b;
				}
			}
			
			string oldestSeatOwner = "";
			
			const u8 seatLength = seatIDs.length;
			if (seatLength > 0)
			{
				seatIDs.sortAsc();
				
				if (multiTeams) // ship has multiple owners (e.g two connected motherships)
					oldestSeatOwner = "*";
				else
				{
					//find the oldest seat available
					const bool mothership = ship.isMothership && core !is null;
					for (u8 q = 0; q < seatLength; q++)
					{
						CBlob@ oldestSeat = getBlobByNetworkID(seatIDs[q]);
						u16[] checked, unchecked;
						if (oldestSeat !is null && (mothership ? shipLinked(oldestSeat, core, checked, unchecked) : true))
						{
							oldestSeatOwner = oldestSeat.get_string("playerOwner");
							break;
						}
					}
				}

				//change ship team (only non-motherships that have activated seats)
				if (!multiCores && !multiTeams && !ship.isStation && !oldestSeatOwner.isEmpty() && ship.owner != oldestSeatOwner)
				{
					CPlayer@ oldestOwner = getPlayerByUsername(oldestSeatOwner);

					if (oldestOwner !is null && (core !is null ? core.getTeamNum() == oldestOwner.getTeamNum() : true))
					{
						server_setShipTeam(ship, oldestOwner.getTeamNum());
					}
				}
			}
			
			ship.owner = oldestSeatOwner;
		}
		//if (!ship.owner.isEmpty()) print("updated ship " + ship.id + "; owner: " + ship.owner + "; mass: " + ship.mass);
	}
	
	//calculate carryMass weight
	CBlob@[] humans;
	getBlobsByName("human", @humans);
	const u8 humansLength = humans.length;
	for (u8 i = 0; i < humansLength; i++)
	{
		CBlob@ human = humans[i];
		
	    u16[] blocks;
		if (human.get("blocks", blocks) && blocks.size() > 0)
		{
			const s32 overlappingShipID = human.get_s32("shipID");
			Ship@ ship = overlappingShipID > 0 ? ShipSet.getShip(overlappingShipID) : null;
			if (ship is null) continue;
			
			//player-carried blocks add to the ship mass (with penalty)
			const u8 blocksLength = blocks.length;
			for (u8 q = 0; q < blocksLength; q++)
			{
				CBlob@ block = getBlobByNetworkID(blocks[q]);
				if (block is null) continue;
				ship.carryMass += 2.5f * block.get_f32("weight");
			}
		}
	}
}

// Relay the ship's information to the block so all blobs move in unison (expensive!)
void UpdateShipBlob(CBlob@ blob, Ship@ ship, ShipBlock@ ship_block)
{
	Vec2f offset = ship_block.offset;
	offset.RotateBy(ship.angle);
	
	blob.setPosition(ship.pos + offset);
	blob.setAngleDegrees(ship.angle + ship_block.angle_offset);
	blob.setVelocity(Vec2f_zero);
	blob.setAngularVelocity(0.0f);
}

// Update blocks outside of this script
void SetUpdateBlocks(const int&in shipColor = 0)
{
	CBlob@[] blocks;
	getBlobsByTag("weapon", @blocks); //update docking info
	getBlobsByTag("seat", @blocks);   //update controls
	UpdateBlocks(shipColor, blocks);
}

// Update core rings spritelayer
void SetUpdateCores(const int&in shipColor = 0)
{
	if (!isClient()) return;
	
	CBlob@[] blocks;
	if (getBlobsByTag("core", @blocks))
		UpdateBlocks(shipColor, blocks);
}

// Update specified blocks
void UpdateBlocks(const int&in shipColor, CBlob@[] blocks)
{
	const u16 blocksLength = blocks.length;
	for (u16 i = 0; i < blocksLength; i++)
	{
		CBlob@ b = blocks[i];
		if (b.getShape().getVars().customData == shipColor || shipColor == 0)
			b.set_bool("updateBlock", true);
	}
}

// For collision with tiles (rock)
void TileCollision(Ship@ ship, Vec2f&in tilePos)
{
	Vec2f colvec1 = ship.pos - tilePos;
	colvec1.Normalize();
	
	ship.vel = colvec1;
	
	//effects
	if (isClient())
	{
		Vec2f velnorm = ship.vel; 
		const f32 vellen = velnorm.Normalize();
	
		const u8 shake = vellen * ship.mass;
		ShakeScreen(Maths::Min(shake, 120), 12, tilePos);
		directionalSoundPlay(shake > 25 ? "WoodHeavyBump" : "WoodLightBump", tilePos);
	}
}

// Awkward fix for blob team changes wiping up the frame state (rest on Block.as)
void onBlobChangeTeam(CRules@ this, CBlob@ blob, const int oldTeam)
{
	if (!isServer() && blob.hasTag("block") && blob.getSprite().getFrame() > 0)
		blob.set_u8("frame", blob.getSprite().getFrame());
}

// Remove blocks from ships or kill ships when the block dies
void onBlobDie(CRules@ this, CBlob@ blob)
{
	const int blobColor = blob.getShape().getVars().customData;
	if (blobColor <= 0) return;
	
	ShipDictionary@ ShipSet = getShipSet(this);
	
	Ship@ ship = ShipSet.getShip(blobColor);
	if (ship is null) return;
	
	if (ship.blocks.length <= 1) //no blocks left, kill ship
	{
		ShipSet.delete(ship);
		return;
	}
	
	//remove block from shipblocks
	const u16 blockID = blob.getNetworkID();
	for (u16 i = 0; i < ship.blocks.length; ++i)
	{
		if (ship.blocks[i].blobID != blockID) continue;
		
		ship.blocks.erase(i);
		if (ship.centerBlock !is null && ship.centerBlock.getNetworkID() == blockID)
		{
			@ship.centerBlock = null;
		}
		break;
	}
	
	if (isServer() && ship.blocks.length > 1 && !blob.hasTag("activated"))
	{
		blob.Tag("dead");
		CBlob@[] tempArray; tempArray.push_back(blob);
		this.push("dirtyBlocks", tempArray);
	}
}

// Keeps an angle within the engine's boundaries (-740 to 740)
const f32 loopAngle(f32 angle)
{
	while (angle < 0.0f)	angle += 360.0f;
	while (angle > 360.0f)	angle -= 360.0f;
	return angle;
}

// Checks if the ship has moved from its previous position/angle
const bool isShipChanged(Ship@ ship)
{
	const f32 thresh = 0.01f;
	return ((ship.pos - ship.old_pos).LengthSquared() > thresh || Maths::Abs(ship.angle - ship.old_angle) > thresh);
}

/// Networking

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	if (!player.isMyPlayer())
		Synchronize(this, true, player);
}

// Sends a command to synchronize clients to the server
void Synchronize(CRules@ this, const bool full_sync, CPlayer@ player = null)
{
	if (isClient()) return; //no need to synchronize on localhost
	
	CBitStream bs;
	if (Serialize(this, bs, full_sync))
	{
		if (player is null)
		{
			this.SendCommand(full_sync ? this.getCommandID("ships sync") : this.getCommandID("ships update"), bs);
		}
		else
		{
			this.SendCommand(full_sync ? this.getCommandID("ships sync") : this.getCommandID("ships update"), bs, player);
		}
	}
}

// Writes ship information into bitstream for client cmd
const bool Serialize(CRules@ this, CBitStream@ stream, const bool&in full_sync)
{
	ShipDictionary@ ShipSet = getShipSet(this);
	Ship@[] ships = ShipSet.getShips();
	
	const u16 shipsLength = ships.length;
	stream.write_u16(shipsLength);
	
	bool atLeastOne = false;
	
	for (u16 i = 0; i < shipsLength; ++i)
	{
		Ship@ ship = ships[i];
		if (ship is null)
		{
			warn("Serialize: ship not found, iteration ["+i+"]");
			continue;
		}
		
		if (full_sync)
		{
			//send all of a ship's info- ships sync
			const u16 blocksLength = ship.blocks.length;
			
			stream.write_Vec2f(ship.pos);
			stream.write_s32(ship.id);
			stream.write_string(ship.owner);
			stream.write_netid(ship.centerBlock !is null ? ship.centerBlock.getNetworkID() : 0);
			stream.write_Vec2f(ship.vel);
			stream.write_Vec2f(ship.origin_offset);
			stream.write_f32(ship.angle);
			stream.write_f32(ship.angle_vel);
			stream.write_f32(ship.mass);
			stream.write_bool(ship.isMothership);
			stream.write_bool(ship.isStation);
			stream.write_bool(ship.isSecondaryCore);
			stream.write_u16(blocksLength);
			
			for (u16 q = 0; q < blocksLength; ++q)
			{
				ShipBlock@ ship_block = ship.blocks[q];
				CBlob@ b = getBlobByNetworkID(ship_block.blobID);
				if (b !is null)
				{
					stream.write_netid(b.getNetworkID());
					stream.write_Vec2f(ship_block.offset);
					stream.write_f32(ship_block.angle_offset);
				}
				else
				{
					stream.write_netid(0);
					stream.write_Vec2f(Vec2f_zero);
					stream.write_f32(0.0f);
				}
			}
			ship.net_pos = ship.pos;
			ship.net_vel = ship.vel;
			ship.net_angle = ship.angle;
			ship.net_angle_vel = ship.angle_vel;
			atLeastOne = true;
		}
		else
		{
			//send ship's movement info only- ships update
			const u32 FORCE_UPDATE_TIME = getGameTime() + i;
			if (FORCE_UPDATE_TIME % FORCE_UPDATE_TICKS == 0 || isShipChanged(ship))
			{
				const f32 thresh = 0.005f;
				
				stream.write_bool(true);
				stream.write_string(ship.owner);
				if ((ship.net_pos - ship.pos).LengthSquared() > thresh) //position
				{
					stream.write_bool(true);
					stream.write_Vec2f(ship.pos);
					ship.net_pos = ship.pos;
				}
				else stream.write_bool(false);

				if ((ship.net_vel - ship.vel).LengthSquared() > thresh) //velocity
				{
					stream.write_bool(true);
					stream.write_Vec2f(ship.vel);
					ship.net_vel = ship.vel;
				}
				else stream.write_bool(false);
				
				if (Maths::Abs(ship.net_angle - ship.angle) > thresh) //angle
				{
					stream.write_bool(true);
					stream.write_f32(ship.angle);
					ship.net_angle = ship.angle;
				}
				else stream.write_bool(false);

				if (Maths::Abs(ship.net_angle_vel - ship.angle_vel) > thresh) //angular velocity
				{
					stream.write_bool(true);
					stream.write_f32(ship.angle_vel);
					ship.net_angle_vel = ship.angle_vel;
				}
				else stream.write_bool(false);

				atLeastOne = true;
			}
			else
				stream.write_bool(false);
		}
	}
	return atLeastOne;
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	/// ship functions CMD
	
	if (cmd == this.getCommandID("ship collision")) //sent from Block.as
	{
		ShipDictionary@ ShipSet = getShipSet(this);
		
		Ship@ ship = ShipSet.getShip(params.read_s32());
		Ship@ other_ship = ShipSet.getShip(params.read_s32());
		if (ship is null || other_ship is null) return;
		
		if (!params.saferead_Vec2f(ship.vel))
		{
			warn("ship collision (CMD): ship.vel not found, ID ["+ship.id+"]");
			return;
		}
		if (!params.saferead_Vec2f(other_ship.vel))
		{
			warn("ship collision (CMD): other_ship.vel not found, ID ["+other_ship.id+"]");
			return;
		}
		
		const Vec2f point1 = params.read_Vec2f();
		const u8 shake = params.read_u8();
		if (isClient())
		{
			ShakeScreen(Maths::Min(shake, 100), 12, point1);
			directionalSoundPlay(shake > 25 ? "WoodHeavyBump" : "WoodLightBump", point1);
		}
		
		return;
	}
	else if (cmd == this.getCommandID("ship bounce")) //sent from MapBarrier.as
	{
		const s32 shipID = params.read_s32();
		
		Ship@ ship = getShipSet(this).getShip(shipID);
		if (ship is null) return;
		
		f32 bounceAngle;
		if (!params.saferead_f32(bounceAngle))
		{
			warn("ship bounce (CMD): bounce angle not found, ID ["+ship.id+"]");
			return;
		}
		
		if (bounceAngle != 800)
		{
			ship.angle = loopAngle(bounceAngle);
		}
		
		if (!params.saferead_Vec2f(ship.vel))
		{
			warn("ship bounce (CMD): ship.vel not found, ID ["+ship.id+"]");
			return;
		}
		
		return;
	}
	
	/// ship networking CMD
	
	if (isServer()) return; //ONLY CLIENT BELOW

	if (cmd == this.getCommandID("ships sync"))
	{
		ShipDictionary@ ShipSet = getShipSet(this);
		ShipSet.deleteAll();
		
		const u16 count = params.read_u16();
		for (u16 i = 0; i < count; ++i)
		{
			Ship ship;
			if (!params.saferead_Vec2f(ship.pos))
			{
				warn("ships sync (CMD): ship.pos not found");
				return;
			}
			ship.id = params.read_s32();
			ship.owner = params.read_string();
			const u16 centerBlockID = params.read_netid();
			@ship.centerBlock = centerBlockID != 0 ? getBlobByNetworkID(centerBlockID) : null;
			ship.vel = params.read_Vec2f();
			ship.origin_offset = params.read_Vec2f();
			ship.angle = params.read_f32();
			ship.angle_vel = params.read_f32();
			ship.mass = params.read_f32();
			ship.isMothership = params.read_bool();
			ship.isStation = params.read_bool();
			ship.isSecondaryCore = params.read_bool();
			
			if (ship.centerBlock !is null && ship.vel.LengthSquared() > 0.01f) //try to use local values to smoother sync
			{
				ship.pos = ship.centerBlock.getPosition();
			}
			Vec2f offset = ship.origin_offset;
			offset.RotateBy(ship.angle);
			ship.origin_pos = ship.pos + offset;
			
			ship.old_pos = ship.pos;
			ship.old_angle = ship.angle;
			
			const u16 blocks_count = params.read_u16();
			for (u16 q = 0; q < blocks_count; ++q)
			{
				u16 netid;
				if (!params.saferead_netid(netid))
				{
					warn("ships sync (CMD): netid not found");
					return;
				}
				CBlob@ b = getBlobByNetworkID(netid);
				const Vec2f pos = params.read_Vec2f();
				const f32 angle = params.read_f32();
				if (b is null)
				{
					warn("ships sync (CMD): blob not found when creating ship, ID ["+netid+"]");
					return;
				}
				
				ShipBlock ship_block;
				ship_block.blobID = netid;
				ship_block.offset = pos;
				ship_block.angle_offset = angle;
				ship.blocks.push_back(ship_block);
				b.getShape().getVars().customData = ship.id; //color

				//safety on desync
				b.SetVisible(true);
				CSprite@ sprite = b.getSprite();
				sprite.asLayer().SetColor(color_white);
				sprite.asLayer().setRenderStyle(RenderStyle::normal);
			}
			ShipSet.setShip(ship.id, @ship);
		}

		SetUpdateCores();
		UpdateShips(this, false);
	}
	else if (cmd == this.getCommandID("ships update"))
	{
		u16 count;
		if (!params.saferead_u16(count))
		{
			warn("ships update (CMD): count not found");
			return;
		}
		
		ShipDictionary@ ShipSet = getShipSet(this);
		Ship@[] ships = ShipSet.getShips();
		
		if (count != ships.length)
		{
			//onNewPlayerJoin is called with a delay after a player joins, which triggers this warning
			if (sv_test)
				warn("ships update received before ships sync (CMD): SERVER [" +count+ "] , CLIENT [" +ships.length+ "]");
			return;
		}
		
		for (u16 i = 0; i < count; ++i)
		{
			if (params.read_bool()) //has the ship changed since last update?
			{
				Ship@ ship = ships[i];
				if (ship is null)
				{
					warn("ships update (CMD): ship not found ["+i+"]");
					return;
				}

				ship.owner = params.read_string();
				if (params.read_bool()) //passed position thresh
				{
					Vec2f dDelta = params.read_Vec2f() - ship.pos;
					if (dDelta.LengthSquared() < 512) //8 blocks threshold
						ship.pos += dDelta / UPDATE_DELTA_SMOOTHNESS;
					else
						ship.pos += dDelta; 
				}
				if (params.read_bool()) //passed velocity thresh
				{
					ship.vel = params.read_Vec2f() * VEL_DAMPING;
				}
				if (params.read_bool()) //passed angle thresh
				{
					f32 aDelta =  params.read_f32() - ship.angle;
					if (aDelta > 180)	aDelta -= 360;
					if (aDelta < -180)	aDelta += 360;
					ship.angle = loopAngle(ship.angle + aDelta / UPDATE_DELTA_SMOOTHNESS);
				}
				if (params.read_bool()) //passed angle-velocity thresh
				{
					ship.angle_vel = params.read_f32() * ANGLE_VEL_DAMPING;
				}
			}
		}
	}
}

/// Debug Rendering

bool onClientProcessChat(CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player)
{	
	if (player is null) return true;

	const bool myPlayer = player.isMyPlayer();
	
	if (textIn.substr(0,1) == "!")
	{
		string[]@ tokens = textIn.split(" ");
		
		if (tokens[0] == "!candy") //toggle ship debug mode
		{
			if (myPlayer)
			{
				ship_debug = !ship_debug;
				return false;
			}
		}
		else if (tokens[0] == "!ds") //check or change delta smoothness for the player's client
		{
			if (myPlayer)
			{
				if (tokens.length > 1)
				{
					UPDATE_DELTA_SMOOTHNESS = Maths::Max(1.0f, parseFloat(tokens[1]));
					client_AddToChat("Delta smoothness set to " + UPDATE_DELTA_SMOOTHNESS);
				}
				else
					client_AddToChat("Delta smoothness: " + UPDATE_DELTA_SMOOTHNESS);
			}
			return false;
		}
	}
	
	return true;
}

void onRender(CRules@ this)
{
	//draw ship colors & block ids while in shiprekt debug mode
	
	if (g_debug != 1 && !ship_debug) return;
	
	CCamera@ camera = getCamera();
	if (camera is null) return;
	const f32 camRotation = camera.getRotation();
	
	ShipDictionary@ ShipSet = getShipSet(this);
	if (ShipSet is null) return;
	Ship@[] ships = ShipSet.getShips();
	
	const u16 shipsLength = ships.length;
	for (u16 i = 0; i < shipsLength; ++i)
	{
		Ship@ ship = ships[i];
		if (ship is null) continue;
		
		Vec2f cbPos = getDriver().getScreenPosFromWorldPos(ship.pos);
		Vec2f iVel = ship.vel * 20;
		iVel.RotateBy(-camRotation);
		GUI::DrawArrow2D(cbPos, cbPos + iVel, SColor(175, 0, 200, 0));
		if (camera.targetDistance <= 1.0f)
		{
			GUI::SetFont("menu");
			GUI::DrawTextCentered("" + ship.id, cbPos, SColor(255,255,255,255));
			//GUI::DrawText("" + ship.vel.Length(), cbPos, SColor(255,255,255,255));
		}
		
		GUI::SetFont("normal");
		const u16 blocksLength = ship.blocks.length;
		for (u16 q = 0; q < blocksLength; ++q)
		{
			ShipBlock@ ship_block = ship.blocks[q];
			CBlob@ b = getBlobByNetworkID(ship_block.blobID);
			if (b is null) continue;
			
			const int c = b.getShape().getVars().customData;
			GUI::DrawRectangle(getDriver().getScreenPosFromWorldPos(b.getPosition() - Vec2f(4, 4).RotateBy(camRotation)), 
							   getDriver().getScreenPosFromWorldPos(b.getPosition() + Vec2f(4, 4).RotateBy(camRotation)), SColor(100, c*50, -c*90, 93*c));
			if (camera.targetDistance > 1.0f)
				GUI::DrawTextCentered("" + ship_block.blobID, getDriver().getScreenPosFromWorldPos(b.getPosition()), SColor(255,255,255,255));
		}
	}
}
