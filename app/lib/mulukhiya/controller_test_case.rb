module Mulukhiya
  class ControllerTestCase < TestCase
    include Rack::Test::Methods

    def setup
      ensure_db_or_omit
      WebMock.disable_net_connect!(allow_localhost: true)
      app.set(:host_authorization, permitted_hosts: ['example.org'])
      app.set(:raise_errors, true)
      app.set(:show_exceptions, false)
    end

    def teardown
      WebMock.reset!
      super
    end

    def app
      raise NotImplementedError, "#{self.class} must implement #app"
    end

    def upstream_url(path = '')
      base = config["/#{Environment.controller_name}/url"]
      return URI.join(base, path).to_s
    end

    private

    def ensure_db_or_omit
      Sequel::Model.db
    rescue Sequel::Error
      omit('PostgreSQL connection not configured (local-only limitation; CI provides one)')
    end
  end
end
