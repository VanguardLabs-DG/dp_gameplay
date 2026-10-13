local SurrenderModule = {}

local isSurrendered = false

local function handleDoSurrender()
    if isSurrendered then return end
    isSurrendered = true
    local ped = PedAdapter.getPed()

    -- 1. Mãos para o alto
    PedAdapter.playAnim(ped, 'busted', 'idle_2_hands_up_2h', 8.0, 8.0, -1, 1)

    SetTimeout(ConfigInteractions.surrender.handsUpDuration or 4500, function()
        if not isSurrendered then return end
        -- 2. De joelhos no chão
        PedAdapter.playAnim(ped, 'random@arrests@busted', 'idle_a', 8.0, 8.0, -1, 1)
    end)

    SetTimeout(ConfigInteractions.surrender.kneelDuration or 25000, function()
        if isSurrendered then
            isSurrendered = false
            PedAdapter.clearTasks(PedAdapter.getPed())
        end
    end)
end

function SurrenderModule.attemptSurrenderOrder()
    local ped = PedAdapter.getPed()
    if not IsPlayerFreeAiming(PlayerId()) then return end

    local hit, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if not hit or not DoesEntityExist(targetEntity) or not IsPedAPlayer(targetEntity) then
        return
    end

    local targetPlayer = NetworkGetPlayerIndexFromPed(targetEntity)
    local targetServerId = GetPlayerServerId(targetPlayer)
    if targetServerId and targetServerId > 0 then
        TriggerServerEvent('surrender:request', targetServerId)
    end
end

function SurrenderModule.init()
    local confirmCallback = function()
        return NotificationAdapter.confirmDialog(
            'Ordem Policial: Rendição',
            'Um policial está apontando a arma para você e ordenando rendição imediata.\n\nDeseja se render e deitar no chão com as mãos na cabeça?'
        )
    end

    lib.callback.register('surrender:confirmSurrender', confirmCallback)
    lib.callback.register('dp_gameplay:surrender:client:confirm', confirmCallback)

    RegisterNetEvent('surrender:doSurrender', handleDoSurrender)
    RegisterNetEvent('dp_gameplay:surrender:client:doSurrender', handleDoSurrender)
end

_G.SurrenderModule = SurrenderModule
return SurrenderModule
