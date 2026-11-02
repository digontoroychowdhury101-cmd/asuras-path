--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/FootStep
-- Combat footwork as a contact state machine (combat recovery Stage 3, TIMING_CONTRACT §9 T-FW): each foot is either
-- planted at one world point or swinging to its next one, whichever way the body travels, so strafing, backing,
-- turning on the spot and low-speed shuffles need no reversed cycle and a planted foot cannot skate. Pure numbers;
-- ActorPose turns the result into joint transforms.
-- Concepts adapted (see THIRD_PARTY_NOTICES.md): Overgrowth aschar.as HandleFootStance @ 245fe48 (a foot lifts when
-- the planted point falls behind its target, the foot facing away from travel first, feet alternate, target leads
-- velocity); ALS-Refactored RefreshFootLock @ b754d6f (a lock may fall or jump to 1 but never blend in partway; a new
-- lock captures where the foot is now); Orange Duck controller.cpp contact_update @ 57b7250 (unlock radius).
local Foot = {}

Foot.PLANT_RADIUS = 0.3 -- a slow body lets the planted point fall this far from neutral before stepping
Foot.MIN_SWING, Foot.MAX_SWING = 0.075, 0.2
Foot.MAX_LIFT = 0.5
Foot.TURN_LIMIT = math.rad(40) -- a planted foot turns this far from its neutral yaw before it must step
Foot.UNLOCK_RADIUS = 3.0 -- past this the point is unreachable (teleport, knockback): the lock lets go
Foot.TELEPORT = 12 -- studs of neutral movement in one frame: re-seat, never swing across it
Foot.RELEASE_RATE = 12 -- lock amount lost per second when released (swing of a dodge, airborne, death)

export type FootState = {
	Swinging: boolean,
	X: number, Y: number, Z: number, Yaw: number, -- where the foot is
	FromX: number, FromY: number, FromZ: number, FromYaw: number,
	ToX: number, ToY: number, ToZ: number, ToYaw: number,
	T: number, Duration: number, Lift: number,
	Lock: number, -- 0 = the clip's foot, 1 = this contact state
}

export type State = { Left: FootState, Right: FootState, Seeded: boolean, LastLeftX: number, LastLeftZ: number, Next: "Left" | "Right", SinceLift: number }

-- One frame's input, in world space. (X, Z, Yaw) is where the clip wants the foot now; Ground is that point's height.
export type Input = {
	LeftX: number, LeftZ: number, LeftYaw: number, LeftGround: number,
	RightX: number, RightZ: number, RightYaw: number, RightGround: number,
	VX: number, VZ: number,
	Scale: number,
	Release: boolean, -- airborne, dodge, teleport, death: feet follow the clip
}

local function newFoot(): FootState
	return { Swinging = false, X = 0, Y = 0, Z = 0, Yaw = 0, FromX = 0, FromY = 0, FromZ = 0, FromYaw = 0, ToX = 0, ToY = 0, ToZ = 0, ToYaw = 0,
		T = 0, Duration = 0.1, Lift = 0, Lock = 0 }
end

function Foot.new(): State
	return { Left = newFoot(), Right = newFoot(), Seeded = false, LastLeftX = 0, LastLeftZ = 0, Next = "Left", SinceLift = 0 }
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function seat(foot: FootState, x: number, y: number, z: number, yaw: number)
	foot.Swinging, foot.X, foot.Y, foot.Z, foot.Yaw, foot.T = false, x, y, z, yaw, 0
end

-- The planted point's lead ahead of neutral and the swing's length for this speed: wider strides as the body speeds
-- up, narrower across the body so a strafe never crosses the legs.
function Foot.stride(speed: number, scale: number): (number, number)
	local half = math.clamp(0.25 + speed * 0.055, 0.25, 1.5) * scale
	local swing = math.clamp(half / math.max(speed, 1e-3), Foot.MIN_SWING, Foot.MAX_SWING)
	return half, swing
end

local function lift(foot: FootState, x: number, z: number, ground: number, yaw: number, swing: number, scale: number)
	foot.Swinging, foot.T, foot.Duration = true, 0, swing
	foot.FromX, foot.FromY, foot.FromZ, foot.FromYaw = foot.X, foot.Y, foot.Z, foot.Yaw
	foot.ToX, foot.ToY, foot.ToZ, foot.ToYaw = x, ground, z, yaw
	local distance = math.sqrt((x - foot.X) ^ 2 + (z - foot.Z) ^ 2)
	foot.Lift = math.min(Foot.MAX_LIFT, distance * 0.3) * scale
end

local function advance(foot: FootState, dt: number, x: number, z: number, ground: number, yaw: number, leadX: number, leadZ: number)
	if not foot.Swinging then
		return
	end
	foot.T = math.min(foot.T + dt / foot.Duration, 1)
	-- The landing keeps tracking the neutral point: the body has moved on since the foot lifted.
	foot.ToX, foot.ToZ, foot.ToY, foot.ToYaw = x + leadX, z + leadZ, ground, yaw
	local u = foot.T * foot.T * (3 - 2 * foot.T)
	foot.X = foot.FromX + (foot.ToX - foot.FromX) * u
	foot.Z = foot.FromZ + (foot.ToZ - foot.FromZ) * u
	foot.Y = foot.FromY + (foot.ToY - foot.FromY) * u + math.sin(math.pi * foot.T) * foot.Lift
	foot.Yaw = foot.FromYaw + wrap(foot.ToYaw - foot.FromYaw) * u
	if foot.T >= 1 then
		seat(foot, foot.ToX, foot.ToY, foot.ToZ, foot.ToYaw)
	end
end

-- Advances both feet one frame. Each foot's result is its X, Y, Z, Yaw and Lock fields.
function Foot.update(state: State, input: Input, dt: number)
	local left, right = state.Left, state.Right
	state.SinceLift += dt
	local jump = math.sqrt((input.LeftX - state.LastLeftX) ^ 2 + (input.LeftZ - state.LastLeftZ) ^ 2)
	state.LastLeftX, state.LastLeftZ = input.LeftX, input.LeftZ
	if not state.Seeded or jump > Foot.TELEPORT * input.Scale then
		seat(left, input.LeftX, input.LeftGround, input.LeftZ, input.LeftYaw)
		seat(right, input.RightX, input.RightGround, input.RightZ, input.RightYaw)
		state.Seeded = true
	end
	if input.Release then
		-- A lock only falls while released; the next contact re-captures where the foot then is.
		left.Lock = math.max(0, left.Lock - Foot.RELEASE_RATE * dt)
		right.Lock = math.max(0, right.Lock - Foot.RELEASE_RATE * dt)
		seat(left, input.LeftX, input.LeftGround, input.LeftZ, input.LeftYaw)
		seat(right, input.RightX, input.RightGround, input.RightZ, input.RightYaw)
		return
	end
	-- Lock amount jumps to 1 on contact; there is no partial blend in (ActorPose's offset smooths the jump inertially).
	left.Lock, right.Lock = 1, 1
	local speed = math.sqrt(input.VX * input.VX + input.VZ * input.VZ)
	local half, swing = Foot.stride(speed, input.Scale)
	local leadX, leadZ, cadence = 0, 0, 0
	if speed > 0.5 then
		-- Land far enough ahead that the stance is centred under the hip when the foot arrives.
		local reach = half + speed * swing * 0.5
		leadX, leadZ = input.VX / speed * reach, input.VZ / speed * reach
		-- The feet stay half a stride apart in time, whatever they started from: two feet due together do not hop.
		cadence = 0.5 * (reach + half) / speed
	end
	advance(left, dt, input.LeftX, input.LeftZ, input.LeftGround, input.LeftYaw, leadX, leadZ)
	advance(right, dt, input.RightX, input.RightZ, input.RightGround, input.RightYaw, leadX, leadZ)
	-- A point the leg can no longer reach (knockback, a shove) lets go rather than stretching toward it.
	local unlock = Foot.UNLOCK_RADIUS * input.Scale
	if not left.Swinging and math.sqrt((left.X - input.LeftX) ^ 2 + (left.Z - input.LeftZ) ^ 2) > unlock then
		seat(left, input.LeftX, input.LeftGround, input.LeftZ, input.LeftYaw)
	end
	if not right.Swinging and math.sqrt((right.X - input.RightX) ^ 2 + (right.Z - input.RightZ) ^ 2) > unlock then
		seat(right, input.RightX, input.RightGround, input.RightZ, input.RightYaw)
	end

	local function due(foot: FootState, x: number, z: number, yaw: number): number
		if foot.Swinging then
			return -math.huge
		end
		local dx, dz = foot.X - x, foot.Z - z
		local behind = math.sqrt(dx * dx + dz * dz)
		if math.abs(wrap(foot.Yaw - yaw)) > Foot.TURN_LIMIT then
			behind = math.max(behind, Foot.PLANT_RADIUS * input.Scale * 1.01)
		end
		return behind
	end
	local threshold = math.max(Foot.PLANT_RADIUS * input.Scale, if speed > 0.5 then half else 0)
	local leftDue = due(left, input.LeftX, input.LeftZ, input.LeftYaw)
	local rightDue = due(right, input.RightX, input.RightZ, input.RightYaw)
	local leftOver, rightOver = leftDue > threshold, rightDue > threshold
	if not (leftOver or rightOver) or state.SinceLift < cadence then
		return
	end
	local overrun = threshold * 1.5
	local function step(side: "Left" | "Right")
		state.SinceLift = 0
		if side == "Left" then
			lift(left, input.LeftX + leadX, input.LeftZ + leadZ, input.LeftGround, input.LeftYaw, swing, input.Scale)
			state.Next = "Right"
		else
			lift(right, input.RightX + leadX, input.RightZ + leadZ, input.RightGround, input.RightYaw, swing, input.Scale)
			state.Next = "Left"
		end
	end
	if left.Swinging or right.Swinging then
		-- One foot in the air: the other waits unless the body has outrun it (a run has a flight phase).
		if leftOver and leftDue > overrun then
			step("Left")
		elseif rightOver and rightDue > overrun then
			step("Right")
		end
	elseif leftOver and rightOver then
		-- Both due: the one further behind goes, ties alternate.
		if math.abs(leftDue - rightDue) < 0.05 then
			step(state.Next)
		else
			step(if leftDue > rightDue then "Left" else "Right")
		end
	else
		step(if leftOver then "Left" else "Right")
	end
end

return table.freeze(Foot)
