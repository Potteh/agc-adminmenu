Config = {}

-- Admins need this ACE permission.
Config.AdminAce = 'fivem.admin'

-- Maximum report length.
Config.MaxReportLength = 500

-- Where bans are stored. FiveM resource data directory.
Config.BanFile = 'bans.json'

-- How long a player remains on fire when using the menu.
Config.FireDurationMs = 5000

Config.EarthquakeDurationMs = 15000
Config.EarthquakeIntensity = 0.18

-- Restart sequence
Config.RestartWarningSeconds = 120
Config.RestartStormWeather = 'THUNDER'
Config.RestartSirenSoundName = 'Air_Defences_Activated'
Config.RestartSirenSoundSet = 'DLC_sum20_Business_Battle_AC_Sounds'
-- FiveM resources cannot directly ask txAdmin to restart FXServer through a public resource API.
-- If true, the sequence ends with the FXServer `quit` command. Use this only when your host/process
-- manager is configured to automatically start FXServer again after a clean exit.
Config.RestartUseQuitCommand = false

Config.AdminWorldSyncIntervalMs = 2000


-- Optional ACG Radio integration. acg_radio is NOT a dependency.
Config.AcgRadio = {
    Enabled = true,
    ResourceName = 'acg_radio'
}
