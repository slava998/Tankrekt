//code from territory control

void onRender(CSprite@ this)
{
	CHUD@ hud = getHUD();
	hud.ShowCursor();
	
	CBlob@ blob = this.getBlob();
	if (blob !is null && blob.isMyPlayer())
	{
		if(blob.get_string("current tool") == "pistol")
		{
				if(!hud.hasMenus())hud.HideCursor();
				
				Vec2f CursorPos = blob.getAimPos();
				Vec2f AimPos = blob.getAimPos()-blob.getInterpolatedPosition();
				CursorPos.Normalize();
				CursorPos = CursorPos*AimPos.Length();
				
				Vec2f mouse_pos = getControls().getInterpMouseScreenPos();
				Vec2f virtual_pos = getDriver().getScreenPosFromWorldPos(blob.getInterpolatedPosition()+CursorPos);
				if((mouse_pos-virtual_pos).Length() < 8.0f)virtual_pos = mouse_pos;
				
				SColor Col = SColor(255,255,255,255);

				Render::SetTransformScreenspace();
				int AimSpace = 10;

				Vertex[] cross_height_vertex;
				for( int i = 0; i < 4; i += 1){
					
					float angle = i*90;
					
					Vec2f Dimensions = Vec2f(7,7);
					
					Vec2f TopLeft = Vec2f(-Dimensions.x/2,-Dimensions.y/2)*2;
					Vec2f TopRight = Vec2f(Dimensions.x/2,-Dimensions.y/2)*2;
					Vec2f BotLeft = Vec2f(-Dimensions.x/2,Dimensions.y/2)*2;
					Vec2f BotRight = Vec2f(Dimensions.x/2,Dimensions.y/2)*2;
					TopLeft.RotateByDegrees(angle);
					TopRight.RotateByDegrees(angle);
					BotLeft.RotateByDegrees(angle);
					BotRight.RotateByDegrees(angle);
					
					Vec2f DrawPos = Vec2f(AimSpace,0);
					DrawPos.RotateByDegrees(angle);
					
					DrawPos = mouse_pos+DrawPos;
				
					cross_height_vertex.push_back(Vertex(DrawPos.x+TopLeft.x, DrawPos.y+TopLeft.y, 1, 0, 1, Col)); //top left
					cross_height_vertex.push_back(Vertex(DrawPos.x+TopRight.x, DrawPos.y+TopRight.y, 1, 0.5, 1, Col)); //top right
					cross_height_vertex.push_back(Vertex(DrawPos.x+BotRight.x, DrawPos.y+BotRight.y,1, 0.5, 0, Col)); //bot right
					cross_height_vertex.push_back(Vertex(DrawPos.x+BotLeft.x, DrawPos.y+BotLeft.y,1, 0, 0, Col)); //bot left
				}
				Render::RawQuads("GunCrossHair.png",cross_height_vertex);
				
				cross_height_vertex.clear();
				for( int i = 0; i < 4; i += 1){
					
					float angle = i*90;
					
					Vec2f Dimensions = Vec2f(7,7);
					
					Vec2f TopLeft = Vec2f(-Dimensions.x/2,-Dimensions.y/2)*2;
					Vec2f TopRight = Vec2f(Dimensions.x/2,-Dimensions.y/2)*2;
					Vec2f BotLeft = Vec2f(-Dimensions.x/2,Dimensions.y/2)*2;
					Vec2f BotRight = Vec2f(Dimensions.x/2,Dimensions.y/2)*2;
					TopLeft.RotateByDegrees(angle);
					TopRight.RotateByDegrees(angle);
					BotLeft.RotateByDegrees(angle);
					BotRight.RotateByDegrees(angle);
					
					Vec2f DrawPos = Vec2f(AimSpace,0);
					DrawPos.RotateByDegrees(angle);
					
					DrawPos = mouse_pos+DrawPos;
					
					cross_height_vertex.push_back(Vertex(DrawPos.x+TopLeft.x, DrawPos.y+TopLeft.y, 1, 0.5, 1, Col)); //top left
					cross_height_vertex.push_back(Vertex(DrawPos.x+TopRight.x, DrawPos.y+TopRight.y, 1, 1, 1, Col)); //top right
					cross_height_vertex.push_back(Vertex(DrawPos.x+BotRight.x, DrawPos.y+BotRight.y,1, 1, 0, Col)); //bot right
					cross_height_vertex.push_back(Vertex(DrawPos.x+BotLeft.x, DrawPos.y+BotLeft.y,1, 0.5, 0, Col)); //bot left
				}
				Render::RawQuads("GunCrossHair.png",cross_height_vertex);
				
				int Skip = 1;
				bool angled = false;
				int ammo = blob.get_u8("ammo");
				int maxammo = ammo;
				
					if(blob.get_u8("clip_size") >= 50) {
						Skip = Maths::Floor(blob.get_u8("clip_size")/50);
						angled = true;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
					}
				
					maxammo = blob.get_u8("clip_size");

					if (blob.get_bool("currently_reloading"))
					{
						f32 mod = 0;

						//Reloading sequence
						
						u32 endTime = blob.get_u16("reloading_time");
						u32 startTime = getGameTime() - blob.get_u32("fire time");
						ammo = f32(maxammo)*f32(startTime) / f32(endTime);
						
						//if(maxammo < 3){
						//	maxammo = 8;
						//	ammo = f32(8)*f32(startTime) / f32(endTime);
						//}
					}
				
				Vertex[] bullet_vertex;
				for( int i = 0; i < ammo; i += Skip){
					
					float angle = i*360/maxammo-90.0f;
					
					Vec2f Dimensions = Vec2f(5,5);
					
					Vec2f TopLeft = Vec2f(-Dimensions.x/2,-Dimensions.y/2)*2;
					Vec2f TopRight = Vec2f(Dimensions.x/2,-Dimensions.y/2)*2;
					Vec2f BotLeft = Vec2f(-Dimensions.x/2,Dimensions.y/2)*2;
					Vec2f BotRight = Vec2f(Dimensions.x/2,Dimensions.y/2)*2;
					if(angled){
						TopLeft.RotateByDegrees(angle);
						TopRight.RotateByDegrees(angle);
						BotLeft.RotateByDegrees(angle);
						BotRight.RotateByDegrees(angle);
					}
					
					Vec2f DrawPos = Vec2f(AimSpace+10,0);
					DrawPos.RotateByDegrees(angle);
					
					DrawPos = mouse_pos+DrawPos;
				
					bullet_vertex.push_back(Vertex(DrawPos.x+TopLeft.x, DrawPos.y+TopLeft.y, 1, 0, 1, Col)); //top left
					bullet_vertex.push_back(Vertex(DrawPos.x+TopRight.x, DrawPos.y+TopRight.y, 1, 1, 1, Col)); //top right
					bullet_vertex.push_back(Vertex(DrawPos.x+BotRight.x, DrawPos.y+BotRight.y,1, 1, 0, Col)); //bot right
					bullet_vertex.push_back(Vertex(DrawPos.x+BotLeft.x, DrawPos.y+BotLeft.y,1, 0, 0, Col)); //bot left
				}
				Render::RawQuads("GunAmmoPip.png",bullet_vertex);
		}
	}
}
