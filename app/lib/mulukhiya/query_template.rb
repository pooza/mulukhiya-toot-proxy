module Mulukhiya
  class QueryTemplate < Ginseng::Postgres::QueryTemplate
    include Package

    private

    def dir
      return "app/query/#{Environment.controller_name}"
    end
  end
end
