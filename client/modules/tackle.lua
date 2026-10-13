local TackleModule = {}

local function getTouchedPlayers(ped)
    local players = {}
    for _, v in ipairs(GetActivePlayers()) do
        local uPed = GetPlayerPed(v)
        if uPed ~= ped and DoesEntityExist(uPed) and IsEntityTouchingEntity(ped, uPed) and not IsPedInAnyVehicle(uPed, false) then
            players[#players + 1] = v
        end
    end
    return players
end

function TackleModule.performTackle()
    local ped = PedAdapter.getPed()
    local isCuffed = LocalPlayer.state.Handcuff or LocalPlayer.state.isCuffed or LocalPlayer.state.ishandcuffed

    if not isCuffed and not IsPedInAnyVehicle(ped, false) and IsPedJumping(ped) then
        local tackled = {}
        local fwd = GetEntityForwardVector(ped)

        SetPedToRagdollWithFall(ped, 2500, 1500, 0, fwd.x, fwd.y, fwd.z, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

        CreateThread(function()
            while IsPedRagdoll(ped) do
                for _, v in ipairs(getTouchedPlayers(ped)) do
                    if not tackled[v] then
                        tackled[v] = true
                        pcall(function() exports.ox_inventory:closeInventory() end)

                        local targetServerId = GetPlayerServerId(v)
                        if targetServerId and targetServerId > 0 then
                            TriggerServerEvent('tackle:Update', targetServerId, { fwd.x, fwd.y, fwd.z })
                        end
                    end
                end
                Wait(10)
            end
        end)
    end
end

function TackleModule.init()
    RegisterCommand('+tackle', function()
        TackleModule.performTackle()
    end, false)

    RegisterCommand('-tackle', function() end, false)

    RegisterKeyMapping('+tackle', 'Investida / Derrubar Jogador (Ao Pular)', 'keyboard', 'e')

    -- Vítima derrubada pela investida (compatível com os dois nomes de evento)
    local function onTackled(coords)
        local ped = PedAdapter.getPed()
        if coords and type(coords) == 'table' then
            SetPedToRagdollWithFall(ped, 4000, 4000, 0, coords[1] or 0.0, coords[2] or 0.0, coords[3] or 0.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        else
            PedAdapter.setRagdoll(ped, 4000, 4000, 0)
        end
        pcall(function() exports.ox_inventory:closeInventory() end)
    end

    RegisterNetEvent('tackle:Player', onTackled)
    RegisterNetEvent('dp_gameplay:tackle:client:getTackled', onTackled)
end

_G.TackleModule = TackleModule
return TackleModule
