local BindsModule = {}

local activeBind = nil
local lastActionTime = 0
local isThreadRunning = false

local function stopActiveBind(clearUpper)
    local ped = PedAdapter.getPed()
    if activeBind then
        if activeBind.dict and activeBind.anim then
            if IsEntityPlayingAnim(ped, activeBind.dict, activeBind.anim, 3) then
                StopAnimTask(ped, activeBind.dict, activeBind.anim, 8.0)
            end
        end
        activeBind = nil
    end

    if GetResourceState('scully_emotemenu') == 'started' then
        pcall(function()
            if exports.scully_emotemenu and exports.scully_emotemenu:isInEmote() then
                exports.scully_emotemenu:cancelEmote()
            end
        end)
    end

    if clearUpper then
        ClearPedSecondaryTask(ped)
    else
        ClearPedTasks(ped)
    end
end

local function canPlayBind(ped)
    local now = GetGameTimer()
    if now < lastActionTime then return false end
    if IsPauseMenuActive() then return false end
    if PedAdapter.isDeadOrDown(ped) then return false end

    local isCuffed = LocalPlayer.state.isCuffed or LocalPlayer.state.Handcuff or LocalPlayer.state.ishandcuffed
    if ConfigBinds.blockIfCuffed and isCuffed then return false end
    if ConfigBinds.blockInVehicle and IsPedInAnyVehicle(ped, false) then return false end
    if ConfigBinds.blockIfSwimming and (IsPedSwimming(ped) or IsPedRagdoll(ped)) then return false end

    if LocalPlayer.state.usingPhone or LocalPlayer.state.phone_open then return false end

    if ConfigBinds.blockIfArmed then
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= joaat('WEAPON_UNARMED') or IsPedArmed(ped, 6) or IsPedArmed(ped, 7) then
            return false
        end
    end

    if ConfigBinds.blockIfAiming and IsPlayerFreeAiming(PlayerId()) then return false end

    return true
end

local function startWatcherThread()
    if isThreadRunning then return end
    isThreadRunning = true

    CreateThread(function()
        while activeBind ~= nil do
            local ped = PedAdapter.getPed()

            if PedAdapter.isDeadOrDown(ped) or IsPedSwimming(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) then
                stopActiveBind(true)
                break
            end

            DisablePlayerFiring(ped, true)
            DisableControlAction(0, 18, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)

            Wait(0)
        end
        isThreadRunning = false
    end)
end

function BindsModule.handleBind(param)
    local key = tostring(param):lower()
    local bindConfig = ConfigBinds.list[key]
    if not bindConfig then return end

    local ped = PedAdapter.getPed()
    if not canPlayBind(ped) then return end

    lastActionTime = GetGameTimer() + (ConfigBinds.cooldownMs or 600)

    if bindConfig.loop then
        if activeBind and activeBind.key == key then
            stopActiveBind(true)
            return
        end

        stopActiveBind(true)

        if lib.requestAnimDict(bindConfig.dict, 2000) then
            local flag = bindConfig.flag or 49
            TaskPlayAnim(ped, bindConfig.dict, bindConfig.anim, 8.0, -8.0, -1, flag, 0.0, false, false, false)
            activeBind = {
                key = key,
                dict = bindConfig.dict,
                anim = bindConfig.anim
            }
            startWatcherThread()
        end
    else
        if activeBind then
            stopActiveBind(true)
        end

        if lib.requestAnimDict(bindConfig.dict, 2000) then
            local flag = bindConfig.flag or 48
            TaskPlayAnim(ped, bindConfig.dict, bindConfig.anim, 8.0, 8.0, -1, flag, 0.0, false, false, false)
        end
    end
end

function BindsModule.stopActiveBind()
    stopActiveBind(true)
end

function BindsModule.init()
    -- Comandos legados compatíveis 1:1 com a base e configurações de teclas dos jogadores
    RegisterCommand('Binds', function(_, args)
        if args and args[1] then
            BindsModule.handleBind(args[1])
        end
    end, false)

    for keyName, bindData in pairs(ConfigBinds.list) do
        RegisterCommand('Binds ' .. keyName, function()
            BindsModule.handleBind(keyName)
        end, false)

        RegisterKeyMapping('Binds ' .. keyName, bindData.description, 'keyboard', bindData.defaultKey)
    end

    RegisterCommand('cancelbinds', function()
        stopActiveBind(true)
    end, false)

    RegisterCommand('Cancel', function()
        stopActiveBind(true)
    end, false)

    RegisterKeyMapping('cancelbinds', 'Cancelar animações rápidas', 'keyboard', 'F6')

    RegisterNetEvent('scully_emotemenu:cancelEmote', function()
        if activeBind then
            stopActiveBind(true)
        end
    end)
end

exports('playBind', BindsModule.handleBind)
exports('stopBind', BindsModule.stopActiveBind)
exports('getActiveBind', function() return activeBind end)

_G.BindsModule = BindsModule
return BindsModule
