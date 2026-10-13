local InventoryAdapter = {}

function InventoryAdapter.registerHook(eventName, callback)
    if GetResourceState('ox_inventory') == 'started' then
        pcall(function()
            exports.ox_inventory:registerHook(eventName, callback)
        end)
    end
end

function InventoryAdapter.getPlayerInventory(src)
    if GetResourceState('ox_inventory') == 'started' then
        local inv = exports.ox_inventory:GetInventory(src)
        return inv and inv.items or {}
    end
    return {}
end

function InventoryAdapter.removeItem(src, item, count)
    if vanguard and vanguard.inventory and vanguard.inventory.removeItem then
        return vanguard.inventory.removeItem(src, item, count or 1)
    end
    if exports.ox_inventory then
        return exports.ox_inventory:RemoveItem(src, item, count or 1)
    end
    return false
end

_G.InventoryAdapter = InventoryAdapter
return InventoryAdapter
