local FerimentoPernaModule = {}

local isInjured = false
local runStartTime = 0
local targetRunTime = 0
local lastStumbleTime = 0
local isWorkerRunning = false

local function resetInjury(notifyMsg)
    if not isInjured then return end
    isInjured = false
    runStartTime = 0
    lastStumbleTime = 0

    LocalPlayer.state:set('legInjured', false, true)
    PedAdapter.resetMovementClipset(PedAdapter.getPed())

    if notifyMsg then
        NotificationAdapter.notify('Tratamento', notifyMsg, 'success')
    end
end

local function startInjuryWorker()
    if isWorkerRunning then return end
    isWorkerRunning = true

    CreateThread(function()
        while isInjured do
            local ped = PedAdapter.getPed()

            if PedAdapter.isDeadOrDown(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) then
                Wait(1000)
            else
                local isRunning = IsPedRunning(ped) or IsPedSprinting(ped) or (IsControlPressed(0, 21) and GetEntitySpeed(ped) > 2.0)

                if isRunning then
                    local now = GetGameTimer()
                    if now >= lastStumbleTime then
                        if runStartTime == 0 then
                            runStartTime = now
                            targetRunTime = math.random(ConfigInjuries.minRunTimeToStumble, ConfigInjuries.maxRunTimeToStumble)
                        elseif (now - runStartTime) >= targetRunTime then
                            runStartTime = 0
                            lastStumbleTime = now + ConfigInjuries.stumbleCooldown
                            PedAdapter.setRagdoll(ped, ConfigInjuries.ragdollDuration, ConfigInjuries.ragdollDuration, 0)
                        end
                    end
                    Wait(50)
                else
                    runStartTime = 0
                    Wait(250) -- Quando não está correndo, repouso a 250ms (zero impacto de CPU!)
                end
            end
        end

        isWorkerRunning = false
    end)
end

function FerimentoPernaModule.init()
    AddEventHandler('gameEventTriggered', function(name, args)
        if name ~= 'CEventNetworkEntityDamage' then return end

        local victim = args[1]
        local weaponHash = args[7]
        local ped = PedAdapter.getPed()

        if victim == ped and not PedAdapter.isDeadOrDown(ped) then
            if LocalPlayer.state.Invincible or GetPlayerInvincible(PlayerId()) then return end

            if GetWeaponDamageType(weaponHash) == 3 then -- Dano de arma de fogo
                local hit, boneId = GetPedLastDamageBone(ped)
                if hit and ConfigInjuries.legBones[boneId] then
                    if not isInjured and math.random(1, 100) <= ConfigInjuries.legInjuryChance then
                        isInjured = true
                        runStartTime = 0
                        LocalPlayer.state:set('legInjured', true, true)
                        PedAdapter.setMovementClipset(ped, ConfigInjuries.animSet)
                        NotificationAdapter.notify('Ferimento', 'Você foi atingido na perna e está mancando!', 'warning')
                        startInjuryWorker()
                    end
                end
            end
        end
    end)

    RegisterNetEvent('ferimento_perna:curar', function()
        resetInjury('Seu ferimento na perna foi completamente curado.')
    end)

    RegisterNetEvent('ferimento_perna:ferir', function()
        if not isInjured then
            isInjured = true
            runStartTime = 0
            LocalPlayer.state:set('legInjured', true, true)
            PedAdapter.setMovementClipset(PedAdapter.getPed(), ConfigInjuries.animSet)
            NotificationAdapter.notify('Ferimento', 'Você sofreu uma lesão na perna.', 'error')
            startInjuryWorker()
        end
    end)
end

_G.FerimentoPernaModule = FerimentoPernaModule
return FerimentoPernaModule
