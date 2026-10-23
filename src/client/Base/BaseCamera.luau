-- Base camera (v0.3): view over the player's own plot, tilted CameraPitchDegrees and turned
-- CameraYawDegrees (Clash of Clans view), with pan and zoom.
--
-- Input (mouse and touch):
-- * Drag (left mouse / one finger) pans; the focus point stays inside the plot.
-- * Mouse wheel / pinch zooms between MIN_DISTANCE and the distance that fits the whole plot.
-- * A press released within CLICK_SLOP pixels of where it started is a click: Clicked fires (screen position).

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Base.WorldConfig)

local BaseCamera = {}

local SIDE = WorldConfig.GridSize * WorldConfig.TileStuds
local MIN_DISTANCE = 60
local CLICK_SLOP = 6 -- pixels
local WHEEL_STEP = 0.9

local clicked = Instance.new("BindableEvent")
BaseCamera.Clicked = clicked.Event -- fires (Vector2 screen position)

local corner: Vector3? = nil
local focus = Vector3.zero
local distance = 0
local maxDistance = 0
local pitch = math.rad(WorldConfig.CameraPitchDegrees)
local yaw = math.rad(WorldConfig.CameraYawDegrees)
local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))

local function apply()
	if corner == nil then
		return
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = WorldConfig.CameraFieldOfView
	camera.CFrame = CFrame.lookAt(focus + direction * distance, focus)
end

local function clampFocus(p: Vector3): Vector3
	local c = corner :: Vector3
	return Vector3.new(math.clamp(p.X, c.X, c.X + SIDE), c.Y, math.clamp(p.Z, c.Z, c.Z + SIDE))
end

-- Screen-pixel drag -> world movement on the ground at the focus distance.
local function pan(delta: Vector2)
	local camera = workspace.CurrentCamera
	local studsPerPixel = 2 * distance * math.tan(math.rad(camera.FieldOfView / 2)) / camera.ViewportSize.Y
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
	focus = clampFocus(focus - right * delta.X * studsPerPixel + forward * delta.Y * studsPerPixel / math.sin(pitch))
	apply()
end

local function zoom(factor: number)
	distance = math.clamp(distance * factor, MIN_DISTANCE, maxDistance)
	apply()
end

-- Point on the plot's floor plane under a screen position (InputObject coordinates, top-bar inset
-- excluded), or nil if the ray points away from it.
function BaseCamera.GroundPoint(screen: Vector2): Vector3?
	if corner == nil then
		return nil
	end
	local ray = workspace.CurrentCamera:ScreenPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Y) < 1e-6 then
		return nil
	end
	local t = ((corner :: Vector3).Y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function BaseCamera.FramePlot(plotCorner: Vector3)
	corner = plotCorner
	focus = plotCorner + Vector3.new(SIDE / 2, 0, SIDE / 2)
	-- Distance that fits the plot's diagonal in the vertical field of view, plus a 10% margin.
	maxDistance = (SIDE * math.sqrt(2) / 2) / math.tan(math.rad(WorldConfig.CameraFieldOfView / 2)) * 1.1
	distance = maxDistance
	apply()
end

-- ---------------------------------------------------------------- input
local press: { start: Vector2, last: Vector2, dragging: boolean }? = nil
local touches: { [InputObject]: boolean } = {}

local function touchCount(): number
	local n = 0
	for _ in touches do
		n += 1
	end
	return n
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or corner == nil then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		touches[input] = true
		if touchCount() > 1 then
			press = nil -- second finger: pinch, not pan or click
			return
		end
	elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local p = Vector2.new(input.Position.X, input.Position.Y)
	press = { start = p, last = p, dragging = false }
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if corner == nil then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not processed then
			zoom(if input.Position.Z > 0 then WHEEL_STEP else 1 / WHEEL_STEP)
		end
		return
	end
	if press == nil then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local p = Vector2.new(input.Position.X, input.Position.Y)
	if not press.dragging and (p - press.start).Magnitude > CLICK_SLOP then
		press.dragging = true
	end
	if press.dragging then
		pan(p - press.last)
	end
	press.last = p
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		touches[input] = nil
	elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local p = press
	press = nil
	if p and not p.dragging then
		clicked:Fire(p.start)
	end
end)

local pinchScale: number? = nil

UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
	if processed or corner == nil or state ~= Enum.UserInputState.Change then
		return
	end
	-- scale is cumulative for the gesture; apply the change since the last event.
	zoom((pinchScale or 1) / scale)
	pinchScale = scale
end)

UserInputService.TouchEnded:Connect(function()
	pinchScale = nil
end)

return BaseCamera
