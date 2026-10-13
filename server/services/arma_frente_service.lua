-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | ARMA FRENTE SERVICE (SERVER)
-- Responsabilidade: Sincronização de armas no peito (Sling), cache de assinatura determinística e OneSync StateBag
-----------------------------------------------------------------------------------------------------------------------------------------

local ArmaFrenteService = {}
local playerSignatures = {} -- [src] = "sigString"
local pendingUpdates = {}   -- [src] = bool (debounce)

local function isSlingCompatible(rawName, oxItem)
    if GlobalState.slingsEnabled == false then return false, nil end
    local lowName = string.lower(tostring(rawName or ''))
    if lowName:find('^mag_') or lowName:find('^ammo') or lowName:find('magazine') or (oxItem and oxItem.weapon == false) then
        return false, nil
    end

    local catalog = GlobalState.slingCatalog or {}
    local stripLow = lowName:gsub('^weapon_', '')
    local upperName = string.upper(lowName)
    local weaponUpper = upperName:find('^WEAPON_') and upperName or ('WEAPON_' .. upperName)

    local entry = catalog[weaponUpper] or catalog[upperName] or catalog[lowName] or catalog[stripLow]
    if entry and entry.is_enabled then
        return true, {
            item_name = weaponUpper, prop_model = entry.prop_model or weaponUpper,
            bone = tonumber(entry.bone) or 24818, category = entry.category or 'weapon',
            x = entry.x, y = entry.y, z = entry.z,
            x_rot = entry.x_rot, y_rot = entry.y_rot, z_rot = entry.z_rot
        }
    end

    if ConfigWeapons and ConfigWeapons.compatibleList and (ConfigWeapons.compatibleList[weaponUpper] or ConfigWeapons.compatibleList[stripLow:upper()]) then
        return true, {
            item_name = weaponUpper, prop_model = weaponUpper,
            bone = ConfigWeapons.slingBone or 24818, category = 'weapon',
            x = ConfigWeapons.slingOffset.x, y = ConfigWeapons.slingOffset.y, z = ConfigWeapons.slingOffset.z,
            x_rot = ConfigWeapons.slingOffset.x_rot, y_rot = ConfigWeapons.slingOffset.y_rot, z_rot = ConfigWeapons.slingOffset.z_rot
        }
    end

    if (oxItem and oxItem.weapon) or weaponUpper:find('RIFLE') or weaponUpper:find('CARBINE') or weaponUpper:find('SHOTGUN') or weaponUpper:find('SMG') or weaponUpper:find('SNIPER') or weaponUpper:find('PARAFAL') or weaponUpper:find('IA2') or weaponUpper:find('SCAR') or weaponUpper:find('FAL') or weaponUpper:find('G36') or weaponUpper:find('ARAD') or weaponUpper:find('BREN') then
        return true, {
            item_name = weaponUpper, prop_model = weaponUpper,
            bone = 24818, category = 'weapon',
            x = -0.005, y = 0.185, z = 0.055, x_rot = 1.5, y_rot = 134.5, z_rot = -4.5
        }
    end

    return false, nil
end

local function computeHotbarSignature(slingList)
    if #slingList == 0 then return 'EMPTY' end
    local parts = {}
    for i = 1, #slingList do
        local item = slingList[i]
        local comps = table.concat(item.components or {}, ',')
        parts[i] = string.format('%d:%s:%s:%d:%d:%s', item.slot, item.name, item.prop, item.bone, item.tint, comps)
    end
    return table.concat(parts, '|')
end

function ArmaFrenteService.updatePlayerSling(src)
    if not src or src <= 0 or not GetPlayerPing(src) or GetPlayerPing(src) <= 0 then
        playerSignatures[src] = nil
        return
    end

    local items = InventoryAdapter.getPlayerInventory(src)
    local slingList = {}

    if GlobalState.slingsEnabled ~= false and items then
        for slot = 1, 5 do
            local item = items[slot]
            if item and item.name and (item.count == nil or item.count > 0) then
                local cleanName = item.name:match('^([^%-]+)') or item.name
                local itemData = InventoryAdapter.getItemDefinition(item.name)
                local isCompat, catItem = isSlingCompatible(cleanName, itemData)

                if isCompat and catItem then
                    local comps = {}
                    if item.metadata and item.metadata.components and type(item.metadata.components) == 'table' then
                        for _, comp in pairs(item.metadata.components) do comps[#comps + 1] = comp end
                        table.sort(comps)
                    end

                    local upperItemName = cleanName:upper()
                    if not upperItemName:find('^WEAPON_') then upperItemName = 'WEAPON_' .. upperItemName end

                    slingList[#slingList + 1] = {
                        name = upperItemName, rawName = cleanName, hash = joaat(upperItemName),
                        prop = catItem.prop_model or upperItemName, category = catItem.category or 'weapon',
                        bone = tonumber(catItem.bone) or 24818,
                        offset = {
                            x = tonumber(catItem.x) or -0.005, y = tonumber(catItem.y) or 0.185, z = tonumber(catItem.z) or 0.055,
                            x_rot = tonumber(catItem.x_rot) or 1.5, y_rot = tonumber(catItem.y_rot) or 134.5, z_rot = tonumber(catItem.z_rot) or -4.5
                        },
                        slot = slot, components = comps, tint = item.metadata and tonumber(item.metadata.tint) or 0
                    }
                end
            end
        end
    end

    table.sort(slingList, function(a, b) return a.slot < b.slot end)
    local newSig = computeHotbarSignature(slingList)

    -- Filtro determinístico: se a assinatura visual não mudou, zero tráfego de rede e zero emissão de StateBag
    if playerSignatures[src] == newSig then return end

    playerSignatures[src] = newSig
    Player(src).state:set('slingWeapons', slingList, true)
    TriggerClientEvent('dp_gameplay:client:syncPlayerSlings', src, slingList)
end

function ArmaFrenteService.requestDebouncedUpdate(src)
    if not src or src <= 0 or pendingUpdates[src] then return end
    pendingUpdates[src] = true
    SetTimeout(50, function()
        pendingUpdates[src] = nil
        ArmaFrenteService.updatePlayerSling(src)
    end)
end

function ArmaFrenteService.init()
    InventoryAdapter.registerHotbarObserver(function(src)
        ArmaFrenteService.requestDebouncedUpdate(src)
    end)

    RegisterNetEvent('dp_gameplay:server:requestSlingSync', function()
        ArmaFrenteService.requestDebouncedUpdate(source)
    end)

    RegisterNetEvent('showeapons:checkWeapons', function()
        ArmaFrenteService.requestDebouncedUpdate(source)
    end)

    RegisterNetEvent('qbx_core:server:playerLoaded', function()
        local src = source
        SetTimeout(1000, function() ArmaFrenteService.requestDebouncedUpdate(src) end)
    end)

    AddEventHandler('playerDropped', function()
        playerSignatures[source] = nil
        pendingUpdates[source] = nil
    end)

    AddStateBagChangeHandler('slingCatalog', 'global', function()
        for _, p in ipairs(GetPlayers()) do
            ArmaFrenteService.requestDebouncedUpdate(tonumber(p))
        end
    end)

    CreateThread(function()
        Wait(500)
        for _, p in ipairs(GetPlayers()) do
            ArmaFrenteService.requestDebouncedUpdate(tonumber(p))
        end
    end)
end

_G.ArmaFrenteService = ArmaFrenteService
return ArmaFrenteService
