local ConduzirModule = {}

local isCarrying = false
local currentCarriedTarget = nil
local isBeingCarried = false

local function stopEscorting()
    if not isCarrying then return end
    local targetServerId = currentCarriedTarget
    isCarrying = false
    currentCarriedTarget = nil

    local ped = PedAdapter.getPed()
    PedAdapter.clearTasks(ped)
    NotificationAdapter.hideTextUI()

    if targetServerId then
        TriggerServerEvent('dp_gameplay:conduzir:server:stop', targetServerId)
    end
    TriggerServerEvent('conduzir:stop')
end

function ConduzirModule.toggleEscort()
    local ped = PedAdapter.getPed()

    if isCarrying then
        stopEscorting()
        return
    end

    if PedAdapter.isDeadOrDown(ped) or isBeingCarried or IsPedInAnyVehicle(ped, false) then
        return
    end

    local targetPlayer, targetPed = PedAdapter.getClosestPlayer(ConfigInteractions.conduzir.maxDistance)
    if not targetPlayer or not targetPed or not DoesEntityExist(targetPed) then
        TriggerServerEvent('player:carryPlayer')
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    if targetServerId and targetServerId > 0 then
        TriggerServerEvent('player:carryPlayer', targetServerId)
        TriggerServerEvent('dp_gameplay:conduzir:server:request', targetServerId)
    end
end

function ConduzirModule.init()
    RegisterCommand('conduzir', function()
        ConduzirModule.toggleEscort()
    end, false)

    local function onCarrierStart(targetId)
        isCarrying = true
        currentCarriedTarget = targetId

        local ped = PedAdapter.getPed()
        PedAdapter.playAnim(ped, ConfigInteractions.conduzir.carrierAnimDict, ConfigInteractions.conduzir.carrierAnim, 8.0, 8.0, -1, 49)
        NotificationAdapter.showTextUI('[H] Soltar Cidadão')
    end

    local function onCarrierStop()
        isCarrying = false
        currentCarriedTarget = nil
        local ped = PedAdapter.getPed()
        PedAdapter.clearTasks(ped)
        NotificationAdapter.hideTextUI()
    end

    local function onTargetStart(officerServerId)
        local officerPlayer = GetPlayerFromServerId(officerServerId)
        if officerPlayer == -1 then return end
        local officerPed = GetPlayerPed(officerPlayer)
        if not DoesEntityExist(officerPed) then return end

        isBeingCarried = true
        local ped = PedAdapter.getPed()

        PedAdapter.attachEntityToEntity(ped, officerPed, 11816, 0.40, 0.45, 0.0, 0.0, 0.0, 0.0)
        PedAdapter.playAnim(ped, ConfigInteractions.conduzir.targetAnimDict, ConfigInteractions.conduzir.targetIdleAnim, 8.0, -8.0, -1, 49)
    end

    local function onTargetStop()
        if not isBeingCarried then return end
        isBeingCarried = false
        local ped = PedAdapter.getPed()
        PedAdapter.detachEntity(ped)
        PedAdapter.clearTasks(ped)
    end

    RegisterNetEvent('conduzir:carrierStart', onCarrierStart)
    RegisterNetEvent('dp_gameplay:conduzir:client:startCarry', onCarrierStart)

    RegisterNetEvent('conduzir:carrierStop', onCarrierStop)

    RegisterNetEvent('conduzir:targetStart', onTargetStart)
    RegisterNetEvent('dp_gameplay:conduzir:client:beEscorted', onTargetStart)

    RegisterNetEvent('conduzir:targetStop', onTargetStop)
    RegisterNetEvent('dp_gameplay:conduzir:client:beReleased', onTargetStop)
end

exports('carryPlayer', function(targetId)
    TriggerServerEvent('player:carryPlayer', targetId)
end)

_G.ConduzirModule = ConduzirModule
return ConduzirModule
