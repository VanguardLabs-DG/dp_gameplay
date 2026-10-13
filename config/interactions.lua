ConfigInteractions = {
    pushVehicle = {
        maxDistance = 3.5,
        pushSpeed = 1.5,
        animDict = 'missfinale_c2ig_11',
        animClip = 'pushcar_offcliff_m',
        blacklistedClasses = { 13, 14, 15, 16 } -- Cycles, Boats, Heli, Planes
    },

    tackle = {
        maxDistance = 1.8,
        cooldownMs = 2500,
        ragdollDurationVictim = 4000,
        ragdollDurationAttacker = 1500
    },

    bodydrag = {
        maxDistance = 2.5,
        animDict = 'combat@drag_ped@',
        carrierAnim = 'injured_drag_plyr',
        targetAnim = 'injured_drag_target',
        pickupDuration = 2000
    },

    conduzir = {
        maxDistance = 2.5,
        carrierAnimDict = 'amb@world_human_drinking@coffee@female@base',
        carrierAnim = 'base',
        targetAnimDict = 'anim@move_m@prisoner_cuffed',
        targetIdleAnim = 'idle',
        targetWalkAnim = 'walk'
    },

    surrender = {
        maxDistance = 12.0,
        handsUpDuration = 3500,
        kneelDuration = 27000
    }
}
