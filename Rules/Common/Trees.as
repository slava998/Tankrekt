#include "TileCommon.as"

void onInit(CRules@ this)
{
	this.addCommandID("sync_treesPool");
	if(isServer()) InitializeTrees(this);
	if(isClient()) this.set_s16("trees_render_id", Render::addScript(Render::layer_prehud, "Trees.as", "trees_render", 0));
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player) 
{
	SyncTrees(this, player);
}

shared void SyncTrees(CRules@ this, CPlayer@ player)
{
	if(!isServer() || player is null) return;
	
	TreesPool@ trees;
	this.get("trees", @trees);
	if(trees is null) return;
	
	Vec2f[] positions = trees.getPosArray();
	
	if(positions.size() <= 0) return;
	
	f32[] angles = trees.getAngleArray();
	CBitStream params;
	params.write_u16(player.getNetworkID());
	params.write_u16(positions.size());

	for(int i = 0; i < positions.size(); i++)
	{
		params.write_Vec2f(positions[i]);
	}
	for(int i = 0; i < positions.size(); i++)
	{
		params.write_f32(angles[i]);
	}

	this.SendCommand(this.getCommandID("sync_treesPool"), params, player);
}

void onRestart(CRules@ this)
{
	TreesPool@ trees;
	if(!this.get("trees", @trees)) return;
	
	trees.positions.clear();
	trees.angles.clear();
}

void InitializeTrees(CRules@ this)
{
	TreesPool@ trees_;
	if(this.get("trees", @trees_)) return;
	
	TreesPool trees;
	this.set("trees", @trees);
}

void trees_render(int id)
{
	CRules@ rules = getRules();
	TreesPool@ trees;
	rules.get("trees", @trees);
	if(trees !is null) trees.Render();
}

shared class TreesPool
{
	Vec2f[] positions;
	f32[] angles;

	TreesPool()
	{
	}

	void AddTree(Vec2f pos)
	{
		positions.push_back(pos);
		angles.push_back(XORRandom(361));
	}
	
	void Render()
	{	
		if(!isClient()) return;
		Vertex[] Verts;
		SColor Col = SColor(255,255,255,255);
		
		const f32 screenHeight = getScreenHeight();
		const f32 screenWidth = getScreenWidth();
		const f32 scale = getDriver().getResolutionScaleFactor();
		
		for(int i = 0; i < positions.size(); i++)
		{
			Verts.clear();
			
			//checking if tree is on screen
			Vec2f pos = positions[i];
			const Vec2f scrpos = getDriver().getScreenPosFromWorldPos(pos);
			if(scrpos.x + 28 * scale >= 0 && scrpos.x - 28 * scale <= screenWidth &&
			   scrpos.y + 26 * scale >= 0 && scrpos.y - 26 * scale <= screenHeight)
			{
				const f32 angle = angles[i];
				
				//tree vertexes
				Vec2f vec = pos - Vec2f(14, 13).RotateBy(angle);
				Verts.push_back(Vertex(vec.x, vec.y, -800, 0, 0, Col)); //top left
				
				vec = pos - Vec2f(-14, 13).RotateBy(angle);
				Verts.push_back(Vertex(vec.x, vec.y, -800, 1, 0, Col)); //top right
				
				vec = pos - Vec2f(-14, -13).RotateBy(angle);
				Verts.push_back(Vertex(vec.x, vec.y, -800, 1, 1, Col)); //bot right
				
				vec = pos - Vec2f(14, -13).RotateBy(angle);
				Verts.push_back(Vertex(vec.x, vec.y, -800, 0, 1, Col)); //bot left
				
				Render::RawQuads("Tree.png", Verts);
			}
		}
	}
	
	Vec2f[] getPosArray()
	{
		return positions;
	}
	
	f32[] getAngleArray()
	{
		return angles;
	}
	
}
void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("sync_treesPool") && isClient())
	{
		u16 ply_id;
		if(!params.saferead_u16(ply_id)) return;
		
		CPlayer@ local = getLocalPlayer();
		if(local.getNetworkID() != ply_id) return;
		
		TreesPool@ trees;
		if(!this.get("trees", @trees)) 
		{
			InitializeTrees(this);
			this.get("trees", @trees);
		}
		else
		{
			trees.positions.clear();
			trees.angles.clear();
		}
		
		u16 array_size;
		if(!params.saferead_u16(array_size)) return;

		
		for(int i = 0; i < array_size; i++)
		{
			trees.positions.push_back(params.read_Vec2f());
		}
		for(int i = 0; i < array_size; i++)
		{
			trees.angles.push_back(params.read_f32());
		}
	}
}