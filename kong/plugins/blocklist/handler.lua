-- Copyright (C) Mashape, Inc.

local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.blocklist.access"

local BlocklistHandler = BasePlugin:extend()

function BlocklistHandler:new()
  BlocklistHandler.super.new(self, "blocklist")
end

function BlocklistHandler:access(conf)
  BlocklistHandler.super.access(self)
  access.execute(conf)
end

BlocklistHandler.PRIORITY = 800

return BlocklistHandler
