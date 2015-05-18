local Migration = {
  name = "2015-05-17_blocklist",

  up = function(options)
    return [[

      CREATE TABLE IF NOT EXISTS blocklist(
        ip text,
        action text,
        created_at timestamp,
        expires_at timestamp,
        PRIMARY KEY (ip, expires_at)
      );

    ]]
  end,

  down = function(options)
    return [[
      DROP TABLE blocklist;
    ]]
  end
}

return Migration
