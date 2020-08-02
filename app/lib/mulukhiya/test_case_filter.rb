module Mulukhiya
  class TestCaseFilter
    include Package

    def active?
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def params=(values)
      @params = values.key_flatten
    end

    def exec(cases)
      cases.delete_if do |v|
        @params['/cases'].member?(File.basename(v, '.rb'))
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

    private

    def initialize(params)
      self.params = params
    end
  end
end
