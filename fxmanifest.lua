fx_version 'cerulean'
lua54 'yes'

author 'AI'
version '1.0.0'
description 'Darknet Market for aprts_tablet'
games {"gta5"}
shared_scripts {'@ox_lib/init.lua', 'config.lua', 'missions/atm_rob/shared.lua'}

server_scripts {'server.lua', 'missions/atm_rob/server.lua'}
client_scripts {'client.lua', 'missions/atm_rob/client.lua'}

dependencies {'aprts_tablet', 'oxmysql'}

exports {'CompleteJob' -- Export pro dokončení jobu a získání odměny
}
