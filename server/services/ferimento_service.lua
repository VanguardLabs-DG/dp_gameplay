local FerimentoService = {}

local function healPlayerLeg(targetId)
    if not targetId or targetId <= 0 or GetPlayerPed(targetId) == 0 then return false end
    TriggerClientEvent('ferimento_perna:curar', targetId)
    return true
end

local function injurePlayerLeg(targetId)
    if not targetId or targetId <= 0 or GetPlayerPed(targetId) == 0 then return false end
    TriggerClientEvent('ferimento_perna:ferir', targetId)
    return true
end

local function hasMedicalOrAdminPerm(src)
    if src == 0 then return true end
    if exports.qbx_core:HasPermission(src, 'admin') or exports.qbx_core:HasPermission(src, 'god') then
        return true
    end

    local player = exports.qbx_core:GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.job then
        local jName = player.PlayerData.job.name
        if jName == 'ambulance' or jName == 'paramedic' or jName == 'hospital' or jName == 'police' then
            return true
        end
    end

    return false
end

function FerimentoService.init()
    exports('curarPerna', healPlayerLeg)
    exports('ferirPerna', injurePlayerLeg)

    lib.addCommand('curarperna', {
        help = 'Curar ferimento na perna de um cidadão',
        params = {
            { name = 'target', help = 'ID do jogador (opcional)', type = 'playerId', optional = true }
        }
    }, function(source, args)
        local targetId = args.target or source
        if not hasMedicalOrAdminPerm(source) then
            TriggerClientEvent('ox_lib:notify', source, { description = 'Você não possui autorização médica.', type = 'error' })
            return
        end

        if healPlayerLeg(targetId) then
            TriggerClientEvent('ox_lib:notify', source, { description = ('Perna curada para o ID %s.'):format(targetId), type = 'success' })
        else
            TriggerClientEvent('ox_lib:notify', source, { description = 'Jogador não encontrado.', type = 'error' })
        end
    end)

    lib.addCommand('ferirperna', {
        help = 'Aplicar lesão na perna de um cidadão (Admin)',
        params = {
            { name = 'target', help = 'ID do jogador', type = 'playerId' }
        }
    }, function(source, args)
        if source ~= 0 and not exports.qbx_core:HasPermission(source, 'admin') then
            TriggerClientEvent('ox_lib:notify', source, { description = 'Sem permissão.', type = 'error' })
            return
        end

        if injurePlayerLeg(args.target) then
            if source > 0 then
                TriggerClientEvent('ox_lib:notify', source, { description = ('Lesão aplicada ao ID %s.'):format(args.target), type = 'inform' })
            end
        end
    end)
end

_G.FerimentoService = FerimentoService
return FerimentoService
