local ArmaFrenteModule = {}

local trackedAttached = {} -- [serverId] = { handle = ent, sig = sig, wepHash = hash }

local function deletePlayerAttachedWeapon(serverId)
    if trackedAttached[serverId] then
        print(string.format('^1[ArmaFrente] deletePlayerAttachedWeapon | serverId=%s | handle=%s^7', tostring(serverId), tostring(trackedAttached[serverId].handle)))
        WeaponAdapter.deleteEntity(trackedAttached[serverId].handle)
        trackedAttached[serverId] = nil
    end
end

local function computeSignature(wepHash, bone, off, comps, tint)
    local cList = {}
    for i = 1, #comps do cList[i] = tostring(comps[i]) end
    return string.format('%s_%d_%d_%.2f_%.2f_%.2f_%s', tostring(wepHash), bone, tint or 0, off.x or 0, off.y or 0, off.z or 0, table.concat(cList, ','))
end

local function attachItemToPed(ped, serverId, item)
    if not DoesEntityExist(ped) then return end
    local upperName = tostring(item.name or item.item_name or ''):upper()
    local wepName = upperName:find('^WEAPON_') and upperName or ('WEAPON_' .. upperName)
    local wepHash = (wepName ~= '' and GetHashKey(wepName)) or item.hash or 0
    local bone = tonumber(item.bone) or (ConfigWeapons and ConfigWeapons.slingBone) or 24818
    local off = item.offset or (ConfigWeapons and ConfigWeapons.slingOffset) or { x = -0.02, y = 0.22, z = -0.06, x_rot = 0.0, y_rot = -30.0, z_rot = 180.0 }
    local tint = tonumber(item.tint) or 0

    print(string.format('^2[ArmaFrente] attachItemToPed | serverId=%s | item=%s | wepHash=%s | bone=%s^7', tostring(serverId), wepName, tostring(wepHash), tostring(bone)))

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
        print(string.format('^3[ArmaFrente] Item %s ja anexado com mesma assinatura (%s). Ignorando.^7', wepName, sig))
        return
    end

    deletePlayerAttachedWeapon(serverId)
    if not DoesEntityExist(ped) then return end

    local ent, isWeapon = WeaponAdapter.spawnSlingEntity(item)
    if not ent or not DoesEntityExist(ent) then
        print(string.format('^1[ArmaFrente] FALHA: spawnSlingEntity retornou entidade invalida (%s) para %s^7', tostring(ent), wepName))
        return
    end

    SetEntityAsMissionEntity(ent, true, true)
    if isWeapon then
        for _, c in ipairs(components) do GiveWeaponComponentToWeaponObject(ent, c) end
        if tint > 0 then SetWeaponObjectTintIndex(ent, tint) end
    end

    SetEntityCollision(ent, false, false)
    local boneIndex = GetPedBoneIndex(ped, bone)
    AttachEntityToEntity(ent, ped, boneIndex, off.x, off.y, off.z, off.x_rot, off.y_rot, off.z_rot, 1, 1, 0, 0, 2, 1)

    trackedAttached[serverId] = { handle = ent, sig = sig, wepHash = wepHash }
    print(string.format('^2[ArmaFrente] SUCESSO: Arma %s (handle=%s) anexada no ped=%s osso=%s boneIdx=%s!^7', wepName, tostring(ent), tostring(ped), tostring(bone), tostring(boneIndex)))
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
    print(string.format('^4[ArmaFrente] updatePedSling | serverId=%s | itemsCount=%d^7', tostring(serverId), itemsCount))

    if itemsCount > 0 then
        local targetWeapon = nil
        for idx, item in ipairs(slingItems) do
            local inHand = WeaponAdapter.isWeaponInHand(ped, item)
            print(string.format('^4[ArmaFrente] Item [%d] %s (slot %s) | inHand=%s^7', idx, tostring(item.name), tostring(item.slot), tostring(inHand)))
            if not inHand then targetWeapon = item; break end
        end

        if targetWeapon then
            print(string.format('^2[ArmaFrente] Target weapon selecionada: %s (slot %s)^7', tostring(targetWeapon.name), tostring(targetWeapon.slot)))
            attachItemToPed(ped, serverId, targetWeapon)
        else
            print('^3[ArmaFrente] Nenhuma arma livre para sling (todas em maos ou vazias). Limpando peito.^7')
            deletePlayerAttachedWeapon(serverId)
        end
    else
        deletePlayerAttachedWeapon(serverId)
    end
end

function ArmaFrenteModule.refreshAll()
    print('^3[ArmaFrente] refreshAll invocado!^7')
    for s in pairs(trackedAttached) do deletePlayerAttachedWeapon(s) end
    local myId = cache.serverId or GetPlayerServerId(PlayerId())
    updatePedSling(cache.ped or PlayerPedId(), myId, Player(myId).state.slingWeapons)
end

function ArmaFrenteModule.init()
    local onWeaponChange = function(ev)
        local myId = cache.serverId or GetPlayerServerId(PlayerId())
        print(string.format('^3[ArmaFrente] Evento de troca de arma (%s) disparado! myId=%s^7', tostring(ev or 'cache'), tostring(myId)))
        updatePedSling(cache.ped or PlayerPedId(), myId, Player(myId).state.slingWeapons)
    end
    AddEventHandler('ox_inventory:currentWeapon', function(_) onWeaponChange('ox_inventory:currentWeapon') end)
    lib.onCache('weapon', function(_) onWeaponChange('lib.onCache:weapon') end)

    RegisterNetEvent('dp_gameplay:client:syncPlayerSlings', function(list)
        local myId = cache.serverId or GetPlayerServerId(PlayerId())
        print(string.format('^2[ArmaFrente] Evento direto dp_gameplay:client:syncPlayerSlings recebido: %s^7', json.encode(list)))
        updatePedSling(cache.ped or PlayerPedId(), myId, list)
    end)

    AddStateBagChangeHandler('slingWeapons', nil, function(bagName, _, val)
        local netId = tonumber(bagName:gsub('player:', ''), 10)
        if not netId then return end
        local isLocal = (netId == (cache.serverId or GetPlayerServerId(PlayerId())))
        local player = GetPlayerFromServerId(netId)
        if player == -1 and not isLocal then return end
        local ped = isLocal and (cache.ped or PlayerPedId()) or GetPlayerPed(player)
        print(string.format('^3[ArmaFrente] StateBag slingWeapons recebido para netId=%s (isLocal=%s): %s^7', tostring(netId), tostring(isLocal), json.encode(val)))
        if ped ~= 0 and DoesEntityExist(ped) then updatePedSling(ped, netId, val) end
    end)

    local onVipStateChange = function(bagName)
        local netId = tonumber(bagName:gsub('player:', ''), 10)
        if not netId then return end
        local isLocal = (netId == (cache.serverId or GetPlayerServerId(PlayerId())))
        local player = GetPlayerFromServerId(netId)
        if player == -1 and not isLocal then return end
        local ped = isLocal and (cache.ped or PlayerPedId()) or GetPlayerPed(player)
        if ped ~= 0 and DoesEntityExist(ped) then updatePedSling(ped, netId, Player(netId).state.slingWeapons) end
    end
    AddStateBagChangeHandler('vipWeaponAttachs', nil, onVipStateChange)
    AddStateBagChangeHandler('vipWeaponTints', nil, onVipStateChange)

    AddStateBagChangeHandler('slingsEnabled', 'global', function(_, _, val)
        print(string.format('^3[ArmaFrente] GlobalState.slingsEnabled alterado para: %s^7', tostring(val)))
        if val == false then for s in pairs(trackedAttached) do deletePlayerAttachedWeapon(s) end
        else ArmaFrenteModule.refreshAll() end
    end)

    local req = function() TriggerServerEvent('showeapons:checkWeapons') end
    RegisterNetEvent('ox_inventory:itemNotify', req)
    RegisterNetEvent('ox_inventory:updateInventory', req)
    CreateThread(function() while true do req(); Wait(3000) end end)

    CreateThread(function()
        while true do
            local activePlayers = GetActivePlayers()
            local activeServerIds = {}
            for i = 1, #activePlayers do
                local player = activePlayers[i]
                local serverId = GetPlayerServerId(player)
                activeServerIds[serverId] = true
                local ped = GetPlayerPed(player)
                local pState = Player(serverId).state
                updatePedSling(ped, serverId, pState and pState.slingWeapons)
            end
            for s in pairs(trackedAttached) do
                if not activeServerIds[s] then deletePlayerAttachedWeapon(s) end
            end
            Wait(350)
        end
    end)
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then
            for s in pairs(trackedAttached) do deletePlayerAttachedWeapon(s) end
            trackedAttached = {}
        end
    end)
end

_G.ArmaFrenteModule = ArmaFrenteModule
return ArmaFrenteModule
