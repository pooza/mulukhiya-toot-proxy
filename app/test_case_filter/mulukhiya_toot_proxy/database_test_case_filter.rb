module MulukhiyaTootProxy
  class DatabaseTestCaseFilter < TestCaseFilter
    def active?
      return !Postgres.config?
    end

    private

    def initialize(params)
      super(params)
      Postgres.connect if Postgres.config?
    end
  end
end
