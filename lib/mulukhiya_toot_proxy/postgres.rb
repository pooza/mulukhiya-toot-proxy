module MulukhiyaTootProxy
  class Postgres < Ginseng::Postgres::Database
    include Package

    def default_dbname
      return 'mastodon'
    end

    def self.dsn
      return Ginseng::Postgres::DSN.parse(Config.instance['/postgres/dsn'])
    end
  end
end
