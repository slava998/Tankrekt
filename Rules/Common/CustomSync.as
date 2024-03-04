//Rewritten variable synchronisation - vanilla ones are buggy
//The sync code itself is in CustomSyncCMDRecieve

shared void SyncU8(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(0); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_u8(b.get_u8(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}

shared void SyncU16(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(1); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_u16(b.get_u16(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}

shared void SyncU32(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(2); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_u32(b.get_u32(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}

shared void SyncF32(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(3); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_f32(b.get_f32(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}

shared void SyncBool(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(4); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_bool(b.get_bool(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}

shared void SyncString(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(5); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_string(b.get_string(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}

shared void SyncTag(const u32 blobID, const string var)
{
	if(blobID <= 0) return; //if id is <= 0 the blob is definetly null
	CBlob@ b = getBlobByNetworkID(blobID);
	if(b is null) return;
	CRules@ rules = getRules();
	CBitStream params;
	params.write_u8(6); //command number
	params.write_string(var);
	params.write_netid(blobID);
	params.write_bool(b.hasTag(var));
	rules.SendCommand(rules.getCommandID("Csync"), params);
}