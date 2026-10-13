-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | CLIENT COMPOSITION ROOT
-- Inicialização modular e injeção de dependências
-----------------------------------------------------------------------------------------------------------------------------------------

CreateThread(function()
    -- Inicializa adapters e módulos de domínio
    QadminClientAdapter.init()
    ArmaFrenteModule.init()
    SlingEditorModule.init()
    FerimentoPernaModule.init()
    DesviverModule.init()
    BodydragModule.init()
    ConduzirModule.init()
    SurrenderModule.init()
    BindsModule.init()
    TackleModule.init()
    AntclModule.init()

    -- Registra keybinds centrais
    KeybindsCore.init()

    print('^2[dp_gameplay] Client inicializado com sucesso (SOLID & Clean Architecture Tree - 0.00ms idle).^7')
end)

RegisterCommand('slingdebug', function()
    local ped = PlayerPedId()
    local myId = cache.serverId or GetPlayerServerId(PlayerId())
    local pState = Player(myId).state
    local currentSel = GetSelectedPedWeapon(ped)
    local _, currentWep = GetCurrentPedWeapon(ped, true)
    print('^3=================== [SLING DIAGNOSTIC REPORT] ===================^7')
    print('Server ID: ' .. tostring(myId))
    print('Ped Entity: ' .. tostring(ped))
    print('SelectedPedWeapon: ' .. tostring(currentSel))
    print('CurrentPedWeapon: ' .. tostring(currentWep))
    print('GlobalState.slingsEnabled: ' .. tostring(GlobalState.slingsEnabled))
    print('StateBag slingWeapons: ' .. json.encode(pState and pState.slingWeapons))
    TriggerServerEvent('showeapons:checkWeapons')
    if ArmaFrenteModule and ArmaFrenteModule.refreshAll then
        ArmaFrenteModule.refreshAll()
    end
    print('^3=================================================================^7')
end, false)

