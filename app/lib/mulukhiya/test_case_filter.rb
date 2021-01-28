module Mulukhiya
  class TestCaseFilter < Ginseng::TestCaseFilter
    include Package
    include SNSMethods

    def name
      return params['name']
    end

    def account
      @account ||= account_class.test_account
      return @account
    rescue => e
      logger.error(error: e)
      return nil
    end

    def exec(cases)
      @params['cases'].each do |pattern|
        cases.delete_if do |v|
          File.fnmatch(pattern, v)
        end
      end
    end

    def self.create(name)
      all do |filter|
        return filter if filter.name == name
      end
    end

    def self.all
      return enum_for(__method__) unless block_given?
      config.raw.dig('test', 'filters').each do |entry|
        yield "Mulukhiya::#{name.camelize}TestCaseFilter".constantize.new(entry)
      end
    end
  end
end
