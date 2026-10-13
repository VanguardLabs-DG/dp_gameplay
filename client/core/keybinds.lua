local KeybindsCore = {}

function KeybindsCore.init()
    -- 1. Empurrar Veículo (Tecla M - segura para empurrar)
    RegisterCommand('+pushveh', function()
        PushVehicleModule.startPush()
    end, false)

    RegisterCommand('-pushveh', function()
        PushVehicleModule.stopPush()
    end, false)

    RegisterKeyMapping('+pushveh', 'Empurrar veículo destrancado', 'keyboard', 'M')

    -- 2. Conduzir / Escoltar Cidadão (Tecla H)
    RegisterCommand('conduzirToggle', function()
        ConduzirModule.toggleEscort()
    end, false)

    RegisterKeyMapping('conduzirToggle', 'Conduzir/Soltar Cidadão', 'keyboard', 'H')

    -- 3. Soltar Corpo Arrastado (Tecla G)
    RegisterCommand('releasedrag', function()
        BodydragModule.stopDragKey()
    end, false)

    RegisterKeyMapping('releasedrag', 'Soltar corpo arrastado', 'keyboard', 'G')

    -- 4. Controle de Cruzeiro (Teclas INSERT, PGUP, PGDN, DELETE)
    RegisterCommand('cruise_toggle', function()
        CruiseModule.toggleCruise()
    end, false)
    RegisterKeyMapping('cruise_toggle', 'Ativar/Desativar Controle de Cruzeiro', 'keyboard', 'INSERT')

    RegisterCommand('cruise_up', function()
        CruiseModule.adjustSpeed(ConfigCruise.speedStepKmh or 5.0)
    end, false)
    RegisterKeyMapping('cruise_up', 'Controle de Cruzeiro: Aumentar Velocidade', 'keyboard', 'PGUP')

    RegisterCommand('cruise_down', function()
        CruiseModule.adjustSpeed(-(ConfigCruise.speedStepKmh or 5.0))
    end, false)
    RegisterKeyMapping('cruise_down', 'Controle de Cruzeiro: Diminuir Velocidade', 'keyboard', 'PGDN')

    RegisterCommand('cruise_autopilot', function()
        CruiseModule.toggleAutopilot()
    end, false)
    RegisterCommand('autopilot', function()
        CruiseModule.toggleAutopilot()
    end, false)
    RegisterCommand('piloto', function()
        CruiseModule.toggleAutopilot()
    end, false)
    RegisterKeyMapping('cruise_autopilot', 'Piloto Automático (Aeronaves)', 'keyboard', 'DELETE')
end

_G.KeybindsCore = KeybindsCore
return KeybindsCore
