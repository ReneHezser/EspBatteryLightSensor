local module = {}

wifi_status_codes = {
    [0] = 'Idle',
    [1] = 'Connecting',
    [2] = 'Wrong Password',
    [3] = 'No AP Found',
    [4] = 'Connection Failed',
    [5] = 'Got IP'
}

-- wait for an IP (10 sec max)
local function waitForIp(connectedCallback)
    local ipTimer = tmr.create()
    ipTimer:register(
        100,
        tmr.ALARM_AUTO,
        function()
            if wifi.sta.getip() == nil then
                if wifi_status_codes[wifi.sta.status()] ~= nil then
                    print('Network: Waiting for IP address (Status: ' .. wifi_status_codes[wifi.sta.status()] .. ')')
                else
                    print('Network: Waiting for IP address...')
                end
            else
                print('Network: New IP address is ' .. wifi.sta.getip())
                ipTimer:unregister()
                connectedCallback()
            end
        end
    )
    ipTimer:start()
end

function module.start(connectedCallback)
    print('Network: Configuring Wifi...')

    ssid, password, bssid_set, bssid = wifi.sta.getconfig()
    print('Network: Configured SSID: ' .. ssid)
    -- clear variables after usage for security
    ssid, password, bssid_set, bssid = nil, nil, nil, nil
    mode = wifi.getmode()
    if mode ~= wifi.STATION then
        -- only set the mode if necessary to avoid writing to the flash memory
        print('Network: Setting wifi mode to STATION')
        wifi.setmode(wifi.STATION)
    end
    -- configure wifi
    station_cfg = {}
    station_cfg.ssid = config.wifi.ssid
    station_cfg.pwd = config.wifi.password
    -- use this config
    station_cfg.save = false
    -- connect manually later
    station_cfg.auto = false
    wifi.sta.config(station_cfg)
    wifi.setphymode(config.wifi.phymode)
    -- connect
    wifi.sta.connect()

    if config.wifi.ip ~= '' then
        wifi.sta.setip(
            {
                ip = config.wifi.ip,
                netmask = config.wifi.netmask,
                gateway = config.wifi.gateway
            }
        )
        -- wait for connection
        print('Network: Waiting for network connection...')
        wifi.eventmon.register(
            wifi.eventmon.STA_CONNECTED,
            function(T)
                print('\n\tSTA - CONNECTED' .. '\n\tSSID: ' .. T.SSID .. '\n\tBSSID: ' .. T.BSSID .. '\n\tChannel: ' .. T.channel .. '\n')
                connectedCallback()
            end
        )
    else
        -- wait for an IP
        print('Network: Waiting for wifi...')
        waitForIp(connectedCallback)
    end
end

return module
