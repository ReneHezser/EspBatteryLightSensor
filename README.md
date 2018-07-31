# EspBatteryLightSensor
Values from a TSL2561 are read and sent to an MQTT broker. The battery powered ESP8266 will only do the reading/sending, if the voltage is high enough.

## NodeMCU
To get your device running, you might want to use theese tools:
- [https://esp8266.ru/esplorer/](https://esp8266.ru/esplorer/) - ESPlorer
- [https://nodemcu-build.com/](https://nodemcu-build.com/) - NodeMCU custom build

During development don't upload the init.lua yet. Be sure that the device is working as expected and then upload the init.lua to start automatically.

## Hardware Setup
TODO

## Config file
The config file *config.lua* is not included in the repository. You will need to create one and adjust the parameters.
```lua
local module = {}

module.pins = {}
module.pins.sda = 2
module.pins.scl = 1

module.maxLux = 45000

module.voltage = {}
module.voltage.multiplicator = 0.4
module.voltage.minimum = 3.2

module.wifi = {}
module.wifi.ssid = 'ssid'
module.wifi.password = 'key'

module.mqtt = {}
module.mqtt.url = "ip address"
module.mqtt.deviceId = "LightSensor1"
module.mqtt.topics = {}
module.mqtt.topics.light = 'light/1/lumen'
module.mqtt.topics.voltage = 'light/1/voltage'

return module
```