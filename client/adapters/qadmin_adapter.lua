local QadminClientAdapter = {}
local isCapturing = false

function QadminClientAdapter.init()
    RegisterNUICallback('getCatalog', function(_, cb)
        local res = lib.callback.await('dp_gameplay:server:getSlingCatalog', false)
        cb(res or { ok = false, message = 'Falha ao consultar catalogo no servidor.' })
    end)

    RegisterNUICallback('saveItem', function(data, cb)
        local res = lib.callback.await('dp_gameplay:server:saveSlingItem', false, data.payload, data.revision)
        cb(res or { ok = false, message = 'Falha ao salvar item no servidor.' })
    end)

    RegisterNUICallback('deleteItem', function(data, cb)
        local res = lib.callback.await('dp_gameplay:server:deleteSlingItem', false, data.itemName)
        cb(res or { ok = false, message = 'Falha ao deletar item no servidor.' })
    end)

    RegisterNUICallback('toggleItem', function(data, cb)
        local res = lib.callback.await('dp_gameplay:server:toggleSlingItem', false, data.itemName, data.enabled)
        cb(res or { ok = false, message = 'Falha ao alterar status do item.' })
    end)

    RegisterNUICallback('toggleGlobal', function(data, cb)
        local res = lib.callback.await('dp_gameplay:server:toggleGlobalSlings', false, data.enabled)
        cb(res or { ok = false, message = 'Falha ao alterar status global.' })
    end)

    RegisterNUICallback('captureInGameCoords', function(data, cb)
        if isCapturing then
            cb({ ok = false, message = 'Ja existe uma sessao de calibracao em andamento.' })
            return
        end
        isCapturing = true

        pcall(function()
            if exports['mri_Qadmin'] then exports['mri_Qadmin']:ClosePlugin('slings') end
        end)
        SetNuiFocus(false, false)

        local itemData = data and data.item or {}
        SlingEditorModule.open(itemData, function(confirmed, result)
            isCapturing = false
            pcall(function()
                if exports['mri_Qadmin'] then
                    exports['mri_Qadmin']:OpenPlugin('slings')
                else
                    SetNuiFocus(true, true)
                end
            end)
            Wait(150)
            if confirmed and result then
                cb({ ok = true, bone = result.bone, offset = result.offset })
            else
                cb({ ok = false, message = 'Ajuste cancelado pelo administrador.' })
            end
        end)
    end)

    RegisterNUICallback('closePanel', function(_, cb)
        pcall(function()
            if exports['mri_Qadmin'] then exports['mri_Qadmin']:ClosePlugin('slings') end
        end)
        SetNuiFocus(false, false)
        cb({ ok = true })
    end)
end

_G.QadminClientAdapter = QadminClientAdapter
return QadminClientAdapter
