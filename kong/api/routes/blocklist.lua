-- Copyright (C) Mashape, Inc.

local BaseController = require "kong.api.routes.base_controller"

local Bocklist = BaseController:extend()

function Bocklist:new()
  Bocklist.super.new(self, dao.blocklist, "blocklist")
end

return Bocklist
