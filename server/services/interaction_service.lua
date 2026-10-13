local InteractionService = {}

local function validateDistance(src, targetId, maxDist)
    local pedA = GetPlayerPed(src)
    local pedB = GetPlayerPed(targetId)
    if pedA == 0 or pedB == 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= maxDist
end

function InteractionService.init()
    -- 1. Investida / Tackle (com validação anti-exploit de alcance)
    local function handleTackle(targetServerId, forwardCoords)
        local src = source
        targetServerId = tonumber(targetServerId)
        if not targetServerId or targetServerId <= 0 or targetServerId == src then return end

        local maxDist = (ConfigInteractions and ConfigInteractions.tackle and ConfigInteractions.tackle.maxDistance) or 2.5
        if not validateDistance(src, targetServerId, maxDist) then return end

        TriggerClientEvent('tackle:Player', targetServerId, forwardCoords, src)
        TriggerClientEvent('dp_gameplay:tackle:client:getTackled', targetServerId, forwardCoords)
    end

    RegisterNetEvent('tackle:Update', handleTackle)
    RegisterNetEvent('dp_gameplay:tackle:server:attempt', handleTackle)

    -- 2. Arrastar Corpo / Body Drag
    local dragDist = (ConfigInteractions and ConfigInteractions.bodydrag and ConfigInteractions.bodydrag.maxDistance) or 3.0
    RegisterNetEvent('icemallow-drag-server:attach', function(targetPlayer)
        local src = source
        local target = tonumber(targetPlayer)
        if target and target > 0 and target ~= src and validateDistance(src, target, dragDist) then
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
        if target and target > 0 and target ~= src and validateDistance(src, target, dragDist) then
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

    -- 3. Conduzir Policial (Zero GetPlayers loop; rejeição instantânea sem target)
    local conduzirDist = (ConfigInteractions and ConfigInteractions.conduzir and ConfigInteractions.conduzir.maxDistance) or 3.0
    RegisterNetEvent('player:carryPlayer', function(targetId)
        local src = source
        targetId = tonumber(targetId)
        if not targetId or targetId <= 0 or targetId == src then return end

        if validateDistance(src, targetId, conduzirDist) then
            TriggerClientEvent('dp_gameplay:conduzir:client:startCarry', src, targetId)
            TriggerClientEvent('dp_gameplay:conduzir:client:beEscorted', targetId, src)
        end
    end)

    RegisterNetEvent('dp_gameplay:conduzir:server:request', function(targetId)
        local src = source
        targetId = tonumber(targetId)
        if targetId and targetId > 0 and targetId ~= src and validateDistance(src, targetId, conduzirDist) then
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

    -- 4. Rendição / Surrender (Callback único sem duplicar diálogo na vítima)
    local surrenderDist = (ConfigInteractions and ConfigInteractions.surrender and ConfigInteractions.surrender.maxDistance) or 12.0
    local function handleSurrender(targetId)
        local src = source
        targetId = tonumber(targetId)
        if not targetId or targetId <= 0 or targetId == src then return end
        if not validateDistance(src, targetId, surrenderDist) then return end

        CreateThread(function()
            local ok, accepted = pcall(function()
                return lib.callback.await('surrender:confirmSurrender', targetId)
            end)

            if ok and accepted then
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
