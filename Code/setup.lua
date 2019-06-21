local module = {}

function module.start()
    -- ensuring correct ADC mode.
    print('Configuring ADC...')
    if adc.force_init_mode(adc.INIT_ADC) then
        node.restart()
        return -- don't bother continuing, the restart is scheduled
    end

    -- configure D6 as GPIO to power the TSL2561. This saves battery compared to connecting it to the 3.3V output
    print('Configuring D5 for output...')
    gpio.mode(config.pins.activateTsl, gpio.OUTPUT)

    -- checking voltage first
    print('Reading analog input...')
    val = adc.read(0)
    volt = val * config.voltage.multiplicator
    print("ADC value: " .. tostring(val) .. ", " .. tostring(volt) .. "V")
    -- ignore small values, as there is no battery attached that can be measured
    if val < config.voltage.ignoreAdcValuesBelow then
        print('ignoring low ADC value')
    elseif volt < config.voltage.minimum then
        print('Voltage too low. Going to sleep...')
        -- go sleep again and hope the voltage will rise again
        node.dsleep(4294967295, 2)
        return
    end

    app.start(volt)
end

return module
