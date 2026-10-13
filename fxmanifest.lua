fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dp_gameplay'
author 'Distrito Paulista'
description 'Core Gameplay & Interaction Systems - SOLID & Clean Architecture Tree'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@vanguard_lib/init.lua',
    'config/*.lua',
}

client_scripts {
    'client/adapters/*.lua',
    'client/modules/*.lua',
    'client/core/*.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/adapters/*.lua',
    'server/services/*.lua',
    'server/main.lua',
}

files {
    'admin/index.html',
    'admin/style.css',
    'admin/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
    'vanguard_lib',
}
