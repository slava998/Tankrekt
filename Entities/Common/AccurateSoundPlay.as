//rotates sound positions around the camera since kag engine doesn't do the adjustment for us
shared void directionalSoundPlay(const string&in soundName, Vec2f&in soundPos, f32&in volume = 1.0f, const f32&in pitch = 1.0f)
{
	volume *= 0.75f;
	CCamera@ camera = getCamera();
	if (camera !is null)
	{
		Vec2f camPos = camera.getPosition();
		Vec2f camVec = soundPos - camPos;
		camVec.RotateBy(-camera.getRotation());
		Sound::Play(soundName, camPos + camVec, volume, pitch);
	}
	else
		Sound::Play(soundName, soundPos, volume, pitch);
}
