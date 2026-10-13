local QadminServerAdapter = {}

local function registerAdminPlugin()
    if GetResourceState('mri_Qadmin') ~= 'started' then return end

    local ok, res = pcall(function()
        return exports['mri_Qadmin']:RegisterPlugin({
            id = 'slings',
            label = 'Slings & Coldres',
            icon = 'shield-halved',
            resource = GetCurrentResourceName(),
            htmlPath = 'admin/index.html',
            requiredPerms = { 'qadmin.slings', 'command' },
            permDefs = {
                { id = 'qadmin.slings', label = 'Gerenciar Slings e Itens no Corpo', category = 'Gameplay' }
            },
            description = 'Gerenciamento de posicionamento de armas e itens visíveis no corpo'
        })
    end)

    if ok and res then
        print('^2[dp_gameplay]^7 Plugin Slings & Coldres registrado no mri_Qadmin com sucesso!')
    end
end

function QadminServerAdapter.init()
    AddEventHandler('mri_Qadmin:server:pluginsReady', registerAdminPlugin)

    AddEventHandler('onServerResourceStart', function(resName)
        if resName == 'mri_Qadmin' then
            registerAdminPlugin()
        end
    end)

    CreateThread(function()
        Wait(800)
        registerAdminPlugin()
    end)
end

_G.QadminServerAdapter = QadminServerAdapter
return QadminServerAdapter
