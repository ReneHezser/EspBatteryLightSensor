local module = {}

local function readLux(integrationTime)
    lux = tsl2561.getlux()
    ch0, ch1 = tsl2561.getrawchannels()

    -- ensure max value, if the sensor is saturated by very bright light
    if integrationTime == 0 and (ch0 > 4808 or ch1 == 4808) then
        -- saturation reached
        lux = config.maxLux
    elseif integrationTime == 1 and (ch0 > 36938 or ch1 == 36938) then
        -- saturation reached
        lux = config.maxLux
    end

    print("lux:" .. lux .. ",Raw values:" .. ch0 .. "-" .. ch1)
end

function configureMqtt()
    m = mqtt.Client(config.mqtt.deviceId, 120)
    m:on(
        "connect",
        function(client)
            print("Connected to MQTT. Reading values and sending...")
        end
    )
    print("waiting for MQTT...")
    mqtt_connect()
end

function mqtt_connect()
    success = m:connect(config.mqtt.url, 1883, 0, 0, function(client)
      print("connected")
        readLux(tsl2561.INTEGRATIONTIME_13MS)
        print('sending lux...')
        client:publish(config.mqtt.topics.light, lux, 0, 0, function(client)
            volt = adc.read(0) * config.voltage.multiplicator
            print('now send voltage: ' .. tostring(volt) .. 'V')
            client:publish(config.mqtt.topics.voltage, volt, 0, 0, function()
                -- sleep for 5 minutes
                print("Going to sleep now...")
                node.dsleep(300000000, 2)
            end)
        end)
    end,
    function(client, reason)
      print("failed reason: " .. reason)
      tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, mqtt_connect)
    end)

    if success == false then
      print("Connection failed.")
    end
  end

function module.start()
    print("Application start")

    -- configure sensor
    status = tsl2561.init(config.pins.sda, config.pins.scl, tsl2561.ADDRESS_FLOAT, tsl2561.PACKAGE_T_FN_CL)
    if status == tsl2561.TSL2561_OK then
        status = tsl2561.settiming(tsl2561.INTEGRATIONTIME_13MS, tsl2561.GAIN_1X)

        if status ~= tsl2561.TSL2561_OK then
            print("Error Status setting timing:" .. status)
        end
    end

    configureMqtt()
end

return module
