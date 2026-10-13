-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | INVENTORY ADAPTER (SERVER)
-- Responsabilidade: Abstração de integração com ox_inventory e observador reativo de Hotbar (Slots 1..5)
-----------------------------------------------------------------------------------------------------------------------------------------

local InventoryAdapter = {}

local function isOxReady()
    return GetResourceState('ox_inventory') == 'started'
end

function InventoryAdapter.isHotbarSlot(slot)
    local s = tonumber(slot)
    return s and s >= 1 and s <= 5
end

function InventoryAdapter.getPlayerInventory(src)
    if not isOxReady() or not src or src <= 0 then return {} end
    local ok, inv = pcall(function() return exports.ox_inventory:GetInventory(src) end)
    return (ok and inv and inv.items) or {}
end

function InventoryAdapter.getItemDefinition(itemName)
    if not isOxReady() or not itemName then return nil end
    local ok, item = pcall(function() return exports.ox_inventory:Items(itemName) end)
    return ok and item or nil
end

function InventoryAdapter.removeItem(src, item, count)
    if not src or src <= 0 then return false end
    if vanguard and vanguard.inventory and vanguard.inventory.removeItem then
        return vanguard.inventory.removeItem(src, item, count or 1)
    end
    if isOxReady() then
        local ok, res = pcall(function() return exports.ox_inventory:RemoveItem(src, item, count or 1) end)
        return ok and res or false
    end
    return false
end

function InventoryAdapter.registerHook(eventName, callback)
    if isOxReady() then
        pcall(function() exports.ox_inventory:registerHook(eventName, callback) end)
    end
end

--- Observador reativo de alta performance focado estritamente na hotbar (slots 1..5)
function InventoryAdapter.registerHotbarObserver(callback)
    if not isOxReady() then return end

    local function notifyTarget(target)
        local src = tonumber(target)
        if src and src > 0 and GetPlayerPing(src) > 0 then
            callback(src)
        end
    end

    -- Hook: swapItems (cobre movimentação entre slots, desarmar, puxar para mão, transferências)
    InventoryAdapter.registerHook('swapItems', function(payload)
        if not payload then return true end
        local fromSlot = type(payload.fromSlot) == 'table' and payload.fromSlot.slot or tonumber(payload.fromSlot)
        local toSlot = type(payload.toSlot) == 'table' and payload.toSlot.slot or tonumber(payload.toSlot)

        if InventoryAdapter.isHotbarSlot(fromSlot) or InventoryAdapter.isHotbarSlot(toSlot) then
            notifyTarget(payload.fromInventory)
            notifyTarget(payload.toInventory)
        end
        return true
    end)

    -- Hook: buyItem (compras em lojas direto para o hotbar)
    InventoryAdapter.registerHook('buyItem', function(payload)
        if not payload then return true end
        if payload.toSlot == nil or InventoryAdapter.isHotbarSlot(payload.toSlot) then
            notifyTarget(payload.toInventory)
        end
        return true
    end)

    -- Hook: createItem (criação via scripts/admin/AddItem)
    InventoryAdapter.registerHook('createItem', function(payload)
        if payload and payload.inventoryId then
            notifyTarget(payload.inventoryId)
        end
        return true
    end)

    -- Hook: craftItem (fabricação que caia no inventário do jogador)
    InventoryAdapter.registerHook('craftItem', function(payload)
        if payload and payload.inventoryId then
            notifyTarget(payload.inventoryId)
        end
        return true
    end)

    -- Evento nativo usedItem (caso arma ou acessório sofra desgaste/alteração)
    RegisterNetEvent('ox_inventory:usedItem', function(inventoryId, _, slot)
        if InventoryAdapter.isHotbarSlot(slot) then
            notifyTarget(inventoryId)
        end
    end)
end

_G.InventoryAdapter = InventoryAdapter
return InventoryAdapter
