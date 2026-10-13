ConfigDesviver = {
    Dict = 'mp_suicide',
    Anim = 'pistol',
    AnimTimeBeforeShot = 500, -- Tempo em ms até a arma encostar na têmpora
    RequireAmmo = true,       -- Exige munição para permitir o comando
    ConsumeAmmo = true,       -- Remove 1 munição ao disparar
    SyncDistance = 150.0,     -- Distância máxima em metros para efeitos

    AllowedWeapons = {
        [joaat('WEAPON_PISTOL')] = true,
        [joaat('WEAPON_PISTOL_MK2')] = true,
        [joaat('WEAPON_COMBATPISTOL')] = true,
        [joaat('WEAPON_APPISTOL')] = true,
        [joaat('WEAPON_PISTOL50')] = true,
        [joaat('WEAPON_SNSPISTOL')] = true,
        [joaat('WEAPON_SNSPISTOL_MK2')] = true,
        [joaat('WEAPON_HEAVYPISTOL')] = true,
        [joaat('WEAPON_VINTAGEPISTOL')] = true,
        [joaat('WEAPON_MARKSMANPISTOL')] = true,
        [joaat('WEAPON_REVOLVER')] = true,
        [joaat('WEAPON_REVOLVER_MK2')] = true,
        [joaat('WEAPON_DOUBLEACTION')] = true,
        [joaat('WEAPON_CERAMICPISTOL')] = true,
        [joaat('WEAPON_NAVYREVOLVER')] = true,
        [joaat('WEAPON_GADGETPISTOL')] = true,
        [joaat('WEAPON_STUNGUN')] = false
    }
}
