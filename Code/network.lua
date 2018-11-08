local module = {}

wifi_status_codes = {
    [0] = "Idle",
    [1] = "Connecting",
    [2] = "Wrong Password",
    [3] = "No AP Found",
    [4] = "Connection Failed",
    [5] = "Got IP"
}

-- wait for an IP (10 sec max)
local function waitForIp(connectedCallback)
    local ipTimer = tmr.create()
    ipTimer:register(
        1000,
        tmr.ALARM_AUTO,
        function()
            if wifi.sta.getip() == nil then
                if wifi_status_codes[wifi.sta.status()] ~= nil then
                    print("Waiting for IP address! (Status: " .. wifi_status_codes[wifi.sta.status()] .. ")")
                else
                    print("Waiting for IP address!")
                end
            else
                print("New IP address is " .. wifi.sta.getip())
                tmr.unregister(ipTimer)
                connectedCallback()
            end
        end
    )
    tmr.start(ipTimer)
end

function module.start(connectedCallback)
    print("Configuring Wifi...")

    ssid, password, bssid_set, bssid = wifi.sta.getconfig()
    print("Configured SSID: " .. ssid)
    -- clear variables after usage for security
    ssid, password, bssid_set, bssid = nil, nil, nil, nil
    mode = wifi.getmode()
    if mode ~= wifi.STATION then
        -- only set the mode if necessary to avoid writing to the flash memory
        print("setting wifi mode to STATION")
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
    -- connect
    wifi.sta.connect()

    -- wait for an IP
    print("Waiting for wifi...")
    waitForIp(connectedCallback)
end

return module
