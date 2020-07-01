module Mulukhiya
  class DatabaseTestCaseFilter < TestCaseFilter
    def active?
      return !Environment.postgres? || !Postgres.config?
    end
  end
end
