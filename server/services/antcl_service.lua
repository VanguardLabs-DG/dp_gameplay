local AntclService = {}

function AntclService.init()
    AddEventHandler('playerDropped', function(reason)
        local src = source
        local ped = GetPlayerPed(src)
        if ped == 0 or not DoesEntityExist(ped) then return end

        local coords = GetEntityCoords(ped)
        local citizenId = 'N/A'
        local charName = GetPlayerName(src)

        if exports.qbx_core then
            local player = exports.qbx_core:GetPlayer(src)
            if player and player.PlayerData then
                citizenId = player.PlayerData.citizenid or citizenId
                if player.PlayerData.charinfo then
                    charName = ('%s %s'):format(player.PlayerData.charinfo.firstname or '', player.PlayerData.charinfo.lastname or '')
                end
            end
        end

        local payload = {
            citizenid = citizenId,
            tempId = src,
            charName = charName,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            reason = tostring(reason or 'Desconectou')
        }

        -- Envia log seguro para o Discord
        DiscordAdapter.sendLog(
            ConfigAntcl.discordChannel,
            'Combat-Log Detectado',
            ('O jogador **%s** (Passaporte: %s | ID: %s) desconectou.\n**Motivo:** %s\n**Coordenadas:** `vec3(%.2f, %.2f, %.2f)`'):format(
                charName, citizenId, src, payload.reason, coords.x, coords.y, coords.z
            ),
            15548997
        )

        -- Emite marcador 3D apenas para jogadores próximos (< 100m)
        local players = GetPlayers()
        for _, p in ipairs(players) do
            local pSrc = tonumber(p)
            local pPed = GetPlayerPed(pSrc)
            if pPed ~= 0 and #(GetEntityCoords(pPed) - coords) <= (ConfigAntcl.broadcastRadius or 100.0) then
                TriggerClientEvent('dp_gameplay:antcl:client:createMarker', pSrc, payload)
            end
        end
    end)
end

_G.AntclService = AntclService
return AntclService
