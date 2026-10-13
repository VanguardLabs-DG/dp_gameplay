local ArmaFrenteService = {}

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
        local pModel = entry.prop_model or weaponUpper
        return true, {
            item_name = weaponUpper, prop_model = pModel,
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

    if oxItem and oxItem.weapon then
        local cat = oxItem.category
        if cat == 'Rifle' or cat == 'Shotgun' or cat == 'SMG' or cat == 'Sniper' or cat == 'Heavy' then
            return true, {
                item_name = weaponUpper, prop_model = weaponUpper,
                bone = 24818, category = 'weapon',
                x = -0.005, y = 0.185, z = 0.055, x_rot = 1.5, y_rot = 134.5, z_rot = -4.5
            }
        end
    end

    if weaponUpper:find('RIFLE') or weaponUpper:find('CARBINE') or weaponUpper:find('AK') or weaponUpper:find('M4') or weaponUpper:find('M16') or weaponUpper:find('SHOTGUN') or weaponUpper:find('SMG') or weaponUpper:find('SNIPER') or weaponUpper:find('PARAFAL') or weaponUpper:find('IA2') or weaponUpper:find('SCAR') or weaponUpper:find('FAL') or weaponUpper:find('G36') or weaponUpper:find('ARAD') or weaponUpper:find('BREN') then
        return true, {
            item_name = weaponUpper, prop_model = weaponUpper,
            bone = 24818, category = 'weapon',
            x = -0.005, y = 0.185, z = 0.055, x_rot = 1.5, y_rot = 134.5, z_rot = -4.5
        }
    end

    return false, nil
end

function ArmaFrenteService.updatePlayerSling(src)
    if not src or type(src) ~= 'number' or src <= 0 then return end
    if not GetPlayerPing(src) or GetPlayerPing(src) <= 0 then return end

    local inv = exports.ox_inventory and exports.ox_inventory:GetInventory(src)
    if not inv or not inv.items or GlobalState.slingsEnabled == false then
        Player(src).state:set('slingWeapons', {}, true)
        TriggerClientEvent('dp_gameplay:client:syncPlayerSlings', src, {})
        return
    end

    print(string.format('^3[ArmaFrente:SERVER] UpdatePlayerSling iniciado para src=%s | slots scan 1..5^7', tostring(src)))
    local slingList = {}

    for slot = 1, 5 do
        local item = inv.items[slot]
        if item and item.name and (item.count == nil or item.count > 0) then
            local cleanName = item.name:match('^([^%-]+)') or item.name
            local itemData = exports.ox_inventory and exports.ox_inventory:Items(item.name)
            local isCompat, catItem = isSlingCompatible(cleanName, itemData)
            print(string.format('^3[ArmaFrente:SERVER] Slot %d: item=%s, clean=%s -> isCompat=%s^7', slot, tostring(item.name), cleanName, tostring(isCompat)))

            if isCompat and catItem then
                local comps = {}
                if item.metadata and item.metadata.components and type(item.metadata.components) == 'table' then
                    for _, comp in pairs(item.metadata.components) do comps[#comps + 1] = comp end
                end

                local upperItemName = cleanName:upper()
                if not upperItemName:find('^WEAPON_') and (catItem.category == 'rifle' or catItem.category == 'shotgun' or catItem.category == 'smg' or catItem.category == 'pistol' or catItem.category == 'sniper' or catItem.category == 'weapon') then
                    upperItemName = 'WEAPON_' .. upperItemName
                end
                local resolvedHash = joaat(upperItemName)
                slingList[#slingList + 1] = {
                    name = upperItemName,
                    rawName = cleanName,
                    hash = resolvedHash,
                    prop = catItem.prop_model or upperItemName,
                    category = catItem.category or 'weapon',
                    bone = tonumber(catItem.bone) or 24818,
                    offset = {
                        x = tonumber(catItem.x) or -0.02, y = tonumber(catItem.y) or 0.22, z = tonumber(catItem.z) or -0.06,
                        x_rot = tonumber(catItem.x_rot) or 0.0, y_rot = tonumber(catItem.y_rot) or -30.0, z_rot = tonumber(catItem.z_rot) or 180.0
                    },
                    slot = slot,
                    components = comps,
                    tint = item.metadata and tonumber(item.metadata.tint) or 0
                }
            end
        end
    end

    table.sort(slingList, function(a, b) return a.slot < b.slot end)
    print(string.format('^2[ArmaFrente:SERVER] slingWeapons sincronizado para src=%s com %d armas: %s^7', tostring(src), #slingList, json.encode(slingList)))
    Player(src).state:set('slingWeapons', slingList, true)
    TriggerClientEvent('dp_gameplay:client:syncPlayerSlings', src, slingList)
end

function ArmaFrenteService.init()
    RegisterNetEvent('showeapons:checkWeapons', function()
        ArmaFrenteService.updatePlayerSling(source)
    end)

    local function triggerUpdate(src)
        if src and type(src) == 'number' and src > 0 then
            SetTimeout(60, function() ArmaFrenteService.updatePlayerSling(src) end)
        end
    end

    local hookHandler = function(payload)
        if payload then
            triggerUpdate(payload.source)
            triggerUpdate(payload.toInventory)
            triggerUpdate(payload.fromInventory)
        end
        return true
    end

    InventoryAdapter.registerHook('swapItems', hookHandler)
    InventoryAdapter.registerHook('createItem', hookHandler)
    InventoryAdapter.registerHook('buyItem', hookHandler)
    InventoryAdapter.registerHook('giveItem', hookHandler)

    RegisterNetEvent('qbx_core:server:playerLoaded', function()
        local src = source
        SetTimeout(1000, function() ArmaFrenteService.updatePlayerSling(src) end)
    end)

    AddStateBagChangeHandler('slingCatalog', 'global', function()
        for _, p in ipairs(GetPlayers()) do
            local src = tonumber(p)
            if src then triggerUpdate(src) end
        end
    end)

    CreateThread(function()
        Wait(500)
        for _, p in ipairs(GetPlayers()) do
            local src = tonumber(p)
            if src then triggerUpdate(src) end
        end
    end)
end

_G.ArmaFrenteService = ArmaFrenteService
return ArmaFrenteService
