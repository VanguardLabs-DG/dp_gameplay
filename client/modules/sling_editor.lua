local SlingEditorModule = {}

local isOpen = false
local previewEntity = nil
local editBone = 24818
local editOffset = { x = 0.0, y = 0.0, z = 0.0, x_rot = 0.0, y_rot = 0.0, z_rot = 0.0 }
local mode = 'pos'
local activeCallback = nil
local BLOCKED_KEYS = { 30, 31, 21, 22, 24, 25, 37, 44, 38, 20, 26, 29, 140, 141, 142, 177, 191, 201, 202, 108, 109, 110, 111, 117, 118 }

function SlingEditorModule.isActive() return isOpen end

local function updateUI()
    local bLabel = (editBone == 24818) and '24818 (Peito)' or ((editBone == 24816) and '24816 (Costas)' or tostring(editBone))
    local mLabel = (mode == 'pos') and '[POSICAO]' or '[ROTACAO]'
    local o = editOffset
    local text = string.format("**[CALIBRADOR 3D - SLING]**\nBone: **%s** | Modo: **%s** `[TAB]`\nPos: `%.3f, %.3f, %.3f` | Rot: `%.1f°, %.1f°, %.1f°`\n`[Setas / Q / E]` : Mover Eixos\n`[Mouse]` : Girar Camera 360° | `[Scroll]` : Zoom\n`[Z / C / B]` : Giro Z / Bone\n`[SHIFT]` : 4x Vel | `[ENTER]` : Confirmar | `[ESC]` : Cancelar",
        bLabel, mLabel, o.x, o.y, o.z, o.x_rot, o.y_rot, o.z_rot)
    lib.showTextUI(text, { position = 'top-right' })
end

local function applyPreviewAttachment()
    if not previewEntity or not DoesEntityExist(previewEntity) then return end
    local ped = cache.ped or PlayerPedId()
    local boneIdx = GetPedBoneIndex(ped, editBone)
    local o = editOffset
    AttachEntityToEntity(previewEntity, ped, boneIdx, o.x, o.y, o.z, o.x_rot, o.y_rot, o.z_rot, 1, 1, 0, 0, 2, 1)
end

local function spawnPreviewObject(cfg)
    local item = type(cfg) == 'table' and cfg or { prop = cfg, name = cfg, category = 'weapon' }
    item.name = item.name or item.item_name or item.prop_model or item.prop
    item.prop = item.prop or item.prop_model or item.item_name or item.name
    item.category = item.category or 'weapon'
    print(string.format('^5[SlingEditor DEBUG] spawnPreviewObject chamado para item: %s | prop: %s | cat: %s^7', tostring(item.name), tostring(item.prop), tostring(item.category)))
    local ent, _ = WeaponAdapter.spawnSlingEntity(item)
    print(string.format('^5[SlingEditor DEBUG] spawnPreviewObject resultado: ent=%s, exists=%s^7', tostring(ent), tostring(ent and DoesEntityExist(ent))))
    if ent and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        SetEntityCollision(ent, false, false)
    end
    return ent
end


function SlingEditorModule.close(saveChanges)
    if not isOpen then return end
    isOpen = false
    lib.hideTextUI()
    if SlingCamera and SlingCamera.stop then SlingCamera.stop() end

    if previewEntity and DoesEntityExist(previewEntity) then
        WeaponAdapter.deleteEntity(previewEntity)
        previewEntity = nil
    end

    local cb = activeCallback
    activeCallback = nil

    if cb then
        cb(saveChanges, { bone = editBone, offset = editOffset })
    elseif saveChanges then
        TriggerServerEvent('dp_gameplay:server:saveSlingConfig', { bone = editBone, offset = editOffset })
    else
        lib.notify({ title = 'Sling Editor', description = 'Edicao cancelada.', type = 'inform' })
    end
    if ArmaFrenteModule and ArmaFrenteModule.refreshAll then ArmaFrenteModule.refreshAll() end
end

local function runLoop()
    CreateThread(function()
        local lastTick = GetGameTimer()
        while isOpen do
            Wait(0)
            local ped = cache.ped or PlayerPedId()
            if not DoesEntityExist(ped) or IsEntityDead(ped) then SlingEditorModule.close(false); break end
            for i = 1, #BLOCKED_KEYS do DisableControlAction(0, BLOCKED_KEYS[i], true) end

            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then SlingEditorModule.close(true); break end
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 202) then SlingEditorModule.close(false); break end

            local now = GetGameTimer()
            local fast = IsDisabledControlPressed(0, 21)
            local changed = false

            if IsDisabledControlJustPressed(0, 29) then editBone = (editBone == 24818) and 24816 or 24818; changed = true end
            if IsDisabledControlJustPressed(0, 37) then mode = (mode == 'pos') and 'rot' or 'pos'; changed = true end

            if (now - lastTick) >= (fast and 18 or 30) then
                local step = (mode == 'pos') and (fast and 0.02 or 0.005) or (fast and 5.0 or 1.0)
                local function check(n, p, pk, rk)
                    local k = (mode == 'pos') and pk or rk
                    if IsDisabledControlPressed(0, n) then editOffset[k] = editOffset[k] - step; changed = true
                    elseif IsDisabledControlPressed(0, p) then editOffset[k] = editOffset[k] + step; changed = true end
                end
                check(174, 175, 'x', 'x_rot')
                check(172, 173, 'y', 'y_rot')
                check(44, 38, 'z', 'z_rot')
                if IsDisabledControlPressed(0, 20) or IsDisabledControlPressed(0, 108) then editOffset.z_rot = editOffset.z_rot - step; changed = true
                elseif IsDisabledControlPressed(0, 26) or IsDisabledControlPressed(0, 109) then editOffset.z_rot = editOffset.z_rot + step; changed = true end

                if changed then lastTick = now; applyPreviewAttachment(); updateUI() end
            end
        end
    end)
end

function SlingEditorModule.open(cfg, cb)
    if isOpen then return end
    if previewEntity and DoesEntityExist(previewEntity) then WeaponAdapter.deleteEntity(previewEntity); previewEntity = nil end
    isOpen = true
    activeCallback = cb

    editBone = tonumber(cfg and cfg.bone) or 24818
    local off = (cfg and (cfg.offset or cfg)) or {}
    editOffset = {
        x = tonumber(off.x) or -0.005, y = tonumber(off.y) or 0.185, z = tonumber(off.z) or 0.055,
        x_rot = tonumber(off.x_rot) or 1.5, y_rot = tonumber(off.y_rot) or 134.5, z_rot = tonumber(off.z_rot) or -4.5
    }
    mode = 'pos'

    previewEntity = spawnPreviewObject(cfg)
    if not previewEntity or not DoesEntityExist(previewEntity) then
        isOpen = false
        lib.notify({ title = 'Erro', description = 'Nao foi possivel instanciar o prop.', type = 'error' })
        if cb then cb(false, nil) end
        return
    end

    if SlingCamera and SlingCamera.start then SlingCamera.start() end
    applyPreviewAttachment()
    updateUI()
    runLoop()
end

function SlingEditorModule.init()
    RegisterNetEvent('dp_gameplay:client:openSlingEditor', function(cfg) SlingEditorModule.open(cfg) end)
    RegisterNetEvent('qbx_core:client:playerLoggedOut', function() if isOpen then SlingEditorModule.close(false) end end)
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() and isOpen then SlingEditorModule.close(false) end
    end)
end

_G.SlingEditorModule = SlingEditorModule
return SlingEditorModule
