module Mulukhiya
  class QueryTemplate < Ginseng::Postgres::QueryTemplate
    include Package

    def self.escape(v)
      return Postgres.instance.escape_string(v)
    end

    private

    def dir
      return "app/query/#{Environment.controller_name}"
    end
  end
end
