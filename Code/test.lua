-- use this file to "start up" without init.lua
-- call this file during development

-- load modules and make the global functions available
network = require("network")
app = require("application")
config = require("config")
-- call start function after everything has been loaded
require("setup").start()