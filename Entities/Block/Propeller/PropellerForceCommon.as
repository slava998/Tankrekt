//Common file for getting forces from a propeller

#include "ShipsCommon.as";

const f32 PROPELLER_SPEED = 0.9f; //0.9f
const f32 ENGINE_BOOST = 2.0f; //actual value is 0.2, divided by 10

shared void PropellerForces(CBlob@ this, Ship@ ship, const f32&in power, Vec2f&out moveVel, Vec2f&out moveNorm, f32&out angleVel)
{

	moveVel = Vec2f(0.0f, (PROPELLER_SPEED + (ENGINE_BOOST * ship.engineblockcount) / 10) * power).RotateBy(this.getAngleDegrees());
	moveNorm = moveVel;
	const f32 moveSpeed = moveNorm.Normalize();

	// calculate "proper" force

	Vec2f fromCenter = this.getPosition() - ship.pos;
	const f32 fromCenterLen = fromCenter.Normalize();
	const f32 dist = 35.0f;
	const f32 centerMag = (dist - Maths::Min(dist, fromCenterLen))*0.0285f; //magic number?
	const f32 directionMag = ship.blocks.length > 2 ? Maths::Abs(fromCenter * moveNorm) : 1.0f; //how "aligned" it is from center
	const f32 velCoef = (directionMag + centerMag)*0.5f;

	moveVel *= velCoef;

	const f32 dragFactor = Maths::Max(0.2f, 1.1f - 0.005f * ship.blocks.length);
	const f32 turnDirection = Vec2f(dragFactor * moveNorm.y, dragFactor * -moveNorm.x) * fromCenter; //how "disaligned" it is from center
	const f32 angleCoef = (1.0f - velCoef) * (1.0f - directionMag) * turnDirection;
	angleVel = (angleCoef * moveSpeed)*1.2; // rotating tank is slow so small buff shouldn`t destroy balance
}