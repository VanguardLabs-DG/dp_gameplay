local DesviverService = {}
local activeSuicides = {}
local lastActionTick = {}

local function isRateLimited(src, cooldownMs)
    local now = GetGameTimer()
    if (now - (lastActionTick[src] or 0)) < cooldownMs then return true end
    lastActionTick[src] = now
    return false
end

function DesviverService.init()
    RegisterNetEvent('dp_gameplay:desviver:server:syncAim', function(status, phase)
        local src = source
        if isRateLimited(src, 300) then return end

        if status then
            activeSuicides[src] = true
        else
            activeSuicides[src] = nil
        end

        TriggerClientEvent('dp_gameplay:desviver:client:syncAim', -1, src, status, phase)
    end)

    RegisterNetEvent('dp_gameplay:desviver:server:syncShot', function(weaponHash, fromCoords, toCoords)
        local src = source
        if isRateLimited(src, 2000) then return end
        activeSuicides[src] = nil

        local ped = GetPlayerPed(src)
        if ped == 0 or not DoesEntityExist(ped) then return end

        local pedCoords = GetEntityCoords(ped)
        if #(pedCoords - vec3(fromCoords.x, fromCoords.y, fromCoords.z)) > 10.0 then return end

        TriggerClientEvent('dp_gameplay:desviver:client:syncShot', -1, src, weaponHash, fromCoords, toCoords)

        local name = vanguard and vanguard.player and vanguard.player.getName(src) or GetPlayerName(src)
        DiscordAdapter.sendLog(
            'desviver',
            'Suicídio (/desviver)',
            ('O cidadão **%s** (ID %s) utilizou /desviver.'):format(name, src),
            15158332
        )
    end)

    RegisterNetEvent('dp_gameplay:desviver:server:consumeAmmo', function()
        local src = source
        if exports.ox_inventory then
            local currentWeapon = exports.ox_inventory:GetCurrentWeapon(src)
            if currentWeapon and currentWeapon.slot then
                local weaponItem = exports.ox_inventory:GetSlot(src, currentWeapon.slot)
                if weaponItem and weaponItem.metadata and weaponItem.metadata.ammo then
                    local newAmmo = math.max(0, tonumber(weaponItem.metadata.ammo or 1) - 1)
                    local meta = weaponItem.metadata
                    meta.ammo = newAmmo
                    exports.ox_inventory:SetMetadata(src, currentWeapon.slot, meta)
                end
            end
        end
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        lastActionTick[src] = nil
        if activeSuicides[src] then
            activeSuicides[src] = nil
            TriggerClientEvent('dp_gameplay:desviver:client:syncAim', -1, src, false, 'cancel')
        end
    end)
end

_G.DesviverService = DesviverService
return DesviverService
