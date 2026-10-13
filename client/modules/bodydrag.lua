local BodydragModule = {}

local isDragging = false
local draggingTarget = nil
local isBeingDragged = false

local function stopDragging()
    if not isDragging then return end
    local targetServerId = draggingTarget
    isDragging = false
    draggingTarget = nil

    local ped = PedAdapter.getPed()
    PedAdapter.clearTasks(ped)
    NotificationAdapter.hideTextUI()

    if targetServerId then
        TriggerServerEvent('icemallow-drag-server:deattach', targetServerId)
        TriggerServerEvent('dp_gameplay:bodydrag:server:stop', targetServerId)
    end
end

function BodydragModule.startDragAttempt()
    local ped = PedAdapter.getPed()

    if isDragging then
        stopDragging()
        return
    end

    if PedAdapter.isDeadOrDown(ped) or isBeingDragged or IsPedInAnyVehicle(ped, false) then
        return
    end

    local targetPlayer, targetPed = PedAdapter.getClosestPlayer(ConfigInteractions.bodydrag.maxDistance)
    if not targetPlayer or not targetPed or not DoesEntityExist(targetPed) then
        NotificationAdapter.notify('Arrastar', 'Nenhum cidadão caído por perto.', 'warning')
        return
    end

    if not PedAdapter.isDeadOrDown(targetPed) then
        NotificationAdapter.notify('Arrastar', 'O cidadão não está desacordado.', 'error')
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    if targetServerId and targetServerId > 0 then
        TriggerServerEvent('icemallow-drag-server:attach', targetServerId)
        TriggerServerEvent('dp_gameplay:bodydrag:server:request', targetServerId)
    end
end

function BodydragModule.stopDragKey()
    if isDragging then
        stopDragging()
    end
end

function BodydragModule.init()
    -- Confirmação do arrasto no puxador
    RegisterNetEvent('dp_gameplay:bodydrag:client:dragSuccess', function(targetId)
        isDragging = true
        draggingTarget = targetId

        local ped = PedAdapter.getPed()
        PedAdapter.playAnim(ped, ConfigInteractions.bodydrag.animDict, ConfigInteractions.bodydrag.carrierAnim, 2.0, 2.0, -1, 49)
        NotificationAdapter.showTextUI('[G] Largar Corpo')
    end)

    local function handleAttachVictim(carrierServerId)
        local carrierPlayer = GetPlayerFromServerId(carrierServerId)
        if carrierPlayer == -1 then return end
        local carrierPed = GetPlayerPed(carrierPlayer)
        if not DoesEntityExist(carrierPed) then return end

        isBeingDragged = true
        local ped = PedAdapter.getPed()

        PedAdapter.attachEntityToEntity(ped, carrierPed, 11816, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0)
        PedAdapter.playAnim(ped, ConfigInteractions.bodydrag.animDict, ConfigInteractions.bodydrag.targetAnim, 2.0, 2.0, -1, 33)
    end

    local function handleDetachVictim()
        if not isBeingDragged then return end
        isBeingDragged = false
        local ped = PedAdapter.getPed()
        PedAdapter.detachEntity(ped)
        PedAdapter.clearTasks(ped)
    end

    RegisterNetEvent('icemallow-drag:attach', handleAttachVictim)
    RegisterNetEvent('dp_gameplay:bodydrag:client:beAttached', handleAttachVictim)

    RegisterNetEvent('icemallow-drag:deattach', handleDetachVictim)
    RegisterNetEvent('dp_gameplay:bodydrag:client:beDetached', handleDetachVictim)

    RegisterNetEvent('icemallow-drag:cancel', function()
        stopDragging()
    end)
end

_G.BodydragModule = BodydragModule
return BodydragModule
