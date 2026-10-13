-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | ARMA FRENTE MODULE (CLIENT) - Zero-Loops / Multi-Bone / 0.00ms
-----------------------------------------------------------------------------------------------------------------------------------------

local ArmaFrenteModule = {}
local trackedAttached = {} -- [serverId] = { [bone] = { handle = ent, sig = sig, wepHash = hash } }
local pedToServerId = {}   -- [pedHandle] = serverId

local function deleteBoneAttachment(serverId, bone)
    if trackedAttached[serverId] and trackedAttached[serverId][bone] then
        WeaponAdapter.deleteEntity(trackedAttached[serverId][bone].handle)
        trackedAttached[serverId][bone] = nil
    end
end

local function deletePlayerAttachedWeapons(serverId)
    if trackedAttached[serverId] then
        for bone in pairs(trackedAttached[serverId]) do deleteBoneAttachment(serverId, bone) end
        trackedAttached[serverId] = nil
    end
end

local function computeSignature(wepHash, bone, off, comps, tint)
    return string.format('%s_%d_%d_%.2f_%.2f_%.2f_%s', tostring(wepHash), bone, tint or 0, off.x or 0, off.y or 0, off.z or 0, table.concat(comps or {}, ','))
end

local function getPedFromNetId(netId, myServerId)
    if not netId then return nil end
    if netId == myServerId then return (cache.ped or PlayerPedId()) end
    local p = GetPlayerFromServerId(netId)
    return (p ~= -1) and GetPlayerPed(p) or nil
end

local function attachItemToPed(ped, serverId, item, bone)
    if not DoesEntityExist(ped) then return end
    bone = bone or tonumber(item.bone) or 24818
    local upperName = tostring(item.name or item.item_name or ''):upper()
    local wepName = upperName:find('^WEAPON_') and upperName or ('WEAPON_' .. upperName)
    local wepHash = (wepName ~= '' and GetHashKey(wepName)) or item.hash or 0
    local off = item.offset or (ConfigWeapons and ConfigWeapons.slingOffset) or { x = -0.005, y = 0.185, z = 0.055, x_rot = 1.5, y_rot = 134.5, z_rot = -4.5 }

    local components, tint = WeaponAdapter.resolveComponentsAndTint(wepHash, item, serverId)
    local sig = computeSignature(wepHash ~= 0 and wepHash or item.prop, bone, off, components, tint)

    if trackedAttached[serverId] and trackedAttached[serverId][bone] and trackedAttached[serverId][bone].sig == sig and DoesEntityExist(trackedAttached[serverId][bone].handle) then
        return
    end

    deleteBoneAttachment(serverId, bone)
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

    if not trackedAttached[serverId] then trackedAttached[serverId] = {} end
    trackedAttached[serverId][bone] = { handle = ent, sig = sig, wepHash = wepHash }
end

local function updatePedSling(ped, serverId, slingItems)
    if not DoesEntityExist(ped) or PedAdapter.isDeadOrDown(ped) or GlobalState.slingsEnabled == false then
        return deletePlayerAttachedWeapons(serverId)
    end
    local myServerId = cache.serverId or GetPlayerServerId(PlayerId())
    if (serverId == myServerId) and SlingEditorModule and SlingEditorModule.isActive and SlingEditorModule.isActive() then
        return deletePlayerAttachedWeapons(serverId)
    end

    local itemsCount = (slingItems and type(slingItems) == 'table') and #slingItems or 0
    if itemsCount == 0 then return deletePlayerAttachedWeapons(serverId) end

    local targetByBone = {}
    for _, item in ipairs(slingItems) do
        local bone = tonumber(item.bone) or (ConfigWeapons and ConfigWeapons.slingBone) or 24818
        if not targetByBone[bone] and not WeaponAdapter.isWeaponInHand(ped, item) then
            targetByBone[bone] = item
        end
    end

    if trackedAttached[serverId] then
        for bone in pairs(trackedAttached[serverId]) do
            if not targetByBone[bone] then deleteBoneAttachment(serverId, bone) end
        end
    end

    for bone, item in pairs(targetByBone) do attachItemToPed(ped, serverId, item, bone) end
end

function ArmaFrenteModule.cleanOrphans(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local objects = GetGamePool('CObject')
    for i = 1, #objects do
        local obj = objects[i]
        if DoesEntityExist(obj) and IsEntityAttachedToEntity(obj, ped) then
            local tracked = false
            for _, bones in pairs(trackedAttached) do
                for _, d in pairs(bones) do if d.handle == obj then tracked = true; break end end
                if tracked then break end
            end
            if not tracked then WeaponAdapter.deleteEntity(obj) end
        end
    end
end

function ArmaFrenteModule.refreshAll()
    for s in pairs(trackedAttached) do deletePlayerAttachedWeapons(s) end
    local myId, myPed = cache.serverId or GetPlayerServerId(PlayerId()), cache.ped or PlayerPedId()
    ArmaFrenteModule.cleanOrphans(myPed)
    updatePedSling(myPed, myId, Player(myId).state.slingWeapons)
end

function ArmaFrenteModule.init()
    local myServerId = cache.serverId or GetPlayerServerId(PlayerId())
    ArmaFrenteModule.cleanOrphans(cache.ped or PlayerPedId())

    local onLocalWeaponChange = function(wep)
        local wepHash = type(wep) == 'table' and (wep.hash or (wep.name and GetHashKey(wep.name)) or 0) or tonumber(wep) or GetHashKey(wep or '')
        LocalPlayer.state:set('currentWeapon', wepHash, true)
        updatePedSling(cache.ped or PlayerPedId(), myServerId, Player(myServerId).state.slingWeapons)
    end
    AddEventHandler('ox_inventory:currentWeapon', onLocalWeaponChange)
    lib.onCache('weapon', onLocalWeaponChange)
    TriggerServerEvent('dp_gameplay:server:requestSlingSync')

    local onBagUpdate = function(bagName, customVal, isDead)
        local netId = tonumber(bagName:gsub('player:', ''), 10)
        if not netId then return end
        if isDead then return deletePlayerAttachedWeapons(netId) end
        local ped = getPedFromNetId(netId, myServerId)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pedToServerId[ped] = netId
            local items = (customVal ~= nil) and customVal or Player(netId).state.slingWeapons
            updatePedSling(ped, netId, items)
        end
    end

    RegisterNetEvent('dp_gameplay:client:syncPlayerSlings', function(items)
        updatePedSling(cache.ped or PlayerPedId(), myServerId, items)
    end)

    AddStateBagChangeHandler('slingWeapons', nil, function(b, _, v) onBagUpdate(b, v, false) end)
    AddStateBagChangeHandler('currentWeapon', nil, function(b) onBagUpdate(b, nil, false) end)
    AddStateBagChangeHandler('vipWeaponAttachs', nil, function(b) onBagUpdate(b, nil, false) end)
    AddStateBagChangeHandler('vipWeaponTints', nil, function(b) onBagUpdate(b, nil, false) end)
    local onDead = function(b, _, d) onBagUpdate(b, nil, d and (type(d) ~= 'number' or d ~= 0)) end
    AddStateBagChangeHandler('isDead', nil, onDead)
    AddStateBagChangeHandler('dead', nil, onDead)
    AddStateBagChangeHandler('qbx_medical:deathState', nil, onDead)

    AddEventHandler('onEntityStreamIn', function(ent)
        if not DoesEntityExist(ent) or not IsEntityAPed(ent) or not IsPedAPlayer(ent) then return end
        local p = NetworkGetPlayerIndexFromPed(ent)
        local sId = (p ~= -1) and GetPlayerServerId(p)
        if sId and sId > 0 then
            pedToServerId[ent] = sId
            local st = Player(sId).state
            if st and st.slingWeapons then updatePedSling(ent, sId, st.slingWeapons) end
        end
    end)

    AddEventHandler('onEntityStreamOut', function(entity)
        local sId = pedToServerId[entity]
        if sId then deletePlayerAttachedWeapons(sId); pedToServerId[entity] = nil end
    end)

    AddStateBagChangeHandler('slingsEnabled', 'global', function(_, _, val)
        if val == false then for s in pairs(trackedAttached) do deletePlayerAttachedWeapons(s) end
        else ArmaFrenteModule.refreshAll() end
    end)

    AddEventHandler('ox_inventory:updateInventory', function(changes)
        if not changes or type(changes) ~= 'table' then return end
        for slot in pairs(changes) do
            local s = tonumber(slot)
            if s and s >= 1 and s <= 5 then TriggerServerEvent('dp_gameplay:server:requestSlingSync'); break end
        end
    end)
    RegisterNetEvent('ox_inventory:updateSlots', function() TriggerServerEvent('dp_gameplay:server:requestSlingSync') end)

    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then
            for s in pairs(trackedAttached) do deletePlayerAttachedWeapons(s) end
            trackedAttached, pedToServerId = {}, {}
        end
    end)
end

_G.ArmaFrenteModule = ArmaFrenteModule
return ArmaFrenteModule
