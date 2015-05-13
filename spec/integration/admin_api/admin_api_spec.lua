local spec_helper = require "spec.spec_helpers"
local http_client = require "kong.tools.http_client"
local json = require "cjson"

local env = spec_helper.get_env()
local created_ids = {}

local kWebURL = spec_helper.API_URL
local ENDPOINTS = {
  {
    collection = "apis",
    total = table.getn(env.faker.FIXTURES.api) + 1,
    entity = {
      form = {
        public_dns = "api.mockbin.com",
        name = "mockbin",
        target_url = "http://mockbin.com"
      }
    },
    update_fields = { public_dns = "newapi.mockbin.com" },
    error_message = '{"public_dns":"public_dns is required","target_url":"target_url is required"}\n'
  },
  {
    collection = "consumers",
    total = table.getn(env.faker.FIXTURES.consumer) + 1,
    entity = {
      form = { custom_id = "123456789" },
    },
    update_fields = { custom_id = "ABC_custom_ID" },
    error_message = '{"custom_id":"At least a \'custom_id\' or a \'username\' must be specified","username":"At least a \'custom_id\' or a \'username\' must be specified"}\n'
  },
  {
    collection = "basicauth_credentials",
    total = table.getn(env.faker.FIXTURES.basicauth_credential) + 1,
    entity = {
      form = {
        username = "username5555",
        password = "password5555",
        consumer_id = function() return created_ids.consumers end
      }
    },
    update_fields = {
      username = "upd_username5555",
      password = "upd_password5555"
    },
    error_message = '{"username":"username is required","consumer_id":"consumer_id is required"}\n'
  },
  {
    collection = "keyauth_credentials",
    total = table.getn(env.faker.FIXTURES.keyauth_credential) + 1,
    entity = {
      form = {
        key = "apikey5555",
        consumer_id = function() return created_ids.consumers end
      }
    },
    update_fields = { key = "upd_apikey5555", },
    error_message = '{"key":"key is required","consumer_id":"consumer_id is required"}\n'
  },
  {
    collection = "plugins_configurations",
    total = table.getn(env.faker.FIXTURES.plugin_configuration) + 1,
    entity = {
      form = {
        name = "ratelimiting",
        api_id = function() return created_ids.apis end,
        consumer_id = function() return created_ids.consumers end,
        ["value.period"] = "second",
        ["value.limit"] = 10
      },
      json = {
        name = "ratelimiting",
        api_id = function() return created_ids.apis end,
        consumer_id = function() return created_ids.consumers end,
        value = {
          period = "second",
          limit = 10
        }
      }
    },
    update_fields = { enabled = false },
    error_message = '{"name":"name is required","api_id":"api_id is required","value":"value is required"}\n'
  }
}

describe("Admin API", function()

  setup(function()
    spec_helper.prepare_db()
    spec_helper.start_kong()
  end)

  teardown(function()
    spec_helper.stop_kong()
    spec_helper.reset_db()
  end)

  describe("/", function()
    local constants = require "kong.constants"

    it("should return Kong's version and a welcome message", function()
      local response, status = http_client.get(kWebURL)
      local body = json.decode(response)
      assert.are.equal(200, status)
      assert.truthy(body.version)
      assert.truthy(body.tagline)
      assert.are.same(constants.VERSION, body.version)
    end)

    it("should have a Server header", function()
      local _, _, headers = http_client.get(kWebURL)
      assert.are.same(string.format("%s/%s", constants.NAME, constants.VERSION), headers.server)
      -- Via is only set for proxied requests
      assert.falsy(headers.via)
    end)

  end)

  describe("POST", function()
    for i, v in ipairs(ENDPOINTS) do
      describe(v.collection.." entity", function()

        it("should not create with invalid url-encoded parameters", function()
            local response, status = http_client.post(kWebURL.."/"..v.collection.."/", {})
            assert.are.equal(400, status)
            assert.are.equal(v.error_message, response)
        end)

        it("should create an entity with an application/x-www-form-urlencoded body", function()
          -- Replace the IDs
          for k, p in pairs(v.entity.form) do
            if type(p) == "function" then
              v.entity.form[k] = p()
            end
          end

          local response, status = http_client.post(kWebURL.."/"..v.collection.."/", v.entity.form)
          local body = json.decode(response)
          assert.are.equal(201, status)
          assert.truthy(body)

          -- Save the ID for later use
          created_ids[v.collection] = body.id
        end)

        it("should create an entity with an application/json body", function()
          local _, err = env.dao_factory[v.collection]:delete(created_ids[v.collection])
          assert.falsy(err)

          local json_entity = v.entity.json and v.entity.json or v.entity.form
          -- Replace the IDs
          for k, p in pairs(json_entity) do
            if type(p) == "function" then
              json_entity[k] = p()
            end
          end

          local response, status = http_client.post(kWebURL.."/"..v.collection.."/", json_entity,
            { ["content-type"] = "application/json" }
          )
          local body = json.decode(response)
          assert.are.equal(201, status)
          assert.truthy(body)

          -- Save the ID for later use
          created_ids[v.collection] = body.id
        end)

      end)
    end
  end)

  describe("GET", function()
    for i, v in ipairs(ENDPOINTS) do
      describe(v.collection.." entity", function()

        it("should not retrieve any entity with an invalid parameter", function()
          local response, status = http_client.get(kWebURL.."/"..v.collection.."/"..created_ids[v.collection].."blah")
          local body = json.decode(response)
          assert.are.equal(404, status)
          assert.truthy(body)
          assert.are.equal('{"id":"'..created_ids[v.collection]..'blah is an invalid uuid"}\n', response)
        end)

        it("should retrieve all entities", function()
          local response, status = http_client.get(kWebURL.."/"..v.collection.."/")
          local body = json.decode(response)
          assert.are.equal(200, status)
          assert.truthy(body.data)
          --assert.truthy(body.total)
          --assert.are.equal(v.total, body.total)
          assert.are.equal(v.total, table.getn(body.data))
        end)

        it("should retrieve one entity", function()
          local response, status = http_client.get(kWebURL.."/"..v.collection.."/"..created_ids[v.collection])
          local body = json.decode(response)
          assert.are.equal(200, status)
          assert.truthy(body)
          assert.are.equal(created_ids[v.collection], body.id)
        end)

      end)
    end
  end)

  describe("PUT", function()
    for _, v in ipairs(ENDPOINTS) do
      describe(v.collection.." entity", function()

        it("should update an entity with an application/x-www-form-urlencoded body", function()
          local data = http_client.get(kWebURL.."/"..v.collection.."/"..created_ids[v.collection])
          local body = json.decode(data)

          -- Create new body
          for k, v in pairs(v.update_fields) do
            body[k] = v
          end

          local response, status = http_client.put(kWebURL.."/"..v.collection.."/"..created_ids[v.collection], body)
          local response_body = json.decode(response)
          assert.are.equal(200, status)
          assert.truthy(response_body)
          assert.are.equal(created_ids[v.collection], response_body.id)
          assert.are.same(body, response_body)
        end)

        it("should update an entity with an application/json body", function()
          local data = http_client.get(kWebURL.."/"..v.collection.."/"..created_ids[v.collection])
          local body = json.decode(data)

          -- Create new body
          for k, v in pairs(v.update_fields) do
            body[k] = v
          end

          local response, status = http_client.put(kWebURL.."/"..v.collection.."/"..created_ids[v.collection], body, { ["content-type"] = "application/json" })
          local response_body = json.decode(response)
          assert.are.equal(200, status)
          assert.truthy(response_body)
          assert.are.equal(created_ids[v.collection], response_body.id)
          assert.are.same(body, response_body)
        end)

      end)
    end
  end)

  -- Tests on DELETE must run in that order:
  --  1. plugins_configurations
  --  2. APIs/Consumers
  -- Since deleting APIs and Consumers delete related plugins_configurations.
  describe("DELETE", function()
    describe("plugins_configurations", function()

      it("should send 404 when trying to delete a non existing entity", function()
        local response, status = http_client.delete(kWebURL.."/plugins_configurations/00000000-0000-0000-0000-000000000000")
        assert.are.equal(404, status)
        assert.are.same('{"message":"Not found"}\n', response)
      end)

      it("should delete a plugin_configuration", function()
        local response, status = http_client.delete(kWebURL.."/plugins_configurations/"..created_ids.plugins_configurations)
        assert.are.equal(204, status)
        assert.falsy(response)
      end)

    end)

    describe("APIs", function()

      it("should delete an API", function()
        local response, status = http_client.delete(kWebURL.."/apis/"..created_ids.apis)
        assert.are.equal(204, status)
        assert.falsy(response)
      end)

    end)

    describe("Consumers", function()

      it("should delete a Consumer", function()
        local response, status = http_client.delete(kWebURL.."/consumers/"..created_ids.consumers)
        assert.are.equal(204, status)
        assert.falsy(response)
      end)

    end)
  end)
end)
