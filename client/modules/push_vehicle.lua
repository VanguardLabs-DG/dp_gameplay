local PushVehicleModule = {}

local isPushing = false
local pushedVehicle = nil

local function isClassAllowed(veh)
    local vClass = GetVehicleClass(veh)
    for _, blacklisted in ipairs(ConfigInteractions.pushVehicle.blacklistedClasses) do
        if vClass == blacklisted then return false end
    end
    return true
end

function PushVehicleModule.startPush()
    local ped = PedAdapter.getPed()
    if isPushing or PedAdapter.isDeadOrDown(ped) or IsPedInAnyVehicle(ped, false) then return end

    local coords = GetEntityCoords(ped)
    local veh = lib.getClosestVehicle(coords, ConfigInteractions.pushVehicle.maxDistance, true)
    if not veh or not DoesEntityExist(veh) or not isClassAllowed(veh) then return end

    local lock = GetVehicleDoorLockStatus(veh)
    if lock > 1 then
        NotificationAdapter.notify('Veículo', 'O veículo está trancado.', 'error')
        return
    end

    isPushing = true
    pushedVehicle = veh

    PedAdapter.playAnim(ped, ConfigInteractions.pushVehicle.animDict, ConfigInteractions.pushVehicle.animClip, 3.0, -3.0, -1, 1)

    local minDim, maxDim = GetModelDimensions(GetEntityModel(veh))
    local pedPos = GetEntityCoords(ped)
    local pedOffset = GetOffsetFromEntityGivenWorldCoords(veh, pedPos.x, pedPos.y, pedPos.z)
    local attachY = (pedOffset.y > 0) and (maxDim.y + 0.6) or (minDim.y - 0.6)
    local attachYaw = (pedOffset.y > 0) and 180.0 or 0.0

    AttachEntityToEntity(ped, veh, -1, 0.0, attachY, pedOffset.z, 0.0, 0.0, attachYaw, false, false, false, true, 0, true)

    CreateThread(function()
        while isPushing and DoesEntityExist(pushedVehicle) do
            if not isPushing then break end

            SetVehicleHandbrake(pushedVehicle, false)

            -- Direção (A e D)
            if IsControlPressed(0, 34) then
                SetVehicleSteeringAngle(pushedVehicle, 15.0)
            elseif IsControlPressed(0, 9) then
                SetVehicleSteeringAngle(pushedVehicle, -15.0)
            else
                SetVehicleSteeringAngle(pushedVehicle, 0.0)
            end

            local pFwd = GetEntityForwardVector(ped)
            local vFwd = GetEntityForwardVector(pushedVehicle)
            local dot  = pFwd.x * vFwd.x + pFwd.y * vFwd.y
            local spd  = (dot < 0.0) and -ConfigInteractions.pushVehicle.pushSpeed or ConfigInteractions.pushVehicle.pushSpeed

            SetVehicleForwardSpeed(pushedVehicle, spd)
            Wait(0)
        end

        PushVehicleModule.stopPush()
    end)
end

function PushVehicleModule.stopPush()
    if not isPushing then return end
    isPushing = false
    local ped = PedAdapter.getPed()
    PedAdapter.detachEntity(ped)
    PedAdapter.clearTasks(ped)
    pushedVehicle = nil
end

_G.PushVehicleModule = PushVehicleModule
return PushVehicleModule
