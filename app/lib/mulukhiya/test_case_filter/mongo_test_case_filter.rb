module Mulukhiya
  class MongoTestCaseFilter < TestCaseFilter
    def active?
      return !Environment.mongo? || !Mongo.config?
    end
  end
end
