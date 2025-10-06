fx_version 'cerulean'
game 'gta5'

author 'Votre Nom'
description 'Core RP 100% Custom - Chat, Inventaire, Santé'
version '2.0.0'

lua54 'yes'

-- Scripts partagés (client + server)
shared_scripts {
    'config.lua',
    'shared/*.lua'
}

-- Scripts serveur (ORDRE IMPORTANT!)
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/notifications.lua',
    'server/main.lua',
    -- Modules
    'server/modules/chat.lua',
    'server/modules/inventory.lua',
	'server/modules/money.lua',
    'server/modules/health.lua'
}

-- Scripts client
client_scripts {
    'client/main.lua',
    'client/notifications.lua',
    -- Modules
    'client/modules/chat.lua',
    'client/modules/inventory.lua',
	'client/modules/money.lua',
    'client/modules/health.lua'
	
}

-- Interface utilisateur (NUI)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/**/*',
    -- Nouvelles pages
    'html/chat.html',
    'html/inventory.html',
    'html/health.html'
}

-- Dépendances
dependencies {
    'oxmysql'
}