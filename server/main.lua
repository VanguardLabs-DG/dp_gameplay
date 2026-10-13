-----------------------------------------------------------------------------------------------------------------------------------------
-- DP_GAMEPLAY | SERVER COMPOSITION ROOT
-- Inicialização modular e injeção de dependências do servidor
-----------------------------------------------------------------------------------------------------------------------------------------

CreateThread(function()
    SlingDatabaseService.init()
    QadminServerAdapter.init()
    ArmaFrenteService.init()
    SlingEditorService.init()
    FerimentoService.init()
    DesviverService.init()
    InteractionService.init()
    AntclService.init()

    print('^2[dp_gameplay] Server inicializado com sucesso (SOLID & Clean Architecture Tree).^7')
end)

RegisterCommand('reloadslings', function(source)
    if source == 0 or IsPlayerAceAllowed(tostring(source), 'command') or IsPlayerAceAllowed(tostring(source), 'admin') then
        if SlingDatabaseService and SlingDatabaseService.reload then
            SlingDatabaseService.reload()
            print('^2[dp_gameplay] Catálogo de slings recarregado com sucesso!^7')
        end
    end
end, true)


