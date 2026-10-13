local AntclModule = {}

local showMarkers = true
local activePoints = {}

local function drawText3D(x, y, z, text, color)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(color.r, color.g, color.b, 230)
        SetTextDropshadow(0, 0, 0, 0, 150)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function AntclModule.init()
    RegisterCommand('antcl', function()
        showMarkers = not showMarkers
        NotificationAdapter.notify(
            'Combat-Log',
            showMarkers and 'Visualização de marcadores ATIVADA.' or 'Visualização DESATIVADA.',
            showMarkers and 'success' or 'warning'
        )
    end, false)

    RegisterNetEvent('dp_gameplay:antcl:client:createMarker', function(data)
        if not data or not data.coords then return end

        local title = '[COMBAT-LOG DETECTADO]'
        local reasonText = tostring(data.reason or 'Desconectou')
        if reasonText:find('memcpy') or reasonText:find('VCRUNTIME') then
            reasonText = 'Forçou Crash (Alt+F4 / Crash)'
        end

        local infoText = ('Passaporte: %s | ID: %s\nNome: %s\nMotivo: %s'):format(
            tostring(data.citizenid or 'N/A'),
            tostring(data.tempId or 'N/A'),
            tostring(data.charName or 'Desconhecido'),
            reasonText
        )

        -- Registra ponto geográfico nativo do ox_lib (0.00ms resmon em repouso!)
        local point = lib.points.new({
            coords = vec3(data.coords.x, data.coords.y, data.coords.z),
            distance = ConfigAntcl.maxDistance or 35.0,
            nearby = function(self)
                if showMarkers then
                    drawText3D(self.coords.x, self.coords.y, self.coords.z + 0.20, title, ConfigAntcl.alertTextColor)
                    drawText3D(self.coords.x, self.coords.y, self.coords.z, infoText, ConfigAntcl.textColor)
                end
            end
        })

        activePoints[#activePoints + 1] = point

        SetTimeout(ConfigAntcl.drawingTime or 30000, function()
            if point then
                point:remove()
            end
        end)
    end)
end

_G.AntclModule = AntclModule
return AntclModule
