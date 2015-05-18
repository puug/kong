local constants = require "kong.constants"
local cassandra = require "cassandra"
local BaseDao = require "kong.dao.cassandra.base_dao"
local timestamp = require "kong.tools.timestamp"
local luatz = require "luatz"

local SCHEMA = {
  ip = { type = "string", required = true, unique = true, queryable = true },
  action = { type = "string", required = true, unique = false, queryable = false },
  expiry_period = { type = "long", required = false, unique = false, queryable = false }
}

local Blocklist = BaseDao:extend()

function Blocklist:new(properties)
  self._schema = SCHEMA
  self._queries = {
    insert = [[ INSERT INTO blocklist (ip, action, created_at, expires_at)
                      VALUES (?, ?, dateof(now()), ?); ]],
    select_one = [[ SELECT * FROM blocklist WHERE ip = ? AND
                      expires_at < dateof(now()) order by expires_at desc LIMIT 1; ]],
    delete = {
      args_keys = { "ip" },
      query = [[ DELETE FROM blocklist WHERE ip = ?; ]]
    }
  }

  Blocklist.super.new(self, properties)
end

function Blocklist:block(ip, action, expiry_period)
  local expires_at = expiry_period and (luatz.gettime() + actual_expiry_period) or constants.DATABASE_MAX_TIMESTAMP
  Blocklist.super._execute(self, self._queries.insert, {
    ip,
    action,
    cassandra.timestamp(expires_at)
  })
end

-- @override
function Blocklist:insert(t)
  self:block(t.ip, t.action, t.expiry_period)
end

function Blocklist:find_one(ip)
  local block, err = Blocklist.super._execute(self, self._queries.select_one, {
    ip
  })
  if err then
    return nil, err
  end

  return block
end

-- Unsuported
function Blocklist:update()
  error("blocklist:update() not supported", 2)
end

function Blocklist:find()
  error("blocklist:find() not supported", 2)
end

function Blocklist:find_by_keys()
  error("blocklist:find_by_keys() not supported", 2)
end

return Blocklist
