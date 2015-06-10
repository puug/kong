local spec_helper = require "spec.spec_helpers"
local http_client = require "kong.tools.http_client"
local cjson = require "cjson"

local STUB_GET_URL = spec_helper.STUB_GET_URL
local STUB_POST_URL = spec_helper.STUB_POST_URL

describe("Authentication Plugin", function()

  setup(function()
    spec_helper.prepare_db()
    spec_helper.insert_fixtures {
      api = {
        { name = "tests basicauth", public_dns = "basicauth.com", target_url = "http://mockbin.com" }
      },
      consumer = {
        { username = "basicauth_tests_consuser" }
      },
      plugin_configuration = {
        { name = "basicauth", value = {}, __api = 1 }
      },
      basicauth_credential = {
        { username = "username", password = "password", __consumer = 1 }
      }
    }

    spec_helper.start_kong()
  end)

  teardown(function()
    spec_helper.stop_kong()
  end)

  describe("Basic Authentication", function()

    it("should return invalid credentials when the credential value is wrong", function()
      local response, status = http_client.get(STUB_GET_URL, {}, {host = "basicauth.com", authorization = "asd"})
      local body = cjson.decode(response)
      assert.are.equal(403, status)
      assert.are.equal("Invalid authentication credentials", body.message)
    end)

    it("should not pass when passing only the password", function()
      local response, status = http_client.get(STUB_GET_URL, {}, {host = "basicauth.com", authorization = "Basic OmFwaWtleTEyMw=="})
      local body = cjson.decode(response)
      assert.are.equal(403, status)
      assert.are.equal("Invalid authentication credentials", body.message)
    end)

    it("should not pass when passing only the username", function()
      local response, status = http_client.get(STUB_GET_URL, {}, {host = "basicauth.com", authorization = "Basic dXNlcjEyMzo="})
      local body = cjson.decode(response)
      assert.are.equal(403, status)
      assert.are.equal("Invalid authentication credentials", body.message)
    end)

    it("should return invalid credentials when the credential parameter name is wrong in GET", function()
      local response, status = http_client.get(STUB_GET_URL, {}, {host = "basicauth.com", authorization123 = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="})
      local body = cjson.decode(response)
      assert.are.equal(403, status)
      assert.are.equal("Invalid authentication credentials", body.message)
    end)

    it("should return invalid credentials when the credential parameter name is wrong in POST", function()
      local response, status = http_client.post(STUB_POST_URL, {}, {host = "basicauth.com", authorization123 = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="})
      local body = cjson.decode(response)
      assert.are.equal(403, status)
      assert.are.equal("Invalid authentication credentials", body.message)
    end)

    it("should pass with GET", function()
      local response, status = http_client.get(STUB_GET_URL, {}, {host = "basicauth.com", authorization = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="})
      assert.are.equal(200, status)
      local parsed_response = cjson.decode(response)
      assert.are.equal("Basic dXNlcm5hbWU6cGFzc3dvcmQ=", parsed_response.headers.authorization)
    end)

    it("should pass with POST", function()
      local response, status = http_client.post(STUB_POST_URL, {}, {host = "basicauth.com", authorization = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="})
      assert.are.equal(200, status)
      local parsed_response = cjson.decode(response)
      assert.are.equal("Basic dXNlcm5hbWU6cGFzc3dvcmQ=", parsed_response.headers.authorization)
    end)

  end)
end)
