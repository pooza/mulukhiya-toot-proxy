module Mulukhiya
  class TestCaseFilter < Ginseng::TestCaseFilter
    include Package
    include SNSMethods

    def account
      @account ||= account_class.test_account
      return @account
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
