module Mulukhiya
  class PostgresTestCaseFilter < TestCaseFilter
    def active?
      return !Environment.postgres? || !Postgres.config?
    end
  end
end
