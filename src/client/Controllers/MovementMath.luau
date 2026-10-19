--!strict
-- Stateless, frame-rate-independent movement tuning. Tested separately from Roblox physics.
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared"):WaitForChild("CombatSettings") :: ModuleScript).Movement
local Motion = {}

function Motion.flat(value: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(value.X, 0, value.Z)
	return if flat.Magnitude > 0.001 then flat.Unit else fallback
end

function Motion.bullet(look: Vector3): Vector3
	return (look * 1.35 + Vector3.new(0, 0.75, 0)).Unit * Settings.BulletSpeed
end

function Motion.doubleJump(move: Vector3): Vector3
	return Vector3.new(0, Settings.DoubleJumpUp, 0) + move * Settings.DoubleJumpForward
end

function Motion.slide(direction: Vector3, speed: number, normal: Vector3, move: Vector3, gravity: number, dt: number): (Vector3, number, Vector3)
	local steered = direction:Lerp(Motion.flat(move, direction), 1 - math.exp(-3 * dt))
	direction = Motion.flat(steered, direction)
	local tangent = direction - normal * direction:Dot(normal)
	tangent = if tangent.Magnitude > 0.001 then tangent.Unit else direction
	local slope = Vector3.new(0, -gravity, 0):Dot(tangent)
	speed = math.clamp(speed + (slope - Settings.SlideFriction) * dt, 0, Settings.SlideMaxSpeed)
	return direction, speed, tangent * speed
end

function Motion.glide(velocity: Vector3, look: Vector3, dt: number): Vector3
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local direction = Motion.flat(look, Motion.flat(horizontal, Vector3.zAxis))
	local target = direction * math.max(horizontal.Magnitude, Settings.WalkSpeed)
	local steered = horizontal:Lerp(target, 1 - math.exp(-Settings.GlideSteering * dt))
	return Vector3.new(steered.X, math.max(velocity.Y, -Settings.GlideFallSpeed), steered.Z)
end

return Motion
