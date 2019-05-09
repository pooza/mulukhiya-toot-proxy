module MulukhiyaTootProxy
  class Postgres < Ginseng::Postgres::Database
    include Package

    def default_dbname
      return 'mastodon'
    end

    def begin
      @db.exec('BEGIN')
    rescue PG::Error => e
      raise Ginseng::DatabaseError, e.message
    end

    def rollback
      @db.exec('ROLLBACK')
    rescue PG::Error => e
      raise Ginseng::DatabaseError, e.message
    end

    def commit
      @db.exec('COMMIT')
    rescue PG::Error => e
      raise Ginseng::DatabaseError, e.message
    end

    def self.dsn
      return Ginseng::Postgres::DSN.parse(Config.instance['/postgres/dsn'])
    end
  end
end
