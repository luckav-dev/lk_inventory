fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lk_inv'
author 'LK'
version '0.1.0'
description 'LK Inventory — original advanced inventory with real ground objects'

-- Acts as ox_inventory for the rest of the server: GetResourceState('ox_inventory')
-- returns started and any resource that `dependency 'ox_inventory'` is satisfied,
-- so existing scripts work with no edits. Don't run a real ox_inventory alongside.
provide 'ox_inventory'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

client_script 'init.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua',
}

ui_page 'web/build/index.html'

files {
    'config/*.lua',
    'shared/*.lua',
    'locales/*.lua',
    'client/*.lua',
    'web/build/index.html',
    'web/build/**/*',
    'web/images/*.png',
}
