//Gingerbeard @ 3/27/2022
//Converts a block to the player's team after some time nearby

const int capture_radius = 8;
const u8 checkFrequency = 15;
const u8 checkFrequencyIdle = 40;

void onInit(CBlob@ this)
{
	this.getCurrentScript().tickFrequency = checkFrequencyIdle;
	this.set_u8("convertTime", this.get_u8("capture time"));
	this.set_u8("convertTeam", this.getTeamNum());
}

void onTick(CBlob@ this)
{
	if (!isServer()) return;
	
	u8 convertTime = this.get_u8("convertTime");
	u8 convertTeam = this.get_u8("convertTeam");
	
	const u8 capture_time = this.get_u8("capture time"); //time it takes to capture
	const u8 thisTeamNum = this.getTeamNum();
	u8 crewNum = 0;

	CBlob@[] blobsInRadius;
	getMap().getBlobsInRadius(this.getPosition(), capture_radius, @blobsInRadius);
	
	//use players in radius
	const u8 blobsLength = blobsInRadius.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ b = blobsInRadius[i];
		const u8 bTeamNum = b.getTeamNum();
		if (b.getName() == "human" && bTeamNum != thisTeamNum)
		{
			if (convertTeam == thisTeamNum) //claim attack cycle
				convertTeam = bTeamNum;
			if (convertTeam == bTeamNum) //attack
				crewNum++;
		}
	}
	
	if (crewNum > 0)
	{
		//start counting upwards
		convertTime = Maths::Max(0, convertTime - crewNum);
		this.getCurrentScript().tickFrequency = checkFrequency;
		
		if (convertTime <= 0)
		{
			//capture!
			this.server_setTeamNum(convertTeam);
		
			convertTime = capture_time;
			this.getCurrentScript().tickFrequency = checkFrequencyIdle;
		}
	}
	else if (convertTime < capture_time)
	{
		//start counting backwards
		convertTime++;
		this.getCurrentScript().tickFrequency = checkFrequency;
	}
	else if (convertTime >= capture_time)
	{
		//reset
		this.getCurrentScript().tickFrequency = checkFrequencyIdle;
		convertTeam = thisTeamNum;
	}
	
	if (convertTeam != this.get_u8("convertTeam"))
	{
		//sync convertTeam for use in onRender
		this.set_u8("convertTeam", convertTeam);
		this.Sync("convertTeam", true); //-1380000415 HASH
	}
	
	if (convertTime != this.get_u8("convertTime"))
	{
		//sync convertTime for use in onRender
		this.set_u8("convertTime", convertTime);
		this.Sync("convertTime", true); //-1321747407 HASH
	}
}
