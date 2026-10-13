local SlingDatabaseService = {}
local cachedCatalog = {}

local function revisionOf(records)
    local encoded = json.encode(records or {})
    local hash = 0
    for i = 1, #encoded do
        hash = (hash * 31 + string.byte(encoded, i)) % 4294967296
    end
    return string.format('%08x', hash)
end

local function hasAdminPerms(src)
    if not src or src <= 0 then return false end
    if exports['mri_Qadmin'] and exports['mri_Qadmin'].HasPerms then
        local ok, res = pcall(function() return exports['mri_Qadmin']:HasPerms(src, 'qadmin.slings') end)
        if ok and res then return true end
    end
    if SlingEditorService and SlingEditorService.isAdmin and SlingEditorService.isAdmin(src) then return true end
    return IsPlayerAceAllowed(tostring(src), 'command') or IsPlayerAceAllowed(tostring(src), 'admin') or false
end

function SlingDatabaseService.broadcast()
    local catalogList = {}
    local seen = {}
    for _, item in pairs(cachedCatalog) do
        if item.id and not seen[item.id] then
            seen[item.id] = true
            catalogList[#catalogList + 1] = item
        end
    end
    table.sort(catalogList, function(a, b) return tostring(a.label) < tostring(b.label) end)
    GlobalState.slingCatalog = cachedCatalog
    TriggerClientEvent('dp_gameplay:client:syncSlingCatalog', -1, cachedCatalog)
    return catalogList
end

function SlingDatabaseService.reload()
    local rows = MySQL.query.await('SELECT * FROM `dp_slings` ORDER BY `label` ASC') or {}
    cachedCatalog = {}
    for i = 1, #rows do
        local r = rows[i]
        local rawKey = tostring(r.item_name or '')
        local lowKey = string.lower(rawKey)
        if lowKey ~= '' then
            local entry = {
                id = r.id, item_name = rawKey, label = r.label or rawKey, prop_model = r.prop_model or rawKey,
                category = r.category or 'weapon', bone = tonumber(r.bone) or 24818,
                x = tonumber(r.x) or 0.0, y = tonumber(r.y) or 0.0, z = tonumber(r.z) or 0.0,
                x_rot = tonumber(r.x_rot) or 0.0, y_rot = tonumber(r.y_rot) or 0.0, z_rot = tonumber(r.z_rot) or 0.0,
                is_enabled = (r.is_enabled == 1 or r.is_enabled == true) and true or false
            }
            cachedCatalog[lowKey] = entry
            cachedCatalog[string.upper(lowKey)] = entry
            local stripped = lowKey:gsub('^weapon_', '')
            if stripped ~= '' then
                cachedCatalog[stripped] = entry
                cachedCatalog[string.upper(stripped)] = entry
            end
        end
    end
    return SlingDatabaseService.broadcast()
end

local function seedDefaults()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `dp_slings`') or 0
    if count == 0 and ConfigSlingsSeed then
        for _, item in ipairs(ConfigSlingsSeed) do
            MySQL.insert.await([[
                INSERT INTO `dp_slings` 
                (`item_name`, `label`, `prop_model`, `category`, `bone`, `x`, `y`, `z`, `x_rot`, `y_rot`, `z_rot`, `is_enabled`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            ]], { item.item_name, item.label, item.prop_model, item.category, item.bone, item.x, item.y, item.z, item.x_rot, item.y_rot, item.z_rot })
        end
        print('^2[dp_gameplay] Tabela dp_slings inicializada com ' .. #ConfigSlingsSeed .. ' itens do catálogo padrão!^7')
    end
end

function SlingDatabaseService.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `dp_slings` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `item_name` VARCHAR(50) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL,
            `prop_model` VARCHAR(100) NOT NULL,
            `category` VARCHAR(50) NOT NULL DEFAULT 'weapon',
            `bone` INT NOT NULL DEFAULT 24818,
            `x` FLOAT NOT NULL DEFAULT 0.0, `y` FLOAT NOT NULL DEFAULT 0.0, `z` FLOAT NOT NULL DEFAULT 0.0,
            `x_rot` FLOAT NOT NULL DEFAULT 0.0, `y_rot` FLOAT NOT NULL DEFAULT 0.0, `z_rot` FLOAT NOT NULL DEFAULT 0.0,
            `is_enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_category` (`category`), INDEX `idx_enabled` (`is_enabled`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    seedDefaults()
    GlobalState.slingsEnabled = true
    SlingDatabaseService.reload()

    lib.callback.register('dp_gameplay:server:getSlingCatalog', function(source)
        if not hasAdminPerms(source) then return { ok = false, message = 'Sem permissão.' } end
        local list = {}
        local seen = {}
        for _, v in pairs(cachedCatalog) do
            if v.id and not seen[v.id] then
                seen[v.id] = true
                list[#list + 1] = v
            end
        end
        table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
        return { ok = true, data = { records = list, revision = revisionOf(list), enabled = GlobalState.slingsEnabled } }
    end)

    lib.callback.register('dp_gameplay:server:saveSlingItem', function(source, payload, clientRevision)
        if not hasAdminPerms(source) then return { ok = false, message = 'Sem permissão.' } end
        if not payload or not payload.item_name then return { ok = false, message = 'Dados incompletos.' } end

        local rawItemName = string.gsub(tostring(payload.item_name), '%s+', '')
        local itemName = rawItemName:upper():find('^WEAPON_') and rawItemName:upper() or rawItemName
        local label = tostring(payload.label or itemName)
        local prop = tostring(payload.prop_model or itemName)
        local cat = tostring(payload.category or 'weapon')
        local bone = tonumber(payload.bone) or 24818
        local x = math.max(-2.0, math.min(2.0, tonumber(payload.x) or 0.0))
        local y = math.max(-2.0, math.min(2.0, tonumber(payload.y) or 0.0))
        local z = math.max(-2.0, math.min(2.0, tonumber(payload.z) or 0.0))
        local xr = math.max(-360.0, math.min(360.0, tonumber(payload.x_rot) or 0.0))
        local yr = math.max(-360.0, math.min(360.0, tonumber(payload.y_rot) or 0.0))
        local zr = math.max(-360.0, math.min(360.0, tonumber(payload.z_rot) or 0.0))
        local isEnabled = (payload.is_enabled == nil or payload.is_enabled == true or payload.is_enabled == 1) and 1 or 0

        MySQL.query.await([[
            INSERT INTO `dp_slings` (`item_name`, `label`, `prop_model`, `category`, `bone`, `x`, `y`, `z`, `x_rot`, `y_rot`, `z_rot`, `is_enabled`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
            `label` = VALUES(`label`), `prop_model` = VALUES(`prop_model`), `category` = VALUES(`category`),
            `bone` = VALUES(`bone`), `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`),
            `x_rot` = VALUES(`x_rot`), `y_rot` = VALUES(`y_rot`), `z_rot` = VALUES(`z_rot`), `is_enabled` = VALUES(`is_enabled`);
        ]], { itemName, label, prop, cat, bone, x, y, z, xr, yr, zr, isEnabled })

        if exports['mri_Qadmin'] and exports['mri_Qadmin'].AddLog then
            exports['mri_Qadmin']:AddLog(GetCurrentResourceName(), 'slings', 'info',
                string.format('Admin %s salvou o item sling: %s', GetPlayerName(source), itemName), payload)
        end

        local updated = SlingDatabaseService.reload()
        return { ok = true, message = 'Item salvo com sucesso!', data = { records = updated, revision = revisionOf(updated) } }
    end)

    lib.callback.register('dp_gameplay:server:deleteSlingItem', function(source, itemName)
        if not hasAdminPerms(source) then return { ok = false, message = 'Sem permissão.' } end
        local key = string.lower(tostring(itemName or ''))
        MySQL.query.await('DELETE FROM `dp_slings` WHERE LOWER(`item_name`) = ?', { key })
        if exports['mri_Qadmin'] and exports['mri_Qadmin'].AddLog then
            exports['mri_Qadmin']:AddLog(GetCurrentResourceName(), 'slings', 'warn',
                string.format('Admin %s removeu o item sling: %s', GetPlayerName(source), key))
        end
        local updated = SlingDatabaseService.reload()
        return { ok = true, message = 'Item removido!', data = { records = updated, revision = revisionOf(updated) } }
    end)

    lib.callback.register('dp_gameplay:server:toggleGlobalSlings', function(source, newState)
        if not hasAdminPerms(source) then return { ok = false, message = 'Sem permissão.' } end
        GlobalState.slingsEnabled = newState and true or false
        TriggerClientEvent('dp_gameplay:client:syncGlobalSlings', -1, GlobalState.slingsEnabled)
        return { ok = true, enabled = GlobalState.slingsEnabled }
    end)

    lib.callback.register('dp_gameplay:server:toggleSlingItem', function(source, itemName, newState)
        if not hasAdminPerms(source) then return { ok = false, message = 'Sem permissão.' } end
        local key = string.lower(tostring(itemName or ''))
        local val = (newState == true or newState == 1) and 1 or 0
        MySQL.query.await('UPDATE `dp_slings` SET `is_enabled` = ? WHERE LOWER(`item_name`) = ?', { val, key })
        local updated = SlingDatabaseService.reload()
        return { ok = true, data = { records = updated, revision = revisionOf(updated) } }
    end)
end

_G.SlingDatabaseService = SlingDatabaseService
return SlingDatabaseService
