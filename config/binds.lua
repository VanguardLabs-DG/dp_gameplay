ConfigBinds = {
    cooldownMs = 600,
    blockInVehicle = true,
    blockIfSwimming = true,
    blockIfCuffed = true,
    blockIfDead = true,
    blockIfArmed = true,
    blockIfAiming = true,

    -- Binds Rápidas estilo Creative (Teclas 6, 7, 8, 9, left, right, up, down)
    list = {
        ['6'] = {
            label = 'Braços Cruzados',
            description = 'Interação do botão 6 (Braços Cruzados)',
            dict = 'anim@heists@heist_corona@single_team',
            anim = 'single_team_loop_boss',
            loop = true,
            upperBody = true,
            flag = 49,
            defaultKey = '6'
        },
        ['7'] = {
            label = 'Postura de Segurança',
            description = 'Interação do botão 7 (Postura Segurança)',
            dict = 'mini@strip_club@idles@bouncer@base',
            anim = 'base',
            loop = true,
            upperBody = true,
            flag = 49,
            defaultKey = '7'
        },
        ['8'] = {
            label = 'Dedo do Meio',
            description = 'Interação do botão 8 (Dedo do Meio)',
            dict = 'anim@mp_player_intupperfinger',
            anim = 'idle_a_fp',
            loop = true,
            upperBody = true,
            flag = 49,
            defaultKey = '8'
        },
        ['9'] = {
            label = 'Mãos na Cabeça',
            description = 'Interação do botão 9 (Mãos na Cabeça)',
            dict = 'random@arrests@busted',
            anim = 'idle_a',
            loop = true,
            upperBody = true,
            flag = 49,
            defaultKey = '9'
        },
        ['left'] = {
            label = 'Joinha',
            description = 'Interação da seta esquerda (Joinha)',
            dict = 'anim@mp_player_intupperthumbs_up',
            anim = 'enter',
            loop = false,
            upperBody = true,
            flag = 48,
            defaultKey = 'LEFT'
        },
        ['right'] = {
            label = 'Desgosto / Facepalm',
            description = 'Interação da seta direita (Facepalm)',
            dict = 'anim@mp_player_intcelebrationmale@face_palm',
            anim = 'face_palm',
            loop = false,
            upperBody = true,
            flag = 48,
            defaultKey = 'RIGHT'
        },
        ['up'] = {
            label = 'Continência',
            description = 'Interação da seta pra cima (Continência)',
            dict = 'anim@mp_player_intcelebrationmale@salute',
            anim = 'salute',
            loop = false,
            upperBody = true,
            flag = 48,
            defaultKey = 'UP'
        },
        ['down'] = {
            label = 'Assobiar',
            description = 'Interação da seta pra baixo (Assobiar)',
            dict = 'rcmnigel1c',
            anim = 'hailing_whistle_waive_a',
            loop = false,
            upperBody = true,
            flag = 48,
            defaultKey = 'DOWN'
        }
    }
}
