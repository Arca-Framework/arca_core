fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'arca_core'
author 'Arca'
description 'Arca framework core'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
    'shared/main.lua',
    'shared/jobs.lua',
    'shared/gangs.lua',
    'bridge/qb/shared.lua',
}

client_scripts {
    'modules/callback/client.lua',
    'modules/notify/client.lua',
    'modules/nui/client.lua',
    'modules/progress/client.lua',
    'modules/textui/client.lua',
    'modules/context/client.lua',
    'modules/radial/client.lua',
    'client/main.lua',
    'client/events.lua',
    'bridge/qb/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'modules/callback/server.lua',
    'modules/notify/server.lua',
    'server/main.lua',
    'server/player.lua',
    'server/events.lua',
    'server/commands.lua',
    'bridge/qb/server.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'shared/import.lua',
}

-- answer as qb-core so qb resources (exports['qb-core'], dependency 'qb-core') resolve to Arca
provide 'qb-core'

dependencies {
    'oxmysql',
}
