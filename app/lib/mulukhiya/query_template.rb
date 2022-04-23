module Mulukhiya
  class QueryTemplate < Ginseng::Postgres::QueryTemplate
    include Package
    include SNSMethods

    def initialize(name)
      name = name.to_s
      super
    end

      def self.escape(value)
      return Postgres.instance.escape_string(value)
    end

    private

    def dir
      return File.join('app/query', Environment.controller_name)
    end
  end
end
