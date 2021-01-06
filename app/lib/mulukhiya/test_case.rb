require 'sidekiq/testing'
require 'rack/test'

module Mulukhiya
  class TestCase < Ginseng::TestCase
    include Package
    include SNSMethods

    def account
      @account ||= Environment.account_class.test_account
      return @account
    end

    def status_field
      return Environment.controller_class.status_field
    end

    def status_key
      return Environment.controller_class.status_key
    end

    def handler?
      return false if @handler.nil?
      return false if @handler.disable?
      return true
    end

    def self.load
      ENV['TEST'] = Package.full_name
      Sidekiq::Testing.fake!
      names.each do |name|
        puts "case: #{name}"
        require File.join(dir, "#{name}.rb")
      end
    end

    def self.names
      names = ARGV.first.split(/[^[:word:],]+/)[1]&.split(',')
      names ||= Dir.glob(File.join(dir, '*.rb')).map {|v| File.basename(v, '.rb')}
      TestCaseFilter.all do |filter|
        filter.exec(names) if filter.active?
      end
      return names.sort.uniq
    end

    def self.dir
      return File.join(Environment.dir, 'test')
    end
  end
end
