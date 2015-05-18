local responses = require "kong.tools.responses"

local _M = {}

function _M.execute(conf)

  local ip = ngx.var.remote_addr

  -- Get current block if it exists
  local block, err = dao.blocklist:find_one(ip)
  if err then
    return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
  end

  if block then
    ngx.ctx.stop_phases = true -- interrupt other phases of this request
    return responses.send(444, "IP is blocked")
  end

end

return _M
