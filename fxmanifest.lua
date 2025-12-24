fx_version 'cerulean'
lua54 'yes'

name 'aprts_tablet_darknet'
description 'Modular Darknet Market'
author 'AI'
version '2.5.0'
games {"gta5"}

shared_scripts { '@ox_lib/init.lua', 'config.lua' }

-- Načteme hlavní klient a server
client_script 'client.lua'
server_script 'server.lua'

-- Načteme všechny mise (globálně)
client_scripts {
    'missions/delivery/client.lua',
    'missions/heist/client.lua',
    'missions/drug_sale/client.lua' -- NOVÉ
}

files {
    'install.sql',
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

dependencies { 'aprts_tablet', 'oxmysql' }