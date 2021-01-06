module Mulukhiya
  class TestCaseFilter < Ginseng::TestCaseFilter
    include Package
    include SNSMethods

    def account
      @account ||= account_class.test_account
      return @account
    rescue => e
      logger.error(error: e)
      return nil
    end

    def exec(cases)
      @params['/cases'].each do |pattern|
        cases.delete_if do |v|
          File.fnmatch(pattern, v)
        end
      end
    end

    def self.create(name)
      config['/test/filters'].each do |entry|
        next unless entry['name'] == name
        return "Mulukhiya::#{name.camelize}TestCaseFilter".constantize.new(entry)
      end
    end

    def self.all
      return enum_for(__method__) unless block_given?
      config['/test/filters'].each do |entry|
        yield TestCaseFilter.create(entry['name'])
      end
    end
  end
end
