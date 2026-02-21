require 'sidekiq/testing'
require 'rack/test'
require 'timecop'
require 'webmock/test_unit'
WebMock.allow_net_connect!

module Mulukhiya
  class TestCase < Ginseng::TestCase
    include Package
    include SNSMethods

    def teardown
      config.reload
      @handler&.clear
      Timecop.return
      WebMock.allow_net_connect!
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

    def self.load(cases = nil)
      ENV['TEST'] = Package.full_name
      Sidekiq::Testing.fake!
      file_map(cases).each do |name, path|
        raise 'disabled' if name.end_with?('_handler') && Handler.create(name).disable?
        raise 'disabled' if name.end_with?('_worker') && Worker.create(name).disable?
        puts "+ case: #{name}" if Environment.test?
        require path
      rescue => e
        puts "- case: #{name} (#{e.message})" if Environment.test?
      end
    end

    def self.names(cases = nil)
      return file_map(cases).keys.to_set
    end

    def self.file_map(cases = nil)
      finder = Ginseng::FileFinder.new
      finder.dir = dir
      finder.patterns.push('*.rb')
      all = finder.exec.to_h {|path| [File.basename(path, '.rb'), path]}
      return all unless cases
      targets = cases.split(',').map(&:underscore)
        .map {|v| [v, "#{v}_test", v.sub(/_test$/, '')]}.flatten.compact
      return all.slice(*targets)
    end

    def self.dir
      return File.join(Environment.dir, 'test')
    end
  end
end
