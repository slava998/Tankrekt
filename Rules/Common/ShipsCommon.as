shared class Ship
{
	s32 id;                   //ship's identity key
	ShipBlock[] blocks;       //all blocks on a ship
	Vec2f pos, vel;           //position, velocity
	f32 angle, angle_vel;     //angle of ship, angular velocity
	Vec2f old_pos, old_vel;   //comparing new to old position, velocity
	f32 old_angle;            //comparing new to old angle
	f32 mass, carryMass;      //weight of the entire ship, weight carried by a player
	CBlob@ centerBlock;       //the block in the center of the entire ship
	uint soundsPlayed;        //used in limiting sounds in propellers
	string owner;             //username of the player who owns the ship
	Vec2f origin_pos;         //reference pos for the entire ship
	Vec2f origin_offset;      //origin's offset from the ship's center
	bool isMothership;        //does the ship contain a mothership core?
	bool isStation;           //does the ship contain a station?
	bool isSecondaryCore;     //does the ship contain an auxiliary core?
	bool colliding;           //used in ship collisions to stop ships from colliding twice in the same tick
	
	Vec2f net_pos, net_vel;        //network
	f32 net_angle, net_angle_vel;  //network

	Ship()
	{
		angle = angle_vel = old_angle = mass = carryMass = 0.0f;
		colliding = isMothership = isStation = isSecondaryCore = false;
		@centerBlock = null;
		id = soundsPlayed = 0;
		owner = "";
	}
	
	bool opEquals(Ship@ ship)
	{
		return this is ship;
	}
	
	int opCmp(Ship@ ship)
	{
		return ship.blocks.length - blocks.length;
	}
};

shared class ShipBlock
{
	u16 blobID;
	Vec2f offset;
	f32 angle_offset;
};

shared class ShipDictionary
{
	// we use this ShipDictionary instead of engine dictionary because using
	// dictionary.delete & dictionary.getKeys() together causes an engine crash.
	// if this ^ bug is fixed then this class can be scrapped and the engine dictionary should be used instead

	dictionary ships;
	Ship@[] allShips;

	void setShip(const s32&in ID, Ship@ ship) // Set a ship object to the dictionary
	{
		ships.set(ID+"", @ship);
		allShips.push_back(ship);
	}

	Ship@ getShip(const s32&in ID) // Grab a ship object from the dictionary
	{
		Ship@ ship;
		ships.get(ID+"", @ship);
		return ship;
	}

	void deleteAll() // Remove all entries
	{
		ships.deleteAll();
		allShips.clear();
	}

	void delete(Ship@ ship) // Delete an entry
	{
		ships.delete(ship.id+"");
		const s32 shipIndex = allShips.find(ship);
		if (shipIndex > -1)
			allShips.erase(shipIndex);
	}

	const Ship@[] getShips() // Retrieve all ships inside the dictionary
	{
		return allShips;
	}
}

// Use info from the ships dictionary
shared ShipDictionary@ getShipSet(CRules@ rules = getRules())
{
	ShipDictionary@ ShipSet;
	rules.get("ShipSet", @ShipSet);
	return ShipSet;
}

// Reference a ship from a non-block (e.g human)
shared Ship@ getOverlappingShip(CBlob@ this, ShipDictionary@ ShipSet = getShipSet())
{
	CBlob@[] blobsInRadius;
	if (getMap().getBlobsInRadius(this.getPosition(), 1.0f, @blobsInRadius)) 
	{
		const u8 blobsLength = blobsInRadius.length;
		for (u8 i = 0; i < blobsLength; i++)
		{
			const int color = blobsInRadius[i].getShape().getVars().customData;
			if (color > 0)
				return ShipSet.getShip(color);
		}
	}
	return null;
}

// Gets the mothership core block on determined team 
shared CBlob@ getMothership(const u8&in team, CRules@ rules = getRules())
{
	if (team < 8)
	{
		u16[] cores;
		if (rules.get("motherships", cores))
			return getBlobByNetworkID(cores[team]);
	}
	return null;
}

// Gets the name of the mothership's captain
shared const string getCaptainName(const u8&in team, ShipDictionary@ ShipSet = getShipSet())
{
	CBlob@ core = getMothership(team);
	if (core !is null)
	{
		const int coreCol = core.getShape().getVars().customData;
		if (coreCol > 0)
		{
			Ship@ ship = ShipSet.getShip(coreCol);
			if (ship !is null)
				return ship.owner;
		}
	}
	return "";
}

// Paths to specified block from start, returns true if it is connected
// Doesn't path through couplings and repulsors
shared const bool shipLinked(CBlob@ this, CBlob@ goal, u16[]&in checked, u16[]&in unchecked, const bool&in colorCheck = true)
{
	const u16 networkID = this.getNetworkID();
	checked.push_back(networkID);
	
	// remove from unchecked blocks if this was marked as unchecked
	const s16 uncheckedIndex = unchecked.find(networkID);
	if (uncheckedIndex > -1)
	{
		unchecked.erase(uncheckedIndex);
	}
	
	CBlob@[] overlapping;
	if (this.getOverlapping(@overlapping))
	{
		const Vec2f thisPos = this.getPosition();
		const Vec2f corePos = goal.getPosition();
		const int coreColor = goal.getShape().getVars().customData;
		
		f32 minDist = 99999.0f;
		CBlob@ optimal = null;
		const u8 overlappingLength = overlapping.length;
		for (u8 i = 0; i < overlappingLength; i++)
		{
			CBlob@ b = overlapping[i];
			Vec2f bPos = b.getPosition();
			if (checked.find(b.getNetworkID()) >= 0 ||    // no repeated blocks
				(bPos - thisPos).LengthSquared() >= 78 || // block has to be adjacent
				b.hasTag("removable") || !b.hasTag("block") || // block is not a coupling or repulsor
				(b.getShape().getVars().customData != coreColor && colorCheck)) // is a block, is same ship as goal
				continue;
			
			const f32 coreDist = (bPos - corePos).Length();
			if (coreDist < minDist)
			{
				minDist = coreDist;
				if (optimal !is null) // put non-optimal blocks as unchecked blocks for future alternative pathing
					unchecked.push_back(optimal.getNetworkID());
				@optimal = b; // set closest blob to core as the optimal route
			}
		}
		if (optimal !is null)
		{
			if (optimal is goal)
			{
				// we found the block we were looking for, stop the process
				return true;
			}
			//print(optimal.getNetworkID()+"");
			// continue best estimated path
			return shipLinked(optimal, goal, checked, unchecked, colorCheck);
		}
		else // dead end on path, find next best route from cached 'unchecked' blocks
		{
			if (unchecked.length <= 0)
				return false;
			
			CBlob@ nextBest = getBlobByNetworkID(unchecked[0]);
			if (nextBest !is null)
			{
				// start new path
				unchecked.erase(0);
				//print(nextBest.getNetworkID()+" NEW PATH");
				return shipLinked(nextBest, goal, checked, unchecked, colorCheck);
			}
		}
	}
	return false;
}

shared void server_setShipTeam(Ship@ ship, const int&in teamNum)
{
	const u16 blocksLength = ship.blocks.length;
	for (u16 i = 0; i < blocksLength; ++i)
	{
		CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
		if (b !is null)
			b.server_setTeamNum(teamNum);
	}
}
