-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | ARMA FRENTE MODULE (CLIENT)
-- Responsabilidade: Gestão visual 100% orientada a eventos (Zero-Loops / 0.00ms) de armas no peito (Sling) via OneSync
-----------------------------------------------------------------------------------------------------------------------------------------

local ArmaFrenteModule = {}
local trackedAttached = {} -- [serverId] = { handle = entity, sig = string, wepHash = number }
local pedToServerId = {}   -- [pedHandle] = serverId

local function deletePlayerAttachedWeapon(serverId)
    if trackedAttached[serverId] then
        WeaponAdapter.deleteEntity(trackedAttached[serverId].handle)
        trackedAttached[serverId] = nil
    end
end

local function computeSignature(wepHash, bone, off, comps, tint)
    local cList = {}
    for i = 1, #comps do cList[i] = tostring(comps[i]) end
    return string.format('%s_%d_%d_%.2f_%.2f_%.2f_%s', tostring(wepHash), bone, tint or 0, off.x or 0, off.y or 0, off.z or 0, table.concat(cList, ','))
end

local function getPedFromNetId(netId, myServerId)
    if not netId then return nil end
    if netId == myServerId then return (cache.ped or PlayerPedId()) end
    local p = GetPlayerFromServerId(netId)
    return (p ~= -1) and GetPlayerPed(p) or nil
end

local function attachItemToPed(ped, serverId, item)
    if not DoesEntityExist(ped) then return end
    local upperName = tostring(item.name or item.item_name or ''):upper()
    local wepName = upperName:find('^WEAPON_') and upperName or ('WEAPON_' .. upperName)
    local wepHash = (wepName ~= '' and GetHashKey(wepName)) or item.hash or 0
    local bone = tonumber(item.bone) or (ConfigWeapons and ConfigWeapons.slingBone) or 24818
    local off = item.offset or (ConfigWeapons and ConfigWeapons.slingOffset) or { x = -0.005, y = 0.185, z = 0.055, x_rot = 1.5, y_rot = 134.5, z_rot = -4.5 }
    local tint = tonumber(item.tint) or 0

    local rawComponents = WeaponAdapter.getComponentHashes(wepHash, item.components)
    local playerState = Player(serverId).state
    if playerState then
        local vipAttachs, vipTints = playerState.vipWeaponAttachs, playerState.vipWeaponTints
        if vipAttachs and vipAttachs[wepHash] then
            for compHash, isEq in pairs(vipAttachs[wepHash]) do
                local numCompHash = tonumber(compHash)
                if numCompHash and isEq then rawComponents[#rawComponents + 1] = numCompHash end
            end
        end
        if vipTints and vipTints[wepHash] ~= nil then tint = tonumber(vipTints[wepHash]) or tint end
    end

    local uniqueMap, components = {}, {}
    for _, compHash in ipairs(rawComponents) do
        local cHash = tonumber(compHash)
        if cHash and cHash ~= 0 and not uniqueMap[cHash] and DoesWeaponTakeWeaponComponent(wepHash, cHash) then
            uniqueMap[cHash] = true; components[#components + 1] = cHash
        end
    end
    table.sort(components)

    local sig = computeSignature(wepHash ~= 0 and wepHash or item.prop, bone, off, components, tint)
    if trackedAttached[serverId] and trackedAttached[serverId].sig == sig and DoesEntityExist(trackedAttached[serverId].handle) then
        return
    end

    deletePlayerAttachedWeapon(serverId)
    if not DoesEntityExist(ped) then return end

    local ent, isWeapon = WeaponAdapter.spawnSlingEntity(item)
    if not ent or not DoesEntityExist(ent) then return end

    SetEntityAsMissionEntity(ent, true, true)
    if isWeapon then
        for _, c in ipairs(components) do GiveWeaponComponentToWeaponObject(ent, c) end
        if tint > 0 then SetWeaponObjectTintIndex(ent, tint) end
    end

    SetEntityCollision(ent, false, false)
    local boneIndex = GetPedBoneIndex(ped, bone)
    AttachEntityToEntity(ent, ped, boneIndex, off.x, off.y, off.z, off.x_rot, off.y_rot, off.z_rot, 1, 1, 0, 0, 2, 1)
    trackedAttached[serverId] = { handle = ent, sig = sig, wepHash = wepHash }
end

local function updatePedSling(ped, serverId, slingItems)
    if not DoesEntityExist(ped) or PedAdapter.isDeadOrDown(ped) or GlobalState.slingsEnabled == false then
        return deletePlayerAttachedWeapon(serverId)
    end
    local myServerId = cache.serverId or GetPlayerServerId(PlayerId())
    if (serverId == myServerId) and SlingEditorModule and SlingEditorModule.isActive and SlingEditorModule.isActive() then
        return deletePlayerAttachedWeapon(serverId)
    end

    local itemsCount = (slingItems and type(slingItems) == 'table') and #slingItems or 0
    if itemsCount > 0 then
        local targetWeapon = nil
        for _, item in ipairs(slingItems) do
            if not WeaponAdapter.isWeaponInHand(ped, item) then targetWeapon = item; break end
        end
        if targetWeapon then attachItemToPed(ped, serverId, targetWeapon) else deletePlayerAttachedWeapon(serverId) end
    else
        deletePlayerAttachedWeapon(serverId)
    end
end

function ArmaFrenteModule.refreshAll()
    for s in pairs(trackedAttached) do deletePlayerAttachedWeapon(s) end
    local myId = cache.serverId or GetPlayerServerId(PlayerId())
    updatePedSling(cache.ped or PlayerPedId(), myId, Player(myId).state.slingWeapons)
end

function ArmaFrenteModule.init()
    local myServerId = cache.serverId or GetPlayerServerId(PlayerId())

    -- 1. Troca de arma local (notifica sling e propaga StateBag OneSync para terceiros)
    local onLocalWeaponChange = function(wep)
        local wepHash = 0
        if type(wep) == 'table' then
            wepHash = wep.hash or (wep.name and GetHashKey(wep.name)) or 0
        elseif type(wep) == 'number' or type(wep) == 'string' then
            wepHash = tonumber(wep) or GetHashKey(wep)
        end
        LocalPlayer.state:set('currentWeapon', wepHash, true)
        updatePedSling(cache.ped or PlayerPedId(), myServerId, Player(myServerId).state.slingWeapons)
    end
    AddEventHandler('ox_inventory:currentWeapon', onLocalWeaponChange)
    lib.onCache('weapon', onLocalWeaponChange)

    -- Sincronização inicial pontual na inicialização (zero loops)
    TriggerServerEvent('dp_gameplay:server:requestSlingSync')

    -- 2. Handler Reativo Unificado de StateBags (slingWeapons, currentWeapon, VIPs, óbito)
    local onBagUpdate = function(bagName, isDead)
        local netId = tonumber(bagName:gsub('player:', ''), 10)
        if not netId then return end
        if isDead then return deletePlayerAttachedWeapon(netId) end
        local ped = getPedFromNetId(netId, myServerId)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pedToServerId[ped] = netId
            updatePedSling(ped, netId, Player(netId).state.slingWeapons)
        end
    end

    AddStateBagChangeHandler('slingWeapons', nil, function(b) onBagUpdate(b, false) end)
    AddStateBagChangeHandler('currentWeapon', nil, function(b) onBagUpdate(b, false) end)
    AddStateBagChangeHandler('vipWeaponAttachs', nil, function(b) onBagUpdate(b, false) end)
    AddStateBagChangeHandler('vipWeaponTints', nil, function(b) onBagUpdate(b, false) end)
    AddStateBagChangeHandler('isDead', nil, function(b, _, d) onBagUpdate(b, d) end)
    AddStateBagChangeHandler('dead', nil, function(b, _, d) onBagUpdate(b, d) end)
    AddStateBagChangeHandler('qbx_medical:deathState', nil, function(b, _, d) onBagUpdate(b, d and d ~= 0) end)

    -- 3. Entrada e Saída de Escopo Visual (OneSync entity streaming)
    AddEventHandler('onEntityStreamIn', function(entity)
        if not DoesEntityExist(entity) or not IsEntityAPed(entity) or not IsPedAPlayer(entity) then return end
        local player = NetworkGetPlayerIndexFromPed(entity)
        if player == -1 then return end
        local sId = GetPlayerServerId(player)
        if sId and sId > 0 then
            pedToServerId[entity] = sId
            local pState = Player(sId).state
            if pState and pState.slingWeapons then updatePedSling(entity, sId, pState.slingWeapons) end
        end
    end)

    AddEventHandler('onEntityStreamOut', function(entity)
        local sId = pedToServerId[entity]
        if sId then deletePlayerAttachedWeapon(sId); pedToServerId[entity] = nil end
    end)

    -- 4. Monitoramento do Catálogo Global
    AddStateBagChangeHandler('slingsEnabled', 'global', function(_, _, val)
        if val == false then for s in pairs(trackedAttached) do deletePlayerAttachedWeapon(s) end
        else ArmaFrenteModule.refreshAll() end
    end)

    -- 5. Listener passivo local caso ocorra alteração na hotbar (slots 1..5)
    AddEventHandler('ox_inventory:updateInventory', function(changes)
        if not changes or type(changes) ~= 'table' then return end
        for slot in pairs(changes) do
            local s = tonumber(slot)
            if s and s >= 1 and s <= 5 then
                TriggerServerEvent('dp_gameplay:server:requestSlingSync')
                break
            end
        end
    end)

    -- 6. Limpeza determinística ao parar o recurso
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then
            for s in pairs(trackedAttached) do deletePlayerAttachedWeapon(s) end
            trackedAttached, pedToServerId = {}, {}
        end
    end)
end

_G.ArmaFrenteModule = ArmaFrenteModule
return ArmaFrenteModule
