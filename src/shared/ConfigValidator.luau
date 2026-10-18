--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ConfigValidator
-- Validation runs before the preview is replaced or runtime instances are allocated.
local Validator = {}
local function numberIn(value: any, minimum: number, maximum: number, name: string)
	assert(type(value)=="number" and value==value and value>=minimum and value<=maximum,
		name.." must be finite and between "..minimum.." and "..maximum)
end
local function vector(value: any, minimum: number, maximum: number, name: string)
	assert(type(value)=="table" and #value==3,name.." must have exactly three components")
	for index=1,3 do numberIn(value[index],minimum,maximum,name.."["..index.."]") end
end
function Validator.Validate(config: any)
	assert(type(config)=="table","Config must be a table")
	assert(config.Project.Phase>=5 and config.Project.Phase<=12,"This bootstrap implements Phase 5 through Phase 12")
	assert(config.Arena.Sides==8,"The current mat decomposition requires eight sides")
	local a=config.Arena
	numberIn(a.AcrossFlats,24,64,"Arena.AcrossFlats")
	numberIn(a.FloorThickness,0.1,3,"Arena.FloorThickness")
	numberIn(a.FenceHeight,6,14,"Arena.FenceHeight")
	numberIn(a.WireSpacing,0.75,3,"Arena.WireSpacing")
	numberIn(a.WireDiameter,0.025,0.1,"Arena.WireDiameter")
	numberIn(a.PostDiameter,0.2,1.5,"Arena.PostDiameter")
	numberIn(a.RailDiameter,0.1,0.8,"Arena.RailDiameter")
	numberIn(a.WallThickness,0.1,1,"Arena.WallThickness")
	numberIn(a.WireBottom,0.1,1,"Arena.WireBottom")
	numberIn(a.WireTopInset,0.1,1,"Arena.WireTopInset")
	numberIn(a.LowerRailHeight,0.1,1,"Arena.LowerRailHeight")
	numberIn(a.GateSide,1,8,"Arena.GateSide")
	assert(a.GateSide%1==0,"GateSide must be an integer")
	numberIn(a.GateWidth,2,5,"Arena.GateWidth")
	numberIn(a.GateBarDiameter,0.1,0.4,"Arena.GateBarDiameter")
	numberIn(a.GateLatchHeight,1,a.FenceHeight-1,"Arena.GateLatchHeight")
	numberIn(a.GateLatchLength,0.2,1,"Arena.GateLatchLength")
	numberIn(a.SpawnDistance,2,a.AcrossFlats/2-3,"Arena.SpawnDistance")
	vector(a.SpawnSize,0.1,4,"Arena.SpawnSize")
	numberIn(a.VoidWidth,120,240,"Arena.VoidWidth")
	numberIn(a.VoidHeight,60,120,"Arena.VoidHeight")
	numberIn(a.VoidCenterY,10,30,"Arena.VoidCenterY")
	numberIn(a.VoidWallThickness,0.5,3,"Arena.VoidWallThickness")
	numberIn(a.LightHeight,a.FenceHeight+4,24,"Arena.LightHeight")
	numberIn(a.LightOffset,4,a.AcrossFlats/3,"Arena.LightOffset")
	vector(a.FixtureSize,0.1,6,"Arena.FixtureSize")
	vector(a.DiffuserSize,0.02,6,"Arena.DiffuserSize")
	numberIn(a.DiffuserGap,0.01,0.2,"Arena.DiffuserGap")
	numberIn(a.GeometryEpsilon,1e-8,1e-4,"Arena.GeometryEpsilon")
	numberIn(a.SpotLight.Brightness,0.1,10,"SpotLight.Brightness")
	numberIn(a.SpotLight.Range,a.LightHeight+4,60,"SpotLight.Range")
	numberIn(a.SpotLight.Angle,60,120,"SpotLight.Angle")
	vector(a.SpotLight.Color,0,255,"SpotLight.Color")
	assert(type(a.SpotLight.Shadows)=="boolean","SpotLight.Shadows must be boolean")
	local materials: {[string]: boolean}={Concrete=true,Metal=true,SmoothPlastic=true,Neon=true}
	for key,material in pairs(config.Materials :: {[string]: any}) do
		assert(materials[material.Material],"Unsupported material: "..tostring(material.Material))
		vector(material.Color,0,255,"Materials."..key..".Color")
		numberIn(material.Reflectance,0,0.1,"Materials."..key..".Reflectance")
	end
	for _,key in ipairs({"Ambient","OutdoorAmbient","ColorShiftTop","ColorShiftBottom","FogColor"}) do
		vector(config.Lighting[key],0,255,"Lighting."..key)
	end
	local l=config.Lighting
	assert(l.LightingStyle=="Realistic","Phase 1 targets Realistic lighting")
	assert(type(l.PrioritizeLightingQuality)=="boolean","PrioritizeLightingQuality must be boolean")
	numberIn(l.Brightness,0,10,"Lighting.Brightness")
	numberIn(l.ClockTime,0,24,"Lighting.ClockTime")
	numberIn(l.GeographicLatitude,-90,90,"Lighting.GeographicLatitude")
	numberIn(l.EnvironmentDiffuseScale,0,1,"Lighting.EnvironmentDiffuseScale")
	numberIn(l.EnvironmentSpecularScale,0,1,"Lighting.EnvironmentSpecularScale")
	numberIn(l.ShadowSoftness,0,1,"Lighting.ShadowSoftness")
	numberIn(l.ExposureCompensation,-1,1,"Lighting.ExposureCompensation")
	numberIn(l.FogStart,0,100000,"Lighting.FogStart")
	numberIn(l.FogEnd,l.FogStart+1,100000,"Lighting.FogEnd")
	numberIn(l.Atmosphere.Density,0,1,"Atmosphere.Density")
	numberIn(l.Atmosphere.Offset,0,1,"Atmosphere.Offset")
	numberIn(l.Atmosphere.Haze,0,10,"Atmosphere.Haze")
	numberIn(l.Atmosphere.Glare,0,10,"Atmosphere.Glare")
	vector(l.Atmosphere.Color,0,255,"Atmosphere.Color")
	vector(l.Atmosphere.Decay,0,255,"Atmosphere.Decay")
	assert(type(l.SunRays.Enabled)=="boolean","SunRays.Enabled must be boolean")
	numberIn(l.SunRays.Intensity,0,1,"SunRays.Intensity")
	numberIn(l.SunRays.Spread,0,1,"SunRays.Spread")
	assert(type(l.GlobalShadows)=="boolean","Lighting.GlobalShadows must be boolean")
	assert(type(l.ColorCorrection.Enabled)=="boolean","ColorCorrection.Enabled must be boolean")
	numberIn(l.ColorCorrection.Brightness,-1,1,"ColorCorrection.Brightness")
	numberIn(l.ColorCorrection.Contrast,-1,1,"ColorCorrection.Contrast")
	numberIn(l.ColorCorrection.Saturation,-1,1,"ColorCorrection.Saturation")
	vector(l.ColorCorrection.TintColor,0,255,"ColorCorrection.TintColor")
	assert(type(l.Bloom.Enabled)=="boolean","Bloom.Enabled must be boolean")
	numberIn(l.Bloom.Intensity,0,1,"Bloom.Intensity")
	numberIn(l.Bloom.Size,0,56,"Bloom.Size")
	numberIn(l.Bloom.Threshold,0,10,"Bloom.Threshold")
	assert(type(l.DepthOfField.Enabled)=="boolean","DepthOfField.Enabled must be boolean")
	numberIn(l.DepthOfField.FarIntensity,0,1,"DepthOfField.FarIntensity")
	numberIn(l.DepthOfField.NearIntensity,0,1,"DepthOfField.NearIntensity")
	numberIn(l.DepthOfField.FocusDistance,0,1000,"DepthOfField.FocusDistance")
	numberIn(l.DepthOfField.InFocusRadius,0,1000,"DepthOfField.InFocusRadius")
	vector(config.Workspace.GlobalWind,-100,100,"Workspace.GlobalWind")
	numberIn(config.Workspace.Gravity,0,300,"Workspace.Gravity")
	numberIn(config.Workspace.FallenPartsDestroyHeight,-50000,-20,"Workspace.FallenPartsDestroyHeight")
	assert(config.Workspace.StreamingEnabled==false,"Compact Phase 1 arena expects streaming off")
	numberIn(config.Runtime.MaximumArenaParts,100,2000,"Runtime.MaximumArenaParts")
	assert(config.PresentationIntensity=="ModerateTarget" or config.PresentationIntensity=="Off","Unsupported presentation preset")
	for feature,enabled in pairs(config.Features :: {[string]: boolean}) do
		assert(enabled==(feature=="Combat" or feature=="StyleRolls" or feature=="Injuries" or feature=="Persistence"  or feature=="CustomFighter"),"Unsupported feature configuration: "..feature)
	end
	if config.Injury then
		numberIn(config.Injury.ArmDamagePenalty,0.1,1.0,"Injury.ArmDamagePenalty")
		numberIn(config.Injury.ArmStaminaPenalty,1.0,3.0,"Injury.ArmStaminaPenalty")
		numberIn(config.Injury.LegMovePenaltyPerLeg,0.01,0.5,"Injury.LegMovePenaltyPerLeg")
		numberIn(config.Injury.LegMovePenaltyCap,0.05,0.8,"Injury.LegMovePenaltyCap")
		numberIn(config.Injury.LegDamagePenalty,0.1,1.0,"Injury.LegDamagePenalty")
	end
	local combat=config.Combat
	for _,key in {"MaxHealth","MaxStamina","StaminaRegenPerSecond","GuardDrainPerSecond","MaxBodyDamage","GrappleDrainPerSecond","GrappleBreakCost","GrappleSeparation","CounterDamageScale","FeintStaminaCost","GroundDrainPerSecond","GroundSeparation","MountDamageScale","GroundTransitionCost","SweepCost","StandUpCost","TakedownStaminaCost","SubmissionDrainPerSecond","SubmissionDamagePerSecond","SubmissionEscapeCost","SubmissionStaminaCost","GroundStrikeDamage","GroundStrikeStamina"} do
		numberIn(combat[key],0.1,200,"Combat."..key)
	end
	for _,key in {"RegenDelayTicks","GuardBreakTicks","BlockStunTicks","HitStunTicks","KOResetTicks","DisplayExtrapolationTicks","GrappleMaxTicks","CounterStunTicks","GroundMaxTicks","SubmissionMaxTicks"} do
		numberIn(combat[key],1,600,"Combat."..key);assert(combat[key]%1==0,"Combat ticks must be integers")
	end
	for _,key in {"GuardDamageScale","GuardMoveScale","AttackMoveScale","HitMoveScale","AttackTurnScale","GuardTurnScale"} do
		numberIn(combat[key],0,1,"Combat."..key)
	end
	numberIn(combat.GuardArcCos,-1,1,"Combat.GuardArcCos")
	numberIn(combat.GrappleArcCos,-1,1,"Combat.GrappleArcCos")
	numberIn(combat.InputBufferTicks,1,12,"Combat.InputBufferTicks")
	numberIn(combat.PreviewTimeoutSeconds,0.1,0.5,"Combat.PreviewTimeoutSeconds")
	numberIn(combat.SweepEpsilon,1e-8,1e-4,"Combat.SweepEpsilon")
	numberIn(combat.DummyGuardResumeStamina,1,combat.MaxStamina,"Combat.DummyGuardResumeStamina")
	assert(type(combat.PracticeDummyGuard)=="boolean","Dummy guard flag")
	assert(#combat.Parts==6 and #combat.Hurtboxes==6,"Six calibrated body parts required")
	for _,h in combat.Hurtboxes do
		assert(table.find(combat.Parts,h.Part),"Unknown hurtbox part")
		numberIn(h.X,-2,2,"Hurtbox.X");numberIn(h.Y,0,6,"Hurtbox.Y")
		numberIn(h.Z,-2,2,"Hurtbox.Z");numberIn(h.Radius,0.1,1,"Hurtbox.Radius")
	end
	local m,n,c,i=config.Movement,config.Network,config.Camera,config.Input
	assert(m.TickRate==60 and n.SendRate==30 and n.SnapshotRate==30,"Timing contract is 60/30/30 Hz")
	numberIn(m.Speed,1,12,"Movement.Speed")
	numberIn(m.Acceleration,1,100,"Movement.Acceleration")
	numberIn(m.Deceleration,1,100,"Movement.Deceleration")
	numberIn(m.Radius,1,2,"Movement.Radius")
	numberIn(m.TurnRate,0.5,10,"Movement.TurnRate")
	assert(m.RootHeight==3 and m.MaxFighters==2,"Calibration contract: 3-stud root, two fighters")
	assert(m.CollisionPasses==4 and m.MaxCatchupSteps==6,"Bounded simulation contract changed")
	numberIn(m.MaxFrameDelta,1/m.TickRate,0.1,"Movement.MaxFrameDelta")
	numberIn(m.BackwardScale,0.1,1,"Movement.BackwardScale")
	numberIn(m.StrafeScale,0.1,1,"Movement.StrafeScale")
	numberIn(m.Epsilon,1e-8,1e-4,"Movement.Epsilon")
	for _,key in {"MaxBatch","MaxQueue","MaxPending","MaxSequence","MessageBurst","FrameBurst","ActionBurst","SnapshotHistory","MaxSequenceGap"} do
		numberIn(n[key],1,2147483647,"Network."..key);assert(n[key]%1==0,"Integer required: "..key)
	end
	assert(n.MaxBatch<=6 and n.MaxQueue<=18 and n.MaxPending<=120,"Network buffers exceed tested caps")
	assert(n.MaxQueue>=n.MaxBatch and n.MaxPending>=n.MaxQueue,"Network buffer ordering")
	for _,key in {"MessagesPerSecond","FramesPerSecond","ActionsPerSecond","ActionCooldown","InputTimeout","DisconnectWarning","InterpolationDelay"} do
		numberIn(n[key],0.01,120,"Network."..key)
	end
	assert(n.Protocol==4 and n.SessionLength==36,"Protocol contract mismatch")
	numberIn(c.FOV,c.MinFOV,c.MaxFOV,"Camera.FOV")
	assert(c.MinFOV==70 and c.MaxFOV==90,"Supported FOV range is 70 to 90")
	numberIn(c.EyeHeight,5,5.8,"Camera.EyeHeight")
	numberIn(c.EyeForward,0,0.3,"Camera.EyeForward")
	numberIn(c.Clearance,0.1,0.5,"Camera.Clearance")
	numberIn(c.PitchLimit,0.5,1.4,"Camera.PitchLimit")
	for _,key in {"MouseSensitivity","TouchSensitivity","GamepadSensitivity","CorrectionSpeed","SnapDistance","FocusDistance","FOVStep","SensitivityStep","TraumaDecay","MaxTraumaYaw","MaxTraumaPitch","MaxTraumaRoll","MaxFovKick"} do
		numberIn(c[key],0.0001,100,"Camera."..key)
	end
	numberIn(i.StickDeadzone,0.05,0.4,"Input.StickDeadzone")
	assert(i.BufferCapacity==8 and i.BufferSeconds==0.2,"Input buffer contract")
	numberIn(i.SwipePixels,10,100,"Input.SwipePixels")
	numberIn(i.TouchStickPixels,30,100,"Input.TouchStickPixels")
	numberIn(i.SwipeMaxSeconds,0.1,1,"Input.SwipeMaxSeconds")
	numberIn(i.TapHoldSeconds,0.5,3,"Input.TapHoldSeconds")
	numberIn(i.ContextPriority,2000,5000,"Input.ContextPriority")
	numberIn(c.SensitivityMin,0.1,1,"Camera.SensitivityMin")
	numberIn(c.SensitivityMax,1,4,"Camera.SensitivityMax")
	numberIn(config.Runtime.DependencyTimeoutSeconds,1,60,"Runtime.DependencyTimeoutSeconds")
	for _,key in {"Color","GloveColor","ShortsColor"} do vector(config.Rig[key],0,255,"Rig."..key) end
	for _,key in {"HeadSize","UpperTorsoSize","LowerTorsoSize","UpperArmSize","ForearmSize","HandSize","ThighSize","ShinSize","FootSize"} do
		vector(config.Rig[key],0.1,2,"Rig."..key)
	end
	for _,key in {"StrideRate","LegSwing","GuardShoulder","GuardElbow"} do numberIn(config.Rig[key],0,10,"Rig."..key) end
end
return table.freeze(Validator)
