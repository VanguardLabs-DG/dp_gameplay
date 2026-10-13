local VehicleAdapter = {}

function VehicleAdapter.getPlayerVehicleIfDriver()
    local ped = cache.ped or PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

function VehicleAdapter.isAircraft(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    local class = GetVehicleClass(veh)
    if class == 15 or class == 16 then return true end
    local model = GetEntityModel(veh)
    return IsThisModelAPlane(model) or IsThisModelAHeli(model)
end

function VehicleAdapter.isHelicopter(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    return GetVehicleClass(veh) == 15 or IsThisModelAHeli(GetEntityModel(veh))
end

function VehicleAdapter.setForwardSpeed(veh, speedMs)
    if DoesEntityExist(veh) then
        SetVehicleForwardSpeed(veh, speedMs)
    end
end

function VehicleAdapter.setMaxSpeed(veh, speedMs)
    if DoesEntityExist(veh) then
        SetVehicleMaxSpeed(veh, speedMs)
    end
end

function VehicleAdapter.resetMaxSpeed(veh)
    if DoesEntityExist(veh) then
        local defaultMax = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
        SetVehicleMaxSpeed(veh, defaultMax > 0.0 and defaultMax or -1.0)
    end
end

function VehicleAdapter.getWaypointCoords()
    local blip = GetFirstBlipInfoId(8)
    if DoesBlipExist(blip) then
        return GetBlipInfoIdCoord(blip)
    end
    return nil
end

function VehicleAdapter.applyAutopilotPlane(veh, ped, targetCoords, cruiseSpeedMs, targetZ)
    local curCoords = GetEntityCoords(veh)
    local currentHeading = GetEntityHeading(veh)
    local dx = targetCoords.x - curCoords.x
    local dy = targetCoords.y - curCoords.y
    local desiredHeading = (GetHeadingFromVector_2d(dx, dy) + 360.0) % 360.0
    local headingDiff = (desiredHeading - currentHeading + 180.0) % 360.0 - 180.0

    local turnAngle = math.max(-18.0, math.min(18.0, headingDiff))
    local guidanceHeading = (currentHeading + turnAngle + 360.0) % 360.0
    local rad = math.rad(guidanceHeading)

    local lookX = curCoords.x - math.sin(rad) * 400.0
    local lookY = curCoords.y + math.cos(rad) * 400.0

    SetPlaneTurbulenceMultiplier(veh, 0.0)
    TaskPlaneMission(ped, veh, 0, 0, lookX, lookY, targetZ, 4, cruiseSpeedMs, 30.0, -1.0, math.floor(targetZ), 10, false)
end

function VehicleAdapter.applyAutopilotHeli(veh, ped, targetCoords, cruiseSpeedMs, targetZ)
    SetPlaneTurbulenceMultiplier(veh, 0.0)
    TaskHeliMission(ped, veh, 0, 0, targetCoords.x, targetCoords.y, targetZ, 4, cruiseSpeedMs, 50.0, -1.0, math.floor(targetZ), 15, -1.0, 0)
end

function VehicleAdapter.clearTasks(ped)
    ClearPedTasks(ped)
end

_G.VehicleAdapter = VehicleAdapter
return VehicleAdapter
