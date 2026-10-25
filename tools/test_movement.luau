--!nonstrict
-- Deterministic component/integration tests; Studio remains necessary for contact/visual QA.
local checks = 0
local function check(value, label)
	assert(value, label)
	checks += 1
end
local function near(a, b) return math.abs(a - b) < 0.001 end
local function signal()
	local listeners = {}
	return { Connect = function(_, fn) table.insert(listeners, fn); return { Disconnect = function() end } end,
		Once = function(_, _fn) end, Fire = function(_, ...) for _, fn in listeners do fn(...) end end }
end
local Enum = setmetatable({}, { __index = function(groups, group)
	local values = setmetatable({}, { __index = function(items, name)
		local value = { Name = name, Value = 3000 }
		rawset(items, name, value)
		return value
	end })
	rawset(groups, group, values)
	return values
end })
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z or 0 }, vmt) end
vmt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2)
	elseif key == "Unit" then return v / v.Magnitude
	elseif key == "Dot" then return function(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
	elseif key == "Lerp" then return function(a, b, t) return a + (b-a)*t end end
end
vmt.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__unm = function(a) return vec(-a.X,-a.Y,-a.Z) end
vmt.__mul = function(a,b) if type(a)=="number" then a,b=b,a end; return vec(a.X*b,a.Y*b,a.Z*b) end
vmt.__div = function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
local Vector3 = { new = vec, zero = vec(0,0,0), xAxis = vec(1,0,0), yAxis = vec(0,1,0), zAxis = vec(0,0,1) }
local Vector2 = { new = vec, zero = vec(0,0,0) }
local cmt = { __mul = function(a,_b) return a end }
local function frame() return setmetatable({ LookVector = vec(0,0,-1), RightVector = vec(1,0,0) }, cmt) end
local CFrame = { identity = frame(), new = frame, lookAt = frame, Angles = frame }
local function identity(...) return { ... } end
local Color3 = { fromRGB = identity }
local ColorSequence = { new = identity }
local NumberSequence = { new = identity }
local NumberSequenceKeypoint = { new = identity }
local NumberRange = { new = identity }
local TweenInfo = { new = identity }
local UDim2 = { new = identity, fromScale = identity, fromOffset = identity }
local UDim = { new = identity }
local RaycastParams = { new = function() return {} end }
local function instance(class)
	local obj = { ClassName = class, Size = vec(2,2,1), C0 = frame(), Position = vec(0,4,0),
		InputBegan = signal(), InputEnded = signal(), Destroying = signal(), DescendantAdded = signal(), Children = {}, AbsoluteSize = vec(800,600), PropertySignals = {} }
	function obj:IsA(kind) return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part") end
	function obj:Destroy() self.Destroyed = true; self.Parent = nil end
	function obj:FindFirstChild(name) return self.Children[name] end
	function obj:FindFirstChildOfClass(kind) for _, child in self.Children do if child.ClassName==kind then return child end end; return nil end
	function obj:WaitForChild(name) return self.Children[name] end
	function obj:GetPropertyChangedSignal(name) self.PropertySignals[name] = self.PropertySignals[name] or signal(); return self.PropertySignals[name] end
	function obj:GetChildren() local out = {};for _,c in self.Children do table.insert(out,c) end;return out end
	function obj:GetDescendants() local out={};for _,c in self.Children do table.insert(out,c);for _,d in c:GetDescendants() do table.insert(out,d)end end;return out end
	function obj:FindFirstAncestor(name) local p=self.Parent;while p do if p.Name==name then return p end;p=p.Parent end;return nil end
	function obj:GetAttribute(name) return self.Attributes and self.Attributes[name] end
	return obj
end
local Instance = { new = instance }
local registry = { WorldStateController = {}, CameraController = {} }
local folder = { WaitForChild = function(self, name) return if name == "AsurasPath" or name == "Simulation" or name == "Shared" then self else name end }
-- Resolve replicated dependencies against the actual Rojo hierarchy, not a permissive mock.
local function tree(children)
	children.WaitForChild = function(_, name) return assert(children[name], "Missing replicated child: " .. name) end
	return children
end
local replicated = tree({}) -- REPLICATION_INSERT
local script = { Parent = folder }
local require = function(name) return assert(registry[name], tostring(name)) end
local playerGui = instance("PlayerGui")
local player = { WaitForChild = function() return playerGui end, Attributes = {} }
function player:SetAttribute(key, value) self.Attributes[key] = value end
local ray = { Normal = Vector3.yAxis }
local workspace = { Gravity = 196.2, CurrentCamera = { CFrame = frame(), ViewportSize = vec(1920,1080) },
	Raycast = function() return ray end, GetServerTimeNow = function() return os.clock() end }
local UIS = { TouchEnabled = false, KeyboardEnabled = true, Focus = nil,
	GetFocusedTextBox = function(self) return self.Focus end, GetMouseDelta = function() return Vector2.zero end,
	Keys = {}, IsKeyDown = function(self, key) return self.Keys[key] == true end }
for _, name in { "WindowFocused", "WindowFocusReleased", "TextBoxFocused", "LastInputTypeChanged", "InputBegan", "InputEnded", "InputChanged" } do UIS[name] = signal() end
local propertySignals = {}
function UIS:GetPropertyChangedSignal(key) propertySignals[key] = propertySignals[key] or signal();return propertySignals[key]end
function UIS:GetLastInputType() return Enum.UserInputType.Keyboard end
local guiService = { MenuOpened = signal(), MenuIsOpen = false }
local CAS = { Actions = {}, BindActionAtPriority = function(self, name, fn, _touch, _priority, ...)
	self.Actions[name] = { Callback = fn, Inputs = { ... } }
end, UnbindAction = function(self, name) self.Actions[name] = nil end }
local debris = { AddItem = function() end }
local tween = { Create = function() return { Play = function() end } end }
local services = { Players = { LocalPlayer = player }, Workspace = workspace, ReplicatedStorage = replicated,
	UserInputService = UIS, GuiService = guiService, ContextActionService = CAS,
	ProximityPromptService = { PromptShown = signal(), PromptHidden = signal() }, Debris = debris, TweenService = tween }
local game = { GetService = function(_, name) return assert(services[name], name) end }
registry.HudKit = { bindScale = function() return function() end end }
-- MODULES_INSERT
local function character()
	local model, root, humanoid, torso, joint = instance("Model"), instance("Part"), instance("Humanoid"), instance("Part"), instance("Motor6D")
	model.Parent, root.Parent, humanoid.Parent, joint.Parent = workspace, model, model, model
	model.Children = { HumanoidRootPart = root, Humanoid = humanoid, UpperTorso = torso, Waist = joint }
	humanoid.Health, humanoid.HipHeight, humanoid.AutoJumpEnabled = 100, 2, true
	humanoid.WalkSpeed, humanoid.MoveDirection, humanoid.FloorMaterial = 22.4, Vector3.xAxis, Enum.Material.Concrete
	humanoid.MaxSlopeAngle, humanoid.Sit, humanoid.PlatformStand = 50, false, false
	function humanoid:ChangeState(state) self.LastState = state; self.FloorMaterial = Enum.Material.Air end
	root.AssemblyLinearVelocity, root.CFrame = vec(30,0,0), frame()
	player.Character = model
	return model, root, humanoid
end
local snapshot = { State = "Idle" }
local world = { DashEnds = 0, OwnSnapshot = function() return snapshot end }
local camera = { Camera = workspace.CurrentCamera, FovPunch = { Value = 0 },
	SetMovement = function(self, glide, slide, turn) self.Glide, self.Slide, self.Turn = glide, slide, turn end,
	Impulse = function(self) self.Rumbles = (self.Rumbles or 0)+1 end }
local Movement, Motion = registry.MovementController, registry.MovementMath
local model, root, humanoid = character()
local move = Movement.new(world, camera)
move:Press("Jump")
check(humanoid.LastState == Enum.HumanoidStateType.Jumping and not move.DoubleUsed, "ordinary jump stays independent of dash")
move:Step(0.2)
check(move.State == "Gliding", "held jump enters glide")
move:Release("Jump"); move:Press("Jump")
check(move.DoubleUsed and near(root.AssemblyLinearVelocity.Y,50) and near(root.AssemblyLinearVelocity.X,25), "one double jump adds up/forward launch")
move:Step(0.2); move:Release("Jump"); root.AssemblyLinearVelocity = vec(1,-20,0); move:Press("Jump")
check(root.AssemblyLinearVelocity.Y == -20, "third jump cannot launch")
move:Release("Jump"); humanoid.FloorMaterial = Enum.Material.Concrete; move:Step(0.2)
check(not move.DoubleUsed and move.GlideTime == 0, "landing replenishes air resources")
humanoid.MoveDirection = Vector3.zero; move:Press("Slide")
check(move.State == "Grounded" and near(humanoid.HipHeight,1.4), "stationary crouch lowers posture")
move:Release("Slide"); humanoid.MoveDirection = Vector3.xAxis
root.AssemblyLinearVelocity = vec(40,0,0); move:Press("Slide")
check(move.State == "Sliding" and near(move.SlideSpeed,56) and near(humanoid.HipHeight,1.4), "slide adds forty percent and lowers stance")
move:Step(0.1)
check(root.AssemblyLinearVelocity.Magnitude < 56 and root.AssemblyLinearVelocity.Magnitude > 50, "flat slide decays with friction")
local momentum = root.AssemblyLinearVelocity.Magnitude
move:Release("Slide")
check(move.State == "Grounded" and humanoid.HipHeight == 2 and near(root.AssemblyLinearVelocity.Magnitude,momentum), "slide cancel restores height and preserves momentum")
local _, down = Motion.slide(Vector3.xAxis,40,vec(0.5,0.866,0).Unit,Vector3.xAxis,196.2,0.1)
local _, up = Motion.slide(Vector3.xAxis,40,vec(-0.5,0.866,0).Unit,Vector3.xAxis,196.2,0.1)
check(down > 40 and up < 40, "slopes gain speed downhill and lose speed uphill")
for _, fps in {30,60,120} do
	local speed = 40
	for _=1,fps do local _dir; _dir,speed = Motion.slide(Vector3.xAxis,speed,Vector3.yAxis,Vector3.xAxis,196.2,1/fps) end
	check(near(speed,26), "friction is frame rate independent")
end
move:Press("Slide")
for index=1,6 do
	ray = if index%2==0 then {Normal=Vector3.yAxis} else nil
	humanoid.FloorMaterial = if ray then Enum.Material.Concrete else Enum.Material.Air
	move:Step(0.05)
	check(move.State == "Sliding" and move.SlideSpeed > 20, "stair contact gaps keep slide momentum")
end
ray = nil; humanoid.FloorMaterial = Enum.Material.Air; move:Step(0.2)
check(move.State == "Airborne", "leaving a ledge ends slide after grace")
ray = {Normal=Vector3.yAxis}; humanoid.FloorMaterial = Enum.Material.Concrete; move:Release("Slide"); move:Step(0.2)
move:Press("Slide"); move:Press("Jump")
check(move.State == "BulletJumping" and near(root.AssemblyLinearVelocity.Magnitude,75) and root.AssemblyLinearVelocity.Y>0, "slide jump launches camera-directed bullet jump")
check(humanoid.HipHeight == 2 and camera.FovPunch.Value == 10 and camera.Rumbles == 1, "bullet launch restores hip and punches camera")
move:Step(0.016)
check(move.State == "Gliding" and camera.Glide and move.Effects.Trails[1].Enabled, "bullet jump transitions immediately into wind-trail glide")
root.AssemblyLinearVelocity = vec(0,-100,-30); move:Step(0.016)
check(root.AssemblyLinearVelocity.Y == -6, "glide caps downward speed")
move:Release("Jump"); move:Release("Slide"); move:Step(0.05)
check(move.State == "Airborne" and not camera.Glide and not move.Effects.Trails[1].Enabled, "releasing glide restores normal gravity and effects")
local used = move.GlideTime
move:Press("Aim"); move:Step(0.05)
check(move.State == "Gliding" and move.GlideTime > used, "aim resumes existing glide budget")
for _=1,40 do move:Step(0.1) end
check(near(move.GlideTime,3.5) and move.State == "Airborne", "glide expires at 3.5 cumulative seconds")
move:Release("Aim"); move:Press("Aim"); move:Step(0.1)
check(move.State == "Airborne", "repeated aim cannot refill glide in the air")
local v = Motion.glide(vec(30,18,0),vec(0,0,-1),0.1)
check(v.Y==18 and v.Z<0, "camera steering preserves ascent")
move:SetEnabled(false); local before = root.AssemblyLinearVelocity; move:Press("Jump")
check(root.AssemblyLinearVelocity == before and humanoid.HipHeight==2, "menu disables launches and restores posture")
local attachments = #move.Effects.Items
move:SetEnabled(true); move:Step(0.1)
check(#move.Effects.Items == attachments and attachments > 0, "menu cleanup preserves reusable effects")
snapshot.State = "Hitstun"; move:Press("Jump"); move:Step(0.1)
check(root.AssemblyLinearVelocity == before and move.State == "Airborne", "hitstun stops assisted movement")
snapshot.State = "Idle"; world.DashEnds = os.clock()+10; move:Press("Aim"); move:Step(0.1)
check(root.AssemblyLinearVelocity == before, "server dash velocity takes precedence")
world.DashEnds = 0; move:Release("Aim"); humanoid.FloorMaterial=Enum.Material.Concrete; move:Step(0.2); move:Press("Slide")
model.Attributes = { RootUntil = workspace:GetServerTimeNow()+5 }
move:Step(0.1)
check(move.State == "Grounded" and humanoid.HipHeight==2, "server root effects cancel assisted locomotion")
model.Attributes = nil
local oldHumanoid = humanoid
model,root,humanoid = character(); move:Step(0.1)
check(oldHumanoid.HipHeight==2 and oldHumanoid.AutoJumpEnabled and not move.DoubleUsed and move.GlideTime==0, "respawn cleans old rig and air state")
-- Real input mappings, CAS callback and touch button events, with the real InputBuffer.
function world:Own() return { Humanoid = humanoid } end
local sent = {}
local input = registry.InputController.new(world,camera,function(action) table.insert(sent,action) end,move)

-- Capability changes may arrive without LastInputTypeChanged (Studio emulator and hot-plugging).
UIS.TouchEnabled,UIS.KeyboardEnabled=true,false
UIS:GetPropertyChangedSignal("TouchEnabled"):Fire()
check(input.Device=="Touch" and input.TouchGui.Enabled,"phone capability change enables touch without an input edge")
UIS.TouchEnabled,UIS.KeyboardEnabled=false,true
UIS:GetPropertyChangedSignal("TouchEnabled"):Fire()
check(input.Device=="Keyboard" and not input.TouchGui.Enabled,"return to keyboard capabilities restores desktop input")
local lastCommand
input.OnCommand = function(command) lastCommand = command end
local binding = CAS.Actions.AsuraKineticMovement
local function action(key, state, kind)
	return binding.Callback("AsuraKineticMovement",state,{KeyCode=key,UserInputType=kind or Enum.UserInputType.Keyboard})
end
check(table.find(binding.Inputs,Enum.KeyCode.Space) and table.find(binding.Inputs,Enum.KeyCode.ButtonA), "jump owns keyboard and gamepad action")
action(Enum.KeyCode.Space,Enum.UserInputState.Begin); action(Enum.KeyCode.Space,Enum.UserInputState.End); input:Step(0.01)
check(#sent==0 and humanoid.LastState==Enum.HumanoidStateType.Jumping, "Space does not send roll or dash")
for _, key in { Enum.KeyCode.LeftShift,Enum.KeyCode.Q,Enum.KeyCode.ButtonB } do
	action(key,Enum.UserInputState.Begin,if key==Enum.KeyCode.ButtonB then Enum.UserInputType.Gamepad1 else nil)
	check(lastCommand == "Dash" and table.find(binding.Inputs,key), "each dedicated evade key is bound to Dash")
	input:Step(0.01)
end
check(sent[1]=="Dash" and not table.find(sent,"Roll"), "dedicated evade inputs send server-validated Dash")
action(Enum.KeyCode.ButtonL2,Enum.UserInputState.Begin,Enum.UserInputType.Gamepad1)
check(move.AimHeld,"gamepad L2 holds aim instead of roll")
action(Enum.KeyCode.ButtonL2,Enum.UserInputState.End,Enum.UserInputType.Gamepad1)
check(not move.AimHeld,"gamepad trigger release stops aim")
input.TouchButtons.Jump.InputBegan:Fire({UserInputType=Enum.UserInputType.Touch})
check(move.JumpHeld and input.TouchButtons.Dash.Text=="DASH", "separate touch Jump and Dash controls")
input.TouchButtons.Jump.InputEnded:Fire({UserInputType=Enum.UserInputType.Touch})
input:SetMenu(true)
check(not move.Enabled and not move.JumpHeld,"menu releases held touch movement")
input:SetMenu(false)
-- F03: Respite closed over Lin's dialogue used to hand every key back while she was still talking.
input:SetMenu(true, "Dialogue"); input:SetMenu(true, "Pause"); input:SetMenu(false, "Pause")
table.clear(sent); input:Press("Swap"); input:Press("Interact")
check(input.MenuOpen and not move.Enabled and #sent == 0, "closing one window keeps input with the dialogue still open")
-- F03: B is both Dash and every window's back button; sinking it left Lin's "[B] leave" dead on a pad.
check(action(Enum.KeyCode.ButtonB,Enum.UserInputState.Begin,Enum.UserInputType.Gamepad1) == Enum.ContextActionResult.Pass,
	"an open window receives B unprocessed for its back button")
check(action(Enum.KeyCode.Space,Enum.UserInputState.Begin) == Enum.ContextActionResult.Sink, "other movement keys stay sunk under a window")
action(Enum.KeyCode.Space,Enum.UserInputState.End)
input:SetMenu(false, "Dialogue"); input:Press("Swap")
check(not input.MenuOpen and move.Enabled and sent[1] == "Swap", "input returns once the last window closes")
check(action(Enum.KeyCode.ButtonB,Enum.UserInputState.Begin,Enum.UserInputType.Gamepad1) == Enum.ContextActionResult.Sink and lastCommand == "Dash",
	"with no window open B is Dash again")
input:Step(0.01); table.clear(sent)
table.clear(sent); UIS.Focus = {}; input:Step(0.01)
check(not move.Enabled,"typing blocks movement")
UIS.Focus=nil; input:Step(0.01); UIS.WindowFocusReleased:Fire()
check(not move.JumpHeld and not move.AimHeld and not move.SlideHeld,"focus loss releases held movement")
-- Alt frees the cursor only while held: a lone Alt press from Alt-Tab must not leave mouse look dead.
UIS.Keys[Enum.KeyCode.LeftAlt] = true; input:Press("Cursor"); input:Step(0.01)
check(input.CursorFree and UIS.MouseBehavior == Enum.MouseBehavior.Default, "holding Alt frees the cursor")
UIS.Keys[Enum.KeyCode.LeftAlt] = nil; input:Step(0.01)
check(not input.CursorFree and UIS.MouseBehavior == Enum.MouseBehavior.LockCenter, "an Alt press whose release never arrives does not stick")
UIS.Keys[Enum.KeyCode.LeftAlt] = true; input:Press("Cursor"); input:Release("Cursor")
check(not input.CursorFree, "releasing Alt recaptures the mouse")
input:Press("Cursor"); UIS.WindowFocused:Fire(); UIS.Keys[Enum.KeyCode.LeftAlt] = nil
check(not input.CursorFree, "regaining window focus recaptures the mouse")
move:Destroy(); input:Destroy()
check(humanoid.AutoJumpEnabled and humanoid.HipHeight==2 and #move.Effects.Items==0,"destroy restores rig and removes all effects")
print("PASS: "..checks.." kinetic movement/input/effects assertions (engine fakes; Studio contact QA separate)")
