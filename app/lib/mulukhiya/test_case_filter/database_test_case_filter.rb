module Mulukhiya
  class DatabaseTestCaseFilter < TestCaseFilter
    def active?
      return !Postgres.config?
    end

    private

    def initialize(params)
      super
      Postgres.connect if Postgres.config?
    end
  end
end
