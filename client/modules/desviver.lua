local DesviverModule = {}
local isSuiciding = false
local ActiveSuicideAims = {}
local isRemoteThreadRunning = false

local function requestPtfx(asset)
    if not HasNamedPtfxAssetLoaded(asset) then
        RequestNamedPtfxAsset(asset)
        local timeout = GetGameTimer() + 3000
        while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do Wait(10) end
    end
    return HasNamedPtfxAssetLoaded(asset)
end

local function isAllowedWeapon(wHash)
    if not wHash or wHash == 0 or wHash == joaat('WEAPON_UNARMED') then return false end
    if ConfigDesviver.AllowedWeapons[wHash] ~= nil then return ConfigDesviver.AllowedWeapons[wHash] end
    return GetWeapontypeGroup(wHash) == 416676503
end

local function startRemoteAimsThread()
    if isRemoteThreadRunning then return end
    isRemoteThreadRunning = true
    CreateThread(function()
        while next(ActiveSuicideAims) ~= nil do
            for targetSource, data in pairs(ActiveSuicideAims) do
                local tPlayer = GetPlayerFromServerId(targetSource)
                local tPed = (tPlayer and tPlayer ~= -1) and GetPlayerPed(tPlayer) or 0
                if DoesEntityExist(tPed) and GetEntityHealth(tPed) > 100 and not IsEntityDead(tPed) then
                    if lib.requestAnimDict(ConfigDesviver.Dict, 500) then
                        if not IsEntityPlayingAnim(tPed, ConfigDesviver.Dict, ConfigDesviver.Anim, 3) then
                            TaskPlayAnim(tPed, ConfigDesviver.Dict, ConfigDesviver.Anim, 8.0, -8.0, -1, 50, data.phase, false, false, false)
                        end
                        SetEntityAnimSpeed(tPed, ConfigDesviver.Dict, ConfigDesviver.Anim, 0.0)
                        SetEntityAnimCurrentTime(tPed, ConfigDesviver.Dict, ConfigDesviver.Anim, data.phase)
                    end
                else
                    ActiveSuicideAims[targetSource] = nil
                end
            end
            Wait(0)
        end
        isRemoteThreadRunning = false
    end)
end

local function handleSuicideExecution(ped, selectedWeapon, pausePhase)
    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 8.0, -8.0, -1, 2, pausePhase, false, false, false)
    SetEntityAnimSpeed(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 1.0)
    Wait(140) -- Tempo crítico até o disparo

    local headCoords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local rightHandCoords = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)

    TriggerServerEvent('dp_gameplay:desviver:server:syncShot', selectedWeapon, rightHandCoords, headCoords)
    requestPtfx('core')
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('muz_pistol', rightHandCoords.x, rightHandCoords.y, rightHandCoords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('blood_mist', headCoords.x, headCoords.y, headCoords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)

    ShootSingleBulletBetweenCoords(rightHandCoords.x, rightHandCoords.y, rightHandCoords.z, headCoords.x, headCoords.y, headCoords.z, 250, true, selectedWeapon, ped, true, true, 1000.0)
    SetPedShootsAtCoord(ped, headCoords.x, headCoords.y, headCoords.z, true)

    if ConfigDesviver.ConsumeAmmo then TriggerServerEvent('dp_gameplay:desviver:server:consumeAmmo') end
    if DoesEntityExist(ped) then
        SetPedCanRagdoll(ped, true); ApplyDamageToPed(ped, 50000, true)
        SetEntityHealth(ped, 0); SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
    end
end

function DesviverModule.startSuicide()
    local ped = PedAdapter.getPed()
    if isSuiciding then return end
    if PedAdapter.isDeadOrDown(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedRagdoll(ped) then
        NotificationAdapter.notify('Ação Negada', 'Você precisa estar em pé e estável.', 'error')
        return
    end

    local currentWeapon = exports.ox_inventory:getCurrentWeapon()
    local selectedWeapon = currentWeapon and currentWeapon.hash or GetSelectedPedWeapon(ped)
    if not isAllowedWeapon(selectedWeapon) then
        NotificationAdapter.notify('Atenção', 'Você precisa estar segurando uma pistola válida.', 'error')
        return
    end

    local ammo = tonumber(currentWeapon and currentWeapon.metadata and currentWeapon.metadata.ammo) or GetAmmoInPedWeapon(ped, selectedWeapon) or 0
    if ConfigDesviver.RequireAmmo and ammo < 1 then
        NotificationAdapter.notify('Sem Munição', 'Sua arma está sem munição.', 'error')
        return
    end

    isSuiciding = true
    LocalPlayer.state:set('invBusy', true, true)

    CreateThread(function()
        lib.requestAnimDict(ConfigDesviver.Dict, 5000)
        TaskPlayAnim(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 8.0, -8.0, -1, 50, 0.0, false, false, false)

        local startTimer = GetGameTimer()
        while (GetGameTimer() - startTimer) < ConfigDesviver.AnimTimeBeforeShot do
            Wait(10)
            ped = PedAdapter.getPed()
            if PedAdapter.isDeadOrDown(ped) then
                isSuiciding = false
                LocalPlayer.state:set('SuicideAim', nil, true)
                LocalPlayer.state:set('invBusy', false, true)
                return
            end
        end

        local pausePhase = GetEntityAnimCurrentTime(ped, ConfigDesviver.Dict, ConfigDesviver.Anim)
        if not pausePhase or pausePhase <= 0.10 or pausePhase >= 0.28 then pausePhase = 0.235 end

        SetEntityAnimSpeed(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 0.0)
        SetEntityAnimCurrentTime(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, pausePhase)

        TriggerServerEvent('dp_gameplay:desviver:server:syncAim', true, pausePhase)
        LocalPlayer.state:set('SuicideAim', pausePhase, true)
        NotificationAdapter.showTextUI('[LMB] Disparar  |  [E] Abortar')

        local userAction = nil
        while isSuiciding do
            ped = PedAdapter.getPed()
            if PedAdapter.isDeadOrDown(ped) or IsPedRagdoll(ped) then userAction = 'cancel'; break end

            DisablePlayerFiring(ped, true)
            for _, c in ipairs({ 24, 257, 25, 38, 21, 22, 23, 37 }) do DisableControlAction(0, c, true) end

            if not IsEntityPlayingAnim(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 3) then
                TaskPlayAnim(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 8.0, -8.0, -1, 50, pausePhase, false, false, false)
            end
            SetEntityAnimSpeed(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 0.0)
            SetEntityAnimCurrentTime(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, pausePhase)

            if IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 257) or IsDisabledControlJustPressed(0, 257) then
                userAction = 'shoot'; break
            end
            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                userAction = 'abort'; break
            end
            Wait(0)
        end

        NotificationAdapter.hideTextUI()
        TriggerServerEvent('dp_gameplay:desviver:server:syncAim', false, userAction)
        LocalPlayer.state:set('SuicideAim', nil, true)
        LocalPlayer.state:set('invBusy', false, true)

        if userAction == 'shoot' then
            handleSuicideExecution(ped, selectedWeapon, pausePhase)
        else
            StopAnimTask(ped, ConfigDesviver.Dict, ConfigDesviver.Anim, 2.5)
            Wait(400)
            ClearPedTasks(ped)
        end
        isSuiciding = false
    end)
end

function DesviverModule.init()
    RegisterCommand('desviver', DesviverModule.startSuicide, false)
    RegisterNetEvent('dp_gameplay:desviver:client:syncAim', function(targetSource, status, phase)
        if targetSource == GetPlayerServerId(PlayerId()) then return end
        if status == true then
            ActiveSuicideAims[targetSource] = { phase = tonumber(phase) or 0.235 }
            startRemoteAimsThread()
        else
            ActiveSuicideAims[targetSource] = nil
        end
    end)
    RegisterNetEvent('dp_gameplay:desviver:client:syncShot', function(targetSource, weaponHash, fromCoords, toCoords)
        if targetSource == GetPlayerServerId(PlayerId()) then return end
        ActiveSuicideAims[targetSource] = nil
        local myCoords = GetEntityCoords(PedAdapter.getPed())
        if #(myCoords - vec3(fromCoords.x, fromCoords.y, fromCoords.z)) <= ConfigDesviver.SyncDistance then
            ShootSingleBulletBetweenCoords(fromCoords.x, fromCoords.y, fromCoords.z, toCoords.x, toCoords.y, toCoords.z, 0, true, weaponHash, 0, true, true, 1000.0)
            requestPtfx('core')
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('muz_pistol', fromCoords.x, fromCoords.y, fromCoords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('blood_mist', toCoords.x, toCoords.y, toCoords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
        end
    end)
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() and isSuiciding then
            NotificationAdapter.hideTextUI()
            ClearPedTasks(PedAdapter.getPed())
        end
    end)
end

_G.DesviverModule = DesviverModule
return DesviverModule
