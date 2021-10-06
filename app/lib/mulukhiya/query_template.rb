module Mulukhiya
  class QueryTemplate < Ginseng::Postgres::QueryTemplate
    include Package
    include SNSMethods

    def self.escape(value)
      return Postgres.instance.escape_string(value)
    end

    private

    def dir
      return "app/query/#{Environment.controller_name}"
    end
  end
end
