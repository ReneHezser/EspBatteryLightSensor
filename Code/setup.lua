local module = {}

function module.start()
    -- ensuring correct ADC mode.
    if adc.force_init_mode(adc.INIT_ADC) then
        node.restart()
        return -- don't bother continuing, the restart is scheduled
    end

    -- checking voltage first
    val = adc.read(0)
    volt = val * config.voltage.multiplicator
    print("ADC value: " .. tostring(val) .. ", " .. tostring(volt) .. "V")
    if volt < config.voltage.minimum then
        print('Voltage too low. Going to sleep...')
        -- go sleep again and hope the voltage will rise again
        node.dsleep(4294967295, 2)
        return
    end

    print("Starting Wifi...")
    network.start(
        function()
            print("Got IP. Starting application...")
            app.start()
        end
    )
end

return module
