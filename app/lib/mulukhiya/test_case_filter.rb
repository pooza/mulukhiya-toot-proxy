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
        cases.clone.select {|v| File.fnmatch(pattern, v)}.each do |v|
          puts v
          cases.delete(v)
        end
      end
    end

    def self.create(name)
      return all.find {|v| v.name == name}
    end

    def self.all
      return enum_for(__method__) unless block_given?
      config.raw.dig('test', 'filters').each do |entry|
        yield "Mulukhiya::#{entry['name'].camelize}TestCaseFilter".constantize.new(entry)
      end
    end
  end
end
