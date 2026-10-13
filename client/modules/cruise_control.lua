local CruiseModule = {}

local isCruiseActive = false
local isAutopilotActive = false
local currentSpeedKmh = 0.0
local activeVehicle = nil
local waypointZ = nil
local nextRouteUpdate = 0
local isWorkerRunning = false
local accelHoldTime = 0
local lastBodyHealth = nil
local lastEngineHealth = nil

local function stopCruise(reason)
    if not isCruiseActive and not isAutopilotActive then return end
    isCruiseActive = false
    isAutopilotActive = false
    accelHoldTime = 0
    lastBodyHealth = nil
    lastEngineHealth = nil

    if activeVehicle and DoesEntityExist(activeVehicle) then
        VehicleAdapter.resetMaxSpeed(activeVehicle)
        if VehicleAdapter.isAircraft(activeVehicle) then VehicleAdapter.clearTasks(PedAdapter.getPed()) end
    end
    activeVehicle = nil
    NotificationAdapter.notify('Controle de Cruzeiro', reason or 'Controle desativado.', reason and 'warning' or 'inform')
end

local function checkCollisionOrHealthDrop(veh, isAir)
    if not DoesEntityExist(veh) or HasEntityCollidedWithAnything(veh) then return true end
    local bodyH = GetVehicleBodyHealth(veh)
    local engH = GetVehicleEngineHealth(veh)

    if not isAir then
        if (lastBodyHealth and (lastBodyHealth - bodyH) > 1.0) or (lastEngineHealth and (lastEngineHealth - engH) > 1.0) or IsEntityInAir(veh) then
            return true
        end
    else
        if lastEngineHealth and (lastEngineHealth - engH) > 10.0 then return true end
    end

    lastBodyHealth = bodyH
    lastEngineHealth = engH
    return false
end

local function startCruiseWorker(veh)
    if isWorkerRunning then return end
    isWorkerRunning = true

    CreateThread(function()
        local isAir = VehicleAdapter.isAircraft(veh)
        local isHeli = isAir and VehicleAdapter.isHelicopter(veh) or false
        local nextWaypointCheck = 0
        local cachedWpCoords = nil

        while isCruiseActive or isAutopilotActive do
            local ped = PedAdapter.getPed()
            if not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped then
                stopCruise('Você saiu do veículo.')
                break
            end

            if checkCollisionOrHealthDrop(veh, isAir) then
                stopCruise('Desativado por colisão ou impacto.')
                break
            end

            if IsControlPressed(0, 72) or IsDisabledControlPressed(0, 72) or IsControlJustPressed(0, 75) then
                stopCruise('Freio acionado.')
                break
            end

            if IsControlPressed(0, 71) then
                accelHoldTime = accelHoldTime + (GetFrameTime() * 1000)
                if accelHoldTime >= 2000 then stopCruise('Acelerador mantido.'); break end
            else
                accelHoldTime = 0
            end

            if isAutopilotActive then
                local now = GetGameTimer()
                if now >= nextWaypointCheck then
                    nextWaypointCheck = now + 250
                    cachedWpCoords = VehicleAdapter.getWaypointCoords()
                end

                if not cachedWpCoords then stopCruise('Marcação removida.'); break end

                local curCoords = GetEntityCoords(veh)
                local dist = #(vector2(curCoords.x, curCoords.y) - vector2(cachedWpCoords.x, cachedWpCoords.y))
                if dist <= (ConfigCruise.planeWaypointApproachDist or 120.0) then
                    stopCruise('Destino alcançado. Assuma o controle.')
                    break
                end

                if now >= nextRouteUpdate then
                    nextRouteUpdate = now + (ConfigCruise.updateIntervalMs or 1500)
                    local cruiseMs = math.max(currentSpeedKmh, ConfigCruise.aircraftMinSpeedKmh or 80.0) / 3.6
                    if isHeli then
                        VehicleAdapter.applyAutopilotHeli(veh, ped, cachedWpCoords, cruiseMs, waypointZ or curCoords.z)
                    else
                        VehicleAdapter.applyAutopilotPlane(veh, ped, cachedWpCoords, cruiseMs, waypointZ or curCoords.z)
                    end
                end
            else
                if isAir or not IsEntityInAir(veh) then
                    VehicleAdapter.setForwardSpeed(veh, currentSpeedKmh / 3.6)
                end
            end
            Wait(0)
        end
        isWorkerRunning = false
    end)
end

function CruiseModule.toggleCruise()
    local veh = VehicleAdapter.getPlayerVehicleIfDriver()
    if not veh then
        NotificationAdapter.notify('Controle de Cruzeiro', 'Você precisa ser o motorista do veículo.', 'error')
        return
    end
    if isCruiseActive then stopCruise(); return end

    local isAir = VehicleAdapter.isAircraft(veh)
    local curKmh = GetEntitySpeed(veh) * 3.6
    if not isAir and curKmh > 60.0 then
        NotificationAdapter.notify('Controle de Cruzeiro', 'Velocidade muito alta para ativar (máx 60 km/h).', 'warning')
        return
    end

    currentSpeedKmh = math.max(curKmh, isAir and (ConfigCruise.aircraftMinSpeedKmh or 80.0) or (ConfigCruise.minSpeedKmh or 10.0))
    isCruiseActive = true
    activeVehicle = veh
    lastBodyHealth = GetVehicleBodyHealth(veh)
    lastEngineHealth = GetVehicleEngineHealth(veh)
    NotificationAdapter.notify('Controle de Cruzeiro', ('Ativado a %.0f km/h.'):format(currentSpeedKmh), 'success')
    startCruiseWorker(veh)
end

function CruiseModule.adjustSpeed(deltaKmh)
    if not isCruiseActive or not activeVehicle then return end
    local isAir = VehicleAdapter.isAircraft(activeVehicle)
    local minLimit = isAir and (ConfigCruise.aircraftMinSpeedKmh or 80.0) or (ConfigCruise.minSpeedKmh or 10.0)
    local maxLimit = isAir and 350.0 or 60.0
    local newSpeed = currentSpeedKmh + deltaKmh

    if newSpeed > maxLimit then
        NotificationAdapter.notify('Controle de Cruzeiro', ('Limite máximo (%d km/h).'):format(math.floor(maxLimit)), 'warning')
        newSpeed = maxLimit
    elseif newSpeed < minLimit then
        newSpeed = minLimit
    end

    currentSpeedKmh = newSpeed
    NotificationAdapter.notify('Controle de Cruzeiro', ('Velocidade ajustada: %.0f km/h.'):format(currentSpeedKmh), 'inform')
end

function CruiseModule.toggleAutopilot()
    local veh = VehicleAdapter.getPlayerVehicleIfDriver()
    if not veh or not VehicleAdapter.isAircraft(veh) then
        NotificationAdapter.notify('Piloto Automático', 'Disponível apenas para aeronaves.', 'error')
        return
    end
    if isAutopilotActive then stopCruise(); return end

    local wpCoords = VehicleAdapter.getWaypointCoords()
    if not wpCoords then
        NotificationAdapter.notify('Piloto Automático', 'Marque um destino no mapa (Waypoint) primeiro.', 'warning')
        return
    end

    waypointZ = GetEntityCoords(veh).z
    currentSpeedKmh = math.max(GetEntitySpeed(veh) * 3.6, ConfigCruise.aircraftMinSpeedKmh or 80.0)
    isCruiseActive = true
    isAutopilotActive = true
    activeVehicle = veh
    nextRouteUpdate = 0
    lastBodyHealth = GetVehicleBodyHealth(veh)
    lastEngineHealth = GetVehicleEngineHealth(veh)
    NotificationAdapter.notify('Piloto Automático', 'Piloto automático engajado em direção ao destino.', 'success')
    startCruiseWorker(veh)
end

_G.CruiseModule = CruiseModule
return CruiseModule
