local SlingEditorService = {}

local currentConfig = {
    bone = 24818,
    offset = {
        x = -0.02,
        y = 0.22,
        z = -0.06,
        x_rot = 0.0,
        y_rot = -30.0,
        z_rot = 180.0
    }
}

local CONFIG_FILE = 'config/sling_custom.json'

local DEFAULT_CONFIG = {
    bone = 24818,
    offset = { x = -0.02, y = 0.22, z = -0.06, x_rot = 0.0, y_rot = -30.0, z_rot = 180.0 }
}

function SlingEditorService.isAdmin(src)
    if not src or type(src) ~= 'number' or src <= 0 then return false end
    local srcStr = tostring(src)

    if IsPlayerAceAllowed(srcStr, 'command.slingedit')
       or IsPlayerAceAllowed(srcStr, 'admin')
       or IsPlayerAceAllowed(srcStr, 'group.admin') then
        return true
    end

    if exports.qbx_core then
        local ok, res = pcall(function()
            if exports.qbx_core.HasPermission and (exports.qbx_core:HasPermission(src, 'admin') or exports.qbx_core:HasPermission(src, 'god')) then
                return true
            end
            if exports.qbx_core.HasGroup and (exports.qbx_core:HasGroup(src, 'admin') or exports.qbx_core:HasGroup(src, 'god')) then
                return true
            end
            return false
        end)
        if ok and res then return true end
    end

    if vanguard and vanguard.player then
        local ok, res = pcall(function()
            local p = vanguard.player.get(src)
            return p and p.hasPermission and (p:hasPermission('admin') or p:hasPermission('god'))
        end)
        if ok and res then return true end
    end

    return false
end

function SlingEditorService.getConfig()
    return currentConfig
end

function SlingEditorService.loadConfig()
    local raw = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE)
    local loaded = false

    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' and data.offset and type(data.offset) == 'table' then
            currentConfig.bone = tonumber(data.bone) or DEFAULT_CONFIG.bone
            currentConfig.offset = {
                x = tonumber(data.offset.x) or DEFAULT_CONFIG.offset.x,
                y = tonumber(data.offset.y) or DEFAULT_CONFIG.offset.y,
                z = tonumber(data.offset.z) or DEFAULT_CONFIG.offset.z,
                x_rot = tonumber(data.offset.x_rot) or DEFAULT_CONFIG.offset.x_rot,
                y_rot = tonumber(data.offset.y_rot) or DEFAULT_CONFIG.offset.y_rot,
                z_rot = tonumber(data.offset.z_rot) or DEFAULT_CONFIG.offset.z_rot,
            }
            loaded = true
            print('^2[dp_gameplay] Sling custom config carregada de config/sling_custom.json.^7')
        end
    end

    if not loaded then
        local def = (ConfigWeapons and ConfigWeapons.slingOffset) and ConfigWeapons.slingOffset or DEFAULT_CONFIG.offset
        currentConfig.bone = (ConfigWeapons and ConfigWeapons.slingBone) or DEFAULT_CONFIG.bone
        currentConfig.offset = {
            x = def.x or DEFAULT_CONFIG.offset.x,
            y = def.y or DEFAULT_CONFIG.offset.y,
            z = def.z or DEFAULT_CONFIG.offset.z,
            x_rot = def.x_rot or DEFAULT_CONFIG.offset.x_rot,
            y_rot = def.y_rot or DEFAULT_CONFIG.offset.y_rot,
            z_rot = def.z_rot or DEFAULT_CONFIG.offset.z_rot
        }
        print('^3[dp_gameplay] Sling config usando fallback padrao (ConfigWeapons / Default).^7')
    end
    GlobalState.slingConfig = currentConfig
end

local function sanitizeCoord(val, min, max, default)
    local n = tonumber(val)
    if not n or n ~= n then return default end
    if n < min then return min end
    if n > max then return max end
    return n
end

function SlingEditorService.saveConfig(src, newConfig)
    if not SlingEditorService.isAdmin(src) then
        print(string.format('^1[dp_gameplay] Jogador %s tentou salvar sling sem permissao!^7', tostring(src)))
        return false
    end

    if not newConfig or type(newConfig) ~= 'table' or not newConfig.offset or type(newConfig.offset) ~= 'table' then
        return false
    end

    local bone = tonumber(newConfig.bone)
    if not bone or (bone ~= 24818 and bone ~= 24816) then bone = 24818 end
    local off = newConfig.offset
    currentConfig = {
        bone = bone,
        offset = {
            x = tonumber(string.format('%.4f', sanitizeCoord(off.x, -2.0, 2.0, -0.02))),
            y = tonumber(string.format('%.4f', sanitizeCoord(off.y, -2.0, 2.0, 0.22))),
            z = tonumber(string.format('%.4f', sanitizeCoord(off.z, -2.0, 2.0, -0.06))),
            x_rot = tonumber(string.format('%.2f', sanitizeCoord(off.x_rot, -360.0, 360.0, 0.0))),
            y_rot = tonumber(string.format('%.2f', sanitizeCoord(off.y_rot, -360.0, 360.0, -30.0))),
            z_rot = tonumber(string.format('%.2f', sanitizeCoord(off.z_rot, -360.0, 360.0, 180.0))),
        }
    }

    GlobalState.slingConfig = currentConfig
    local encoded = json.encode(currentConfig, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), CONFIG_FILE, encoded, -1)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Coldre Atualizado',
        description = 'Posicionamento do coldre salvo e replicado para todos!',
        type = 'success'
    })
    return true
end

function SlingEditorService.init()
    SlingEditorService.loadConfig()

    RegisterCommand('slingedit', function(source, args, rawCommand)
        local src = source
        if src == 0 then
            print('^3[dp_gameplay] /slingedit deve ser executado in-game por um admin.^7')
            return
        end

        if not SlingEditorService.isAdmin(src) then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Acesso Negado',
                description = 'Você não possui permissão para usar o editor de coldre.',
                type = 'error'
            })
            return
        end

        TriggerClientEvent('dp_gameplay:client:openSlingEditor', src, currentConfig)
    end, false)

    RegisterNetEvent('dp_gameplay:server:saveSlingConfig', function(newConfig)
        local src = source
        if not SlingEditorService.isAdmin(src) then
            print(string.format('^1[dp_gameplay] Jogador %s tentou disparar saveSlingConfig sem permissao!^7', tostring(src)))
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Acesso Negado',
                description = 'Ação não autorizada.',
                type = 'error'
            })
            return
        end
        SlingEditorService.saveConfig(src, newConfig)
    end)
end

_G.SlingEditorService = SlingEditorService
return SlingEditorService
