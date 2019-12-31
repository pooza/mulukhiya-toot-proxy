require 'test/unit'
require 'sidekiq/testing'

module MulukhiyaTootProxy
  class TestCase < Test::Unit::TestCase
    def message_field
      return Environment.sns_class.message_field
    end

    def handler?
      return false if @handler.nil? || @handler.disable?
      return true
    end

    def self.load
      ENV['TEST'] = Package.name
      Sidekiq::Testing.fake!
      cases = Dir.glob(File.join(Environment.dir, 'test/*.rb'))
      TestCaseFilter.all do |filter|
        filter.exec(cases) if filter.active?
      end
      cases.sort.each do |f|
        puts "case: #{File.basename(f)}"
        require f
      end
    end
  end
end
