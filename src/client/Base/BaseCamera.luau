-- Base camera (v0.3): fixed view over the player's own plot, tilted CameraPitchDegrees and turned
-- CameraYawDegrees (Clash of Clans view). Pan and zoom come with AB-9.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Base.WorldConfig)

local BaseCamera = {}

local SIDE = WorldConfig.GridSize * WorldConfig.TileStuds

function BaseCamera.FramePlot(corner: Vector3)
	local camera = workspace.CurrentCamera
	local centre = corner + Vector3.new(SIDE / 2, 0, SIDE / 2)
	local pitch = math.rad(WorldConfig.CameraPitchDegrees)
	local yaw = math.rad(WorldConfig.CameraYawDegrees)
	-- Distance that fits the plot's diagonal in the vertical field of view, plus a 10% margin.
	local fov = WorldConfig.CameraFieldOfView
	local distance = (SIDE * math.sqrt(2) / 2) / math.tan(math.rad(fov / 2)) * 1.1
	local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * distance
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(centre + offset, centre)
end

return BaseCamera
