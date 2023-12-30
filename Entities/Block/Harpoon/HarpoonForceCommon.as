//Common file for getting forces from a propeller

#include "ShipsCommon.as";

shared void HarpoonForces(CBlob@ this, CBlob@ hitBlob, Ship@ ship, Vec2f&out moveVel, float&out angleVel)
{
	Vec2f pos = this.getPosition();

	moveVel = -(hitBlob.getPosition() - pos);
	moveVel.Normalize();
	Vec2f moveNorm = moveVel;
	const f32 moveSpeed = moveNorm.Normalize();

	// calculate "proper" force

	Vec2f fromCenter = pos - ship.pos;
	const f32 fromCenterLen = fromCenter.Normalize();
	const f32 directionMag = Maths::Abs(fromCenter * moveNorm);
	const f32 dist = 35.0f;
	const f32 harpoonLength = (hitBlob.getPosition() - pos).getLength();
	const f32 centerMag = (dist - Maths::Min(dist, fromCenterLen))/dist;
	const f32 velCoef = (directionMag + centerMag)*0.5f + Maths::Pow(harpoonLength - harpoon_grapple_length, 2);

	moveVel *= velCoef;

	const f32 turnDirection = Vec2f(moveNorm.y, -moveNorm.x) * fromCenter;
	const f32 angleCoef = (1.0f - velCoef) * (1.0f - directionMag) * turnDirection;
	angleVel = angleCoef * moveSpeed;
}
