#include "ShipsCommon.as";
#include "AccurateSoundPlay.as";
#include "BlockCosts.as";

const f32 rotate_speed = 30.0f;
const f32 max_build_distance = 32.0f;
const u32 placement_time = 22;
const u32 station_placement_time = 11; //placement time on station
u8 crewCantPlaceCounter = 0;

void onInit(CBlob@ this)
{
	u16[] blocks;
	this.set("blocks", blocks);
	this.set_f32("blocks_angle", 0.0f);
	this.set_f32("target_angle", 0.0f);

	this.addCommandID("place");
}

void onTick(CBlob@ this)
{
	u16[] blocks;
	if (!this.get("blocks", blocks) || blocks.size() <= 0)
		return;
	
	Vec2f pos = this.getPosition();
	const u8 blocksLength = blocks.length;
	const s32 overlappingShipID = this.get_s32("shipID");
	Ship@ ship = overlappingShipID > 0 ? getShipSet().getShip(overlappingShipID) : null;
	if (ship is null)
	{
		// cant place in water
		for (u8 i = 0; i < blocksLength; ++i)
		{
			CBlob@ block = getBlobByNetworkID(blocks[i]);
			if (block is null) continue;
			
			SetDisplay(block, SColor(255, 255, 0, 0), RenderStyle::light, -10.0f);
		}
		return;
	}
	
	CBlob@ shipBlob = getBlobByNetworkID(this.get_u16("shipBlobID"));
	if (shipBlob is null)
	{
		warn("PlaceBlocks: shipBlob not found");
		return;
	}
	
	f32 blocks_angle = this.get_f32("blocks_angle"); //next step angle
	f32 target_angle = this.get_f32("target_angle"); //final angle (after manual rotation)
	Vec2f aimPos = this.getAimPos();

	PositionBlocks(blocks, pos, aimPos, blocks_angle, ship, shipBlob);

	CPlayer@ player = this.getPlayer();
	if (player !is null && player.isMyPlayer() && !this.get_bool("justMenuClicked")) 
	{
		//checks for canPlace
		CMap@ map = getMap();
		const u32 gameTime = getGameTime();
		const bool overlappingShip = blocksOverlappingShip(blocks);
		bool onRock = false;
		bool notReady = (gameTime - this.get_u32("placedTime") <= (ship.isBuildStation ? station_placement_time : placement_time)); // dont show block if we are not ready to build yet
		for (u8 i = 0; i < blocksLength; ++i)
		{
			CBlob@ block = getBlobByNetworkID(blocks[i]);
			if (block is null) continue;
			
			Tile bTile = map.getTile(block.getPosition());
			if (map.isTileSolid(bTile))
				onRock = true;
			
			if (overlappingShip || onRock || notReady)
			{
				SetDisplay(block, SColor(255, 255, 0, 0), RenderStyle::additive);
				continue;
			}
		}

		// place
		if (this.isKeyPressed(key_action1) && !getHUD().hasMenus() && !getHUD().hasButtons() && !notReady)
		{
			if (target_angle == blocks_angle && !overlappingShip && !onRock)
			{
				CBitStream params;
				params.write_s32(ship.id);
				params.write_netid(shipBlob.getNetworkID());
				params.write_Vec2f(pos - ship.origin_pos);
				params.write_Vec2f(aimPos - ship.origin_pos);
				params.write_f32(target_angle);
				params.write_f32(ship.angle);
				this.SendCommand(this.getCommandID("place"), params);
				this.set_u32("placedTime", gameTime);
			}
			else
			{
				this.getSprite().PlaySound("Denied.ogg");
				this.set_u32("placedTime", gameTime - 10);
			}
		}

		// rotate
		if (this.isKeyJustPressed(key_action3))
		{
			target_angle += 90.0f;
			if (target_angle > 360.0f)
			{
				target_angle -= 360.0f;
				blocks_angle -= 360.0f;
			}
			this.set_f32("target_angle", target_angle);
			this.Sync("target_angle", false); //-1491678232 HASH
		}
	}

	blocks_angle += rotate_speed;
	if (blocks_angle > target_angle)
		blocks_angle = target_angle;        
	this.set_f32("blocks_angle", blocks_angle);
}

void PositionBlocks(u16[] blocks, Vec2f&in pos, Vec2f&in aimPos, const f32&in blocks_angle, Ship@ ship, CBlob@ shipBlob)
{
	Vec2f ship_pos = ship.origin_pos;
	f32 refBAngle = shipBlob.getAngleDegrees(); //reference block angle
	//current ship angle as point of reference
	while (refBAngle > ship.angle + 45) refBAngle -= 90.0f;
	while (refBAngle < ship.angle - 45) refBAngle += 90.0f;
	
	//add offset of block we're standing on
	Vec2f refBOffset = shipBlob.getPosition() - ship_pos;
	refBOffset.RotateBy(-refBAngle); refBOffset.x %= 8.0f; refBOffset.y %= 8.0f; refBOffset.RotateBy(refBAngle);
	ship_pos += refBOffset;
	
	Vec2f mouseAim = aimPos - pos;
	const f32 maxDistance = Maths::Min(mouseAim.Normalize(), max_build_distance); //set the maximum distance we can place at
	aimPos = pos + mouseAim * maxDistance; //position of the 'buildblock' pointer
	Vec2f shipAim = aimPos - ship_pos; //ship to 'buildblock' pointer
	shipAim.RotateBy(-refBAngle); shipAim = SnapToGrid(shipAim); shipAim.RotateBy(refBAngle);
	Vec2f cursor_pos = ship_pos + shipAim; //position of snapped buildblock
	
	//rotate and position blocks
	const u8 blocksLength = blocks.length;
	for (u8 i = 0; i < blocksLength; ++i)
	{
		CBlob@ block = getBlobByNetworkID(blocks[i]);
		if (block is null) continue;
		
		Vec2f offset = block.get_Vec2f("offset");
		offset.RotateBy(blocks_angle + refBAngle);

		block.setPosition(cursor_pos + offset); //align to ship grid
		block.setAngleDegrees((refBAngle + blocks_angle + (block.hasTag("engine") ? 90.0f : 0.0f)) % 360.0f); //set angle: reference angle + rotation angle

		SetDisplay(block, color_white, RenderStyle::additive, 315.0f);
	}
}

Vec2f SnapToGrid(Vec2f&in pos) //determines the grid of blocks
{
	pos.x = Maths::Floor(pos.x / 8.0f + 0.5f);
	pos.y = Maths::Floor(pos.y / 8.0f + 0.5f);
	pos *= 8;
	return pos;
}

const bool blocksOverlappingShip(u16[] blocks)
{
	const u8 blocksLength = blocks.length;
	for (u8 i = 0; i < blocksLength; ++i)
	{
		CBlob@ block = getBlobByNetworkID(blocks[i]);
		if (block is null) continue;
		
		CBlob@[] overlapping; //we use radius since getOverlapping has a delay when blob is created
		if (getMap().getBlobsInRadius(block.getPosition(), 8.0f, @overlapping))
		{
			const u8 overlappingLength = overlapping.length;
			for (u8 q = 0; q < overlappingLength; q++)
			{
				CBlob@ b = overlapping[q];
				if (b.getShape().getVars().customData > 0)
				{
					if ((b.getPosition() - block.getPosition()).getLength() < block.getRadius() * 0.4f)
						return true;
				}
			}
		}
	}
	return false; 
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd != this.getCommandID("place")) return;

	const s32 shipID = params.read_s32();
	CRules@ rules = getRules();
	ShipDictionary@ ShipSet = getShipSet(rules);
	Ship@ ship = ShipSet.getShip(shipID);
	if (ship is null)
	{
		warn("place cmd: ship not found");
		return;
	}
	
	CBlob@ shipBlob = getBlobByNetworkID(params.read_netid());
	if (shipBlob is null)
	{
		warn("place cmd: shipBlob not found");
		return;
	}

	Vec2f pos_offset = params.read_Vec2f();
	Vec2f aimPos_offset = params.read_Vec2f();
	const f32 target_angle = params.read_f32();
	const f32 ship_angle = params.read_f32();
	
	u16[] blocks;
	if (!this.get("blocks", blocks) || blocks.size() <= 0)
	{
		//can happen when placing and returning blocks at same time
		if (sv_test) warn("place cmd: no blocks");
		return;
	}

	const f32 angleDelta = ship.angle - ship_angle; //to account for ship angle lag
	const u8 blocksLength = blocks.length;
	
	if (isServer())
	{
		CBlob@[] blob_blocks;
		for (u8 i = 0; i < blocksLength; ++i)
		{
			CBlob@ b = getBlobByNetworkID(blocks[i]);
			if (b !is null) blob_blocks.push_back(b);
		}
		
		rules.push("dirtyBlocks", blob_blocks);
	}
	PositionBlocks(blocks, ship.origin_pos + pos_offset.RotateBy(angleDelta), ship.origin_pos + aimPos_offset.RotateBy(angleDelta), target_angle, ship, shipBlob);

	for (u8 i = 0; i < blocksLength; ++i)
	{
		CBlob@ b = getBlobByNetworkID(blocks[i]);
		if (b is null)
		{
			if (sv_test) warn("place cmd: blob not found");
			continue;
		}
		
		b.set_netid("ownerID", 0); //so it wont add to owner blocks
		
		const f32 z = b.hasTag("platform") ? 309.0f : (b.hasTag("weapon") ? 311.0f : 310.0f);
		SetDisplay(b, color_white, RenderStyle::normal, z);
		
		if (!isServer()) //add it locally till a sync
		{
			ShipBlock ship_block;
			ship_block.blobID = b.getNetworkID();
			ship_block.offset = b.getPosition() - ship.pos;
			ship_block.offset.RotateBy(-ship.angle);
			ship_block.angle_offset = b.getAngleDegrees() - ship.angle;
			b.getShape().getVars().customData = shipID;
			ship.blocks.push_back(ship_block);
		}
		else
			b.getShape().getVars().customData = 0; // push on ship
		
		b.set_u32("placedTime", getGameTime());
	}
	
	this.clear("blocks"); //releases the blocks (they are placed)
	directionalSoundPlay("build_ladder.ogg", this.getPosition());
	
	//Grab another block
	if (this.isMyPlayer() && !this.isAttached())
	{
		CBlob@ core = getMothership(this.getTeamNum());
		if (core !is null && !core.hasTag("critical"))
		{
			const s32 overlappingShipID = this.get_s32("shipID");
			Ship@ pShip = overlappingShipID > 0 ? ShipSet.getShip(overlappingShipID) : null;
			if (pShip !is null && pShip.centerBlock !is null && ((pShip.id == core.getShape().getVars().customData) 
				|| ((pShip.isBuildStation || pShip.isSecondaryCore) && pShip.centerBlock.getTeamNum() == this.getTeamNum())))
			{
				this.set_bool("getting block", true);
				this.Sync("getting block", false);
			}
		}
	}
}

void SetDisplay(CBlob@ blob, const SColor&in color, RenderStyle::Style&in style, const f32&in Z = -10000)
{
	CSprite@ sprite = blob.getSprite();
	sprite.asLayer().SetColor(color);
	sprite.asLayer().setRenderStyle(style);
	if (Z > -10000)
	{
		sprite.SetZ(Z);
	}
}
