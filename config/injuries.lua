ConfigInjuries = {
    legInjuryChance = 50, -- 50% chance ao levar tiro na perna
    animSet = 'move_m@injured',
    minRunTimeToStumble = 1200,
    maxRunTimeToStumble = 2200,
    stumbleCooldown = 3500,
    ragdollDuration = 2500,

    legBones = {
        -- Perna Esquerda
        [58271] = true, -- SKEL_L_Thigh (Coxa)
        [11816] = true, -- SKEL_L_Thigh (Coxa - ID alternativo)
        [63931] = true, -- SKEL_L_Calf (Canela)
        [14201] = true, -- SKEL_L_Foot (Pé)
        [2108]  = true, -- SKEL_L_Toe0 (Dedos)
        [46078] = true, -- MH_L_Knee (Joelho)
        [57717] = true, -- SKEL_L_Ankle (Tornozelo)

        -- Perna Direita
        [51826] = true, -- SKEL_R_Thigh (Coxa)
        [41544] = true, -- SKEL_R_Thigh (Coxa - ID alternativo)
        [36864] = true, -- SKEL_R_Calf (Canela)
        [52301] = true, -- SKEL_R_Foot (Pé)
        [20781] = true, -- SKEL_R_Toe0 (Dedos)
        [16335] = true, -- MH_R_Knee (Joelho)
        [24806] = true  -- SKEL_R_Ankle (Tornozelo)
    }
}
