fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'OpenAI'
description 'Secure FiveM Admin Menu with bans, spectate, freeze, fire, kill, and player reports'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'qb-weathersync'

server_script '@oxmysql/lib/MySQL.lua'
