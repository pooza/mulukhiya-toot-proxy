module Mulukhiya
  class TestCaseFilter < Ginseng::TestCaseFilter
    def self.create(name)
      Config.instance['/test/filters'].each do |entry|
        next unless entry['name'] == name
        return "Mulukhiya::#{name.camelize}TestCaseFilter".constantize.new(entry)
      end
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['/test/filters'].each do |entry|
        yield TestCaseFilter.create(entry['name'])
      end
    end
  end
end
