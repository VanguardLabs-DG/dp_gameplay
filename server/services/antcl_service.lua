local AntclService = {}

function AntclService.init()
    AddEventHandler('playerDropped', function(reason)
        local src = source
        local ped = GetPlayerPed(src)
        local hasPed = (ped ~= 0 and DoesEntityExist(ped))
        local coords = hasPed and GetEntityCoords(ped) or nil
        local hasValidCoords = (coords and #(coords - vec3(0.0, 0.0, 0.0)) > 2.0)

        local citizenId = 'N/A'
        local charName = GetPlayerName(src) or ('ID %s'):format(src)

        if exports.qbx_core then
            local player = exports.qbx_core:GetPlayer(src)
            if player and player.PlayerData then
                citizenId = player.PlayerData.citizenid or citizenId
                if player.PlayerData.charinfo then
                    charName = ('%s %s'):format(player.PlayerData.charinfo.firstname or '', player.PlayerData.charinfo.lastname or '')
                end
            end
        end

        local reasonStr = tostring(reason or 'Desconectou')
        local coordDesc = hasValidCoords and ('`vec3(%.2f, %.2f, %.2f)`'):format(coords.x, coords.y, coords.z) or '*Coordenada Indisponível (Ped Despawnado)*'

        DiscordAdapter.sendLog(
            ConfigAntcl.discordChannel,
            'Combat-Log Detectado',
            ('O jogador **%s** (Passaporte: %s | ID: %s) desconectou.\n**Motivo:** %s\n**Coordenadas:** %s'):format(
                charName, citizenId, src, reasonStr, coordDesc
            ),
            15548997
        )

        if not hasValidCoords then return end

        local payload = {
            citizenid = citizenId,
            tempId = src,
            charName = charName,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            reason = reasonStr
        }

        local broadcastDist = ConfigAntcl.broadcastRadius or 100.0
        for _, p in ipairs(GetPlayers()) do
            local pSrc = tonumber(p)
            local pPed = GetPlayerPed(pSrc)
            if pPed ~= 0 and #(GetEntityCoords(pPed) - coords) <= broadcastDist then
                TriggerClientEvent('dp_gameplay:antcl:client:createMarker', pSrc, payload)
            end
        end
    end)
end

_G.AntclService = AntclService
return AntclService
