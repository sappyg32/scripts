fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'you'
description 'Luxor pilot job with NPC passengers'
version '1.0.3'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_inventory'
}
