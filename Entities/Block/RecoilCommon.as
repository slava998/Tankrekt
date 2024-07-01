shared void RecoilForces(CBlob@ this, Vec2f aim, Ship@ ship, const f32&in power)
{
	aim.Normalize();
	Vec2f moveVel = -(aim * power);
	Vec2f moveNorm = moveVel;
	const f32 moveSpeed = moveNorm.Normalize();

	// calculate "proper" force

	Vec2f fromCenter = this.getPosition() - ship.pos;
	const f32 fromCenterLen = fromCenter.Normalize();
	const f32 dist = 35.0f;
	const f32 centerMag = (dist - Maths::Min(dist, fromCenterLen))*0.0285f; //magic number?
	const f32 directionMag = ship.blocks.length > 2 ? Maths::Abs(fromCenter * aim) : 1.0f; //how "aligned" it is from center
	const f32 velCoef = (directionMag + centerMag)*0.5f;

	moveVel *= velCoef;

	const f32 dragFactor = Maths::Max(0.2f, 1.1f - 0.005f * ship.blocks.length);
	const f32 turnDirection = Vec2f(dragFactor * aim.y, dragFactor * -aim.x) * fromCenter; //how "disaligned" it is from center
	const f32 angleCoef = (1.0f - velCoef) * (1.0f - directionMag) * turnDirection;
	f32 angleVel = (angleCoef * moveSpeed);
	
	//apply vel change
	ship.vel += moveVel/ship.mass;
	ship.angle_vel += angleVel/ship.mass;
}

// put this code in fire the function to add recoil
// remember to include recoilcecommon file and add RECOIL_POWER
 
// RecoilForces(this, ship, RECOIL_POWER);