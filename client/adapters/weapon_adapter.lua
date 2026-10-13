-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | WEAPON ADAPTER (CLIENT)
-- Responsabilidade: Interação nativa com GTA V / FiveM para criação, verificação e exclusão de entidades de armas/props
-----------------------------------------------------------------------------------------------------------------------------------------

local WeaponAdapter = {}
local UNARMED_HASH = -1569615261
local oxItemsCache = nil

function WeaponAdapter.normalizeHash(h)
    if not h then return 0 end
    if type(h) == 'string' then h = tonumber(h) or (GetHashKey and GetHashKey(h)) or (joaat and joaat(h)) end
    h = tonumber(h) or 0
    if h >= 0x80000000 then h = h - 0x100000000 end
    return math.floor(h)
end

function WeaponAdapter.loadWeaponAsset(wepHash, timeoutMs)
    if not wepHash or wepHash == 0 then return false end
    if HasWeaponAssetLoaded(wepHash) then return true end
    RequestWeaponAsset(wepHash, 31, 0)
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    while not HasWeaponAssetLoaded(wepHash) and GetGameTimer() < timeout do Wait(10) end
    return HasWeaponAssetLoaded(wepHash)
end

function WeaponAdapter.loadModel(modelHash, timeoutMs)
    if not modelHash or modelHash == 0 then return false end
    if HasModelLoaded(modelHash) then return true end
    RequestModel(modelHash)
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(modelHash)
end

function WeaponAdapter.spawnSlingEntity(item)
    if not item then return nil, false end
    if type(item) ~= 'table' then item = { name = tostring(item), prop = tostring(item), category = 'weapon' } end

    local rawName = tostring(item.name or item.item_name or '')
    local rawProp = tostring(item.prop or item.prop_model or rawName)
    local upperName = rawName:upper()
    local upperProp = rawProp:upper()

    local isWeapon = (item.category == 'weapon' or item.category == 'rifle' or item.category == 'shotgun' or item.category == 'smg' or item.category == 'sniper' or item.category == 'pistol' or upperName:find('^WEAPON_') or upperProp:find('^WEAPON_'))

    -- 1. Instanciação de arma via CreateWeaponObject (isNetwork = false para prop puramente visual local)
    if isWeapon then
        local wepName = upperName:find('^WEAPON_') and upperName or (upperProp:find('^WEAPON_') and upperProp or ('WEAPON_' .. upperName))
        local wepHash = (wepName ~= '' and GetHashKey(wepName)) or item.hash or 0
        if wepHash and wepHash ~= 0 then
            local propClean = (rawProp ~= '' and not rawProp:find('^WEAPON_')) and rawProp:lower() or nil
            if propClean then
                local modelHash = GetHashKey(propClean)
                if IsModelInCdimage(modelHash) then WeaponAdapter.loadModel(modelHash, 1000) end
                local magHash = GetHashKey(propClean .. '_mag1')
                if IsModelInCdimage(magHash) then WeaponAdapter.loadModel(magHash, 500) end
            end

            WeaponAdapter.loadWeaponAsset(wepHash, 2000)
            if HasWeaponAssetLoaded(wepHash) then
                local obj = CreateWeaponObject(wepHash, 0, 0.0, 0.0, 0.0, true, 1.0, 0)
                if obj and DoesEntityExist(obj) then
                    SetEntityVisible(obj, true, 0)
                    SetEntityAlpha(obj, 255, false)
                    ResetEntityAlpha(obj)
                    return obj, true
                end
            end
        end
    end

    -- 2. Instanciação de prop / objeto não-arma via CreateObject (isNetwork = false)
    local propName = (rawProp ~= '' and not rawProp:find('^WEAPON_')) and rawProp or rawName
    local modelHash = GetHashKey(propName)
    if modelHash and modelHash ~= 0 then
        WeaponAdapter.loadModel(modelHash, 2000)
        if HasModelLoaded(modelHash) then
            local obj = CreateObject(modelHash, 0.0, 0.0, 0.0, false, false, false)
            if obj and DoesEntityExist(obj) then return obj, false end
        end
    end

    return nil, false
end

function WeaponAdapter.deleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        DetachEntity(entity, true, true)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteObject(entity)
        DeleteEntity(entity)
        if DoesEntityExist(entity) then
            SetEntityCoords(entity, 0.0, 0.0, -5000.0, false, false, false, false)
            SetEntityAlpha(entity, 0, false)
            SetEntityVisible(entity, false, 0)
        end
    end
end

function WeaponAdapter.isWeaponInHand(ped, wep)
    if not DoesEntityExist(ped) or not wep then return false end
    local wepHash = wep.hash and WeaponAdapter.normalizeHash(wep.hash) or 0
    local nameHash = wep.name and WeaponAdapter.normalizeHash(GetHashKey(wep.name)) or 0
    local rawHash = wep.rawName and WeaponAdapter.normalizeHash(GetHashKey(wep.rawName)) or 0
    local selected = WeaponAdapter.normalizeHash(GetSelectedPedWeapon(ped))
    local _, current = GetCurrentPedWeapon(ped, true)
    current = WeaponAdapter.normalizeHash(current)

    if selected ~= 0 and selected ~= UNARMED_HASH and (selected == wepHash or selected == nameHash or selected == rawHash) then
        return true
    end
    if current ~= 0 and current ~= UNARMED_HASH and (current == wepHash or current == nameHash or current == rawHash) then
        return true
    end

    local myPed = cache.ped or PlayerPedId()
    if ped == myPed then
        local myWep = LocalPlayer.state.currentWeapon
        if myWep and myWep ~= 0 and myWep ~= UNARMED_HASH then
            myWep = WeaponAdapter.normalizeHash(myWep)
            if myWep == wepHash or myWep == nameHash or myWep == rawHash then
                return true
            end
        end
    end

    return false
end

function WeaponAdapter.resolveComponentsAndTint(wepHash, item, serverId)
    local raw = WeaponAdapter.getComponentHashes(wepHash, item and item.components)
    local tint = item and tonumber(item.tint) or 0
    local pState = Player(serverId).state
    if pState then
        local vipAtt, vipT = pState.vipWeaponAttachs, pState.vipWeaponTints
        if vipAtt and vipAtt[wepHash] then
            for c, eq in pairs(vipAtt[wepHash]) do
                local n = tonumber(c)
                if n and eq then raw[#raw + 1] = n end
            end
        end
        if vipT and vipT[wepHash] ~= nil then tint = tonumber(vipT[wepHash]) or tint end
    end
    local uMap, comps = {}, {}
    for _, c in ipairs(raw) do
        local n = tonumber(c)
        if n and n ~= 0 and not uMap[n] and DoesWeaponTakeWeaponComponent(wepHash, n) then
            uMap[n] = true; comps[#comps + 1] = n
        end
    end
    table.sort(comps)
    return comps, tint
end

local function getOxItems()
    if oxItemsCache then return oxItemsCache end
    if exports.ox_inventory then
        local ok, res = pcall(function() return exports.ox_inventory:Items() end)
        if ok and type(res) == 'table' then oxItemsCache = res; return res end
    end
    return nil
end

function WeaponAdapter.getComponentHashes(weaponHash, itemComponents)
    local result = {}
    if not itemComponents or type(itemComponents) ~= 'table' then return result end
    local oxItems = getOxItems()

    for _, comp in pairs(itemComponents) do
        local compHash = nil
        if type(comp) == 'number' and comp ~= 0 then
            compHash = comp
        elseif type(comp) == 'string' then
            if comp:upper():find('^COMPONENT_') then
                compHash = GetHashKey(comp)
            elseif oxItems and oxItems[comp] and oxItems[comp].client and oxItems[comp].client.component then
                for _, model in pairs(oxItems[comp].client.component) do
                    local h = type(model) == 'string' and GetHashKey(model) or tonumber(model)
                    if h and DoesWeaponTakeWeaponComponent(weaponHash, h) then compHash = h; break end
                end
            else
                local h = GetHashKey(comp)
                if DoesWeaponTakeWeaponComponent(weaponHash, h) then compHash = h end
            end
        end
        if compHash and DoesWeaponTakeWeaponComponent(weaponHash, compHash) then
            result[#result + 1] = compHash
        end
    end
    return result
end

_G.WeaponAdapter = WeaponAdapter
return WeaponAdapter
