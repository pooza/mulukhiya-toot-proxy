require 'sidekiq/testing'
require 'rack/test'
require 'timecop'
require 'webmock'

module Mulukhiya
  class TestCase < Ginseng::TestCase
    include Package
    include SNSMethods
    include WebMock::API

    def teardown
      config.reload
      @handler&.clear
      Timecop.return
      WebMock.reset!
    end

    def account
      @account ||= account_class.test_account
      return @account
    rescue => e
      e.log
      return nil
    end

    def test_token
      return account_class.test_token
    rescue => e
      e.log
      return nil
    end

    def http
      @http ||= HTTP.new
      return @http
    end

    def fixture(name)
      return File.read(File.join(self.class.fixture_dir, name))
    end

    def json_fixture(name)
      return JSON.parse(fixture(name))
    end

    def self.fixture_dir
      return File.join(dir, 'fixture')
    end

    def self.load(cases = nil)
      ENV['TEST'] = Package.full_name
      Sidekiq::Testing.fake!
      names(cases).each do |name|
        raise 'disabled' if name.end_with?('_handler') && Handler.create(name).disable?
        raise 'disabled' if name.end_with?('_worker') && Worker.create(name).disable?
        puts "+ case: #{name}" if Environment.test?
        require File.join(dir, "#{name}.rb")
      rescue => e
        puts "- case: #{name} (#{e.message})" if Environment.test?
      end
    end

    def self.names(cases = nil)
      if cases
        names = cases.split(',').map(&:underscore)
          .map {|v| [v, "#{v}_test", v.sub(/_test$/, '')]}.flatten
          .select {|v| File.exist?(File.join(dir, "#{v}.rb"))}.compact
      else
        finder = Ginseng::FileFinder.new
        finder.dir = dir
        finder.patterns.push('*.rb')
        names = finder.exec.map {|v| File.basename(v, '.rb')}
      end
      return names.to_set
    end

    def self.dir
      return File.join(Environment.dir, 'test')
    end
  end
end
