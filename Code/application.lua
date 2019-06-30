local module = {}

local brightness = {'night', 'dim', 'normal', 'bright', 'veryBright'}
local lastLuxValue
local lastVoltage
local readValueCount

-- read sensor and store value in 'lux' variable
local function readLux(integrationTime)
    lux = tsl2561.getlux()
    ch0, ch1 = tsl2561.getrawchannels()

    -- ensure max value, if the sensor is saturated by very bright light
    if integrationTime == 0 and (ch0 > 4808 or ch1 == 4808) then
        -- saturation reached
        lux = config.lux.max
    elseif integrationTime == 1 and (ch0 > 36938 or ch1 == 36938) then
        -- saturation reached
        lux = config.lux.max
    end

    print('Sensor: Values are lux:' .. lux .. ', raw values (Ch1-Ch2):' .. ch0 .. '-' .. ch1)

    -- power down the sensor
    gpio.write(config.pins.activateTsl, gpio.LOW)
end

-- return 0,1,2,3 reflecting night, dim, normal, bright, very bright
local function getBrightness(value)
    if value < config.lux.night then
        return 0 --night
    elseif value < config.lux.normal then
        return 1 --dim
    elseif value < config.lux.bright then
        return 2 --normal
    elseif value < config.lux.veryBright then
        return 3 --bright
    else
        return 4 --veryBright
    end
end

local function goSleep()
    -- do not sleep if battery is near 0. This way you can disconnect the battery to flash/upload
    if lastVoltage / config.voltage.multiplicator < config.voltage.ignoreAdcValuesBelow then
        print("Application: Done. But don't sleep as the battery is not connected.")
    else
        print('Application: Going to sleep for ' .. config.lux.measureInterval .. ' minutes. Bye.')
        -- go sleep again and hope the voltage will rise again
        local sleepTime = config.lux.measureInterval * 60 * 1000 * 1000
        node.dsleep(sleepTime, 2, 1)
    end
end

-- send values and go to deep sleep for 5 minutes
function send_to_mqtt()
    -- assume only port 1883 is unsecure (meaning no TLS)
    local secure = 0
    if config.mqtt.port ~= 1883 then
        secure = 1
    end

    print('MQTT: Connecting to ' .. config.mqtt.url .. ' on port ' .. config.mqtt.port .. ' with secure=' .. secure)
    success =
        m:connect(
        config.mqtt.url,
        config.mqtt.port,
        secure,
        --0, -- autoreconnect is deprecated
        function(client)
            local data = '{"lux":"' .. lux .. '","voltage":"' .. lastVoltage .. '","readCount":"' .. readValueCount .. '"}'
            print('MQTT: Client connected. Now sending data: ' .. data)
            client:publish(
                config.mqtt.topics.name,
                data,
                0, -- QoS level
                0, -- retain
                function(client)
                    print('MQTT: Data sent to mqtt topic. Closing connection.')
                    m:close()

                    goSleep()
                    -- hint: after waking up the device will boot and not continue here
                end
            )
        end,
        function(client, reason)
            print('MQTT: Client failed reason: ' .. reason)
            print('MQTT: retrying in 1s.')
            tmr.create():alarm(1 * 1000, tmr.ALARM_SINGLE, send_to_mqtt)
        end
    )

    if success == false then
        print('MQTT: Client connection failed.')
    end
end

-- configure mqtt and send values
local function configureMqtt()
    print('Application: Creating MQTT client.')
    m = mqtt.Client(config.mqtt.deviceId, 120)
    m:on(
        'connect',
        function(client)
            print('MQTT: Connected callback.')
        end
    )

    send_to_mqtt()
end

-- start wifi and call configureMqtt
local function startWifi()
    print('Application: Starting Wifi...')
    network.start(
        function()
            print('Network: Got IP')
            configureMqtt()
        end
    )
end

-- read sensor and send value if the brightness window changed
local function readSensorValue()
    print('Sensor: reading...')
    readLux(tsl2561.INTEGRATIONTIME_13MS)
    readValueCount = readValueCount + 1
    --print('Sensor: readValueCount: ' .. readValueCount)
    -- send values at least once an hour. measureInterval is 5 (minutes)
    hourlySend = tonumber(readValueCount) >= 60 / tonumber(config.lux.measureInterval)
    if hourlySend then
        print('Sensor: send value at least once an hour.')
        readValueCount = 0
    end

    -- save values so they will survive a deep sleep
    print('Sensor: Save values to rtc (' .. tostring(lux) .. ',' .. tostring(lastVoltage) .. ',' .. tostring(readValueCount) .. ')')
    rtcmem.write32(10, lux, lastVoltage, readValueCount)

    if getBrightness(lastLuxValue) ~= getBrightness(lux) or hourlySend then
        print('Sensor: Brightness changed from ' .. tostring(lastLuxValue) .. ' to ' .. tostring(lux) .. '')
        startWifi()
    else
        -- hint: after waking up the device will boot and not continue here
        print('Sensor: Brightness did not change. Old:' .. tostring(lastLuxValue) .. ', new:' .. tostring(lux) .. '')
        goSleep()
    end
end

function module.start(voltage)
    print('Application: Start (voltage: ' .. tostring(voltage) .. ')')
    -- set D5 to high to power up the sensor
    gpio.write(config.pins.activateTsl, gpio.HIGH)

    -- configure sensor
    status = tsl2561.init(config.pins.sda, config.pins.scl, tsl2561.ADDRESS_FLOAT, tsl2561.PACKAGE_T_FN_CL)
    if status == tsl2561.TSL2561_OK then
        print('Sensor: TSL2561 initialized')
        status = tsl2561.settiming(tsl2561.INTEGRATIONTIME_13MS, tsl2561.GAIN_1X)

        if status ~= tsl2561.TSL2561_OK then
            print('Sensor: Error Status setting timing:' .. status)
        end
    else
        print('Sensor: TSL2561 initialization failed with status: ' .. tostring(status))
    end

    -- get values from memory that survives deep sleep
    --print('Application: Reading values from RTC...')
    lastLuxValue, lastVoltage, readValueCount = rtcmem.read32(10, 3)
    if readValueCount < 0 then
        readValueCount = 0
    end
    print('Application: Values from RTC are lux:' .. lastLuxValue .. ', voltage:' .. lastVoltage .. ', readCount:' .. readValueCount)
    -- overwrite with current value
    lastVoltage = voltage

    readSensorValue()
end

return module
