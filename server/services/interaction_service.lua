local InteractionService = {}

local function validateDistance(src, targetId, maxDist)
    local pedA = GetPlayerPed(src)
    local pedB = GetPlayerPed(targetId)
    if pedA == 0 or pedB == 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= maxDist
end

function InteractionService.init()
    -- 1. Investida / Tackle
    local function handleTackle(targetServerId, forwardCoords)
        local src = source
        targetServerId = tonumber(targetServerId)
        if targetServerId and targetServerId > 0 and targetServerId ~= src then
            local targetPed = GetPlayerPed(targetServerId)
            if targetPed and targetPed ~= 0 then
                TriggerClientEvent('tackle:Player', targetServerId, forwardCoords, src)
                TriggerClientEvent('dp_gameplay:tackle:client:getTackled', targetServerId, forwardCoords)
            end
        end
    end

    RegisterNetEvent('tackle:Update', handleTackle)
    RegisterNetEvent('dp_gameplay:tackle:server:attempt', handleTackle)

    -- 2. Arrastar Corpo / Body Drag (Compatibilidade Icemallow + DP)
    RegisterNetEvent('icemallow-drag-server:attach', function(targetPlayer)
        local src = source
        local target = tonumber(targetPlayer)
        if target and target > 0 and target ~= src and validateDistance(src, target, 5.0) then
            TriggerClientEvent('icemallow-drag:attach', target, src)
            TriggerClientEvent('dp_gameplay:bodydrag:client:dragSuccess', src, target)
            TriggerClientEvent('dp_gameplay:bodydrag:client:beAttached', target, src)
        end
    end)

    RegisterNetEvent('icemallow-drag-server:deattach', function(targetPlayer)
        local src = source
        local target = tonumber(targetPlayer)
        if target and target > 0 then
            TriggerClientEvent('icemallow-drag:deattach', target, src)
            TriggerClientEvent('dp_gameplay:bodydrag:client:beDetached', target)
        end
    end)

    RegisterNetEvent('dp_gameplay:bodydrag:server:request', function(targetId)
        local src = source
        local target = tonumber(targetId)
        if target and target > 0 and target ~= src and validateDistance(src, target, 5.0) then
            TriggerClientEvent('dp_gameplay:bodydrag:client:dragSuccess', src, target)
            TriggerClientEvent('dp_gameplay:bodydrag:client:beAttached', target, src)
        end
    end)

    RegisterNetEvent('dp_gameplay:bodydrag:server:stop', function(targetId)
        local target = tonumber(targetId)
        if target and target > 0 then
            TriggerClientEvent('dp_gameplay:bodydrag:client:beDetached', target)
        end
    end)

    -- 3. Conduzir Policial
    RegisterNetEvent('player:carryPlayer', function(targetId)
        local src = source
        targetId = tonumber(targetId)
        if not targetId or targetId <= 0 then
            -- Busca jogador mais próximo
            local ped = GetPlayerPed(src)
            local coords = GetEntityCoords(ped)
            local closest = nil
            local closestDist = ConfigInteractions.conduzir.maxDistance or 2.5
            for _, p in ipairs(GetPlayers()) do
                local pSrc = tonumber(p)
                if pSrc and pSrc ~= src then
                    local pPed = GetPlayerPed(pSrc)
                    if pPed and pPed ~= 0 then
                        local d = #(coords - GetEntityCoords(pPed))
                        if d <= closestDist then
                            closestDist = d
                            closest = pSrc
                        end
                    end
                end
            end
            targetId = closest
        end

        if targetId and targetId > 0 and targetId ~= src and validateDistance(src, targetId, 4.0) then
            TriggerClientEvent('dp_gameplay:conduzir:client:startCarry', src, targetId)
            TriggerClientEvent('dp_gameplay:conduzir:client:beEscorted', targetId, src)
        end
    end)

    RegisterNetEvent('dp_gameplay:conduzir:server:stop', function(targetId)
        local target = tonumber(targetId)
        if target and target > 0 then
            TriggerClientEvent('dp_gameplay:conduzir:client:beReleased', target)
        end
    end)

    -- 4. Rendição / Surrender
    local function handleSurrender(targetId)
        local src = source
        targetId = tonumber(targetId)
        if not targetId or targetId <= 0 or targetId == src then return end
        if not validateDistance(src, targetId, 12.0) then return end

        CreateThread(function()
            local accepted = false
            pcall(function()
                accepted = lib.callback.await('surrender:confirmSurrender', targetId)
            end)
            if not accepted then
                pcall(function()
                    accepted = lib.callback.await('dp_gameplay:surrender:client:confirm', targetId)
                end)
            end

            if accepted then
                TriggerClientEvent('surrender:doSurrender', targetId)
                TriggerClientEvent('dp_gameplay:surrender:client:doSurrender', targetId)
            end
        end)
    end

    RegisterNetEvent('surrender:request', handleSurrender)
    RegisterNetEvent('dp_gameplay:surrender:server:request', handleSurrender)
end

_G.InteractionService = InteractionService
return InteractionService
