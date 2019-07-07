module MulukhiyaTootProxy
  class Environment < Ginseng::Environment
    def self.name
      return File.basename(dir)
    end

    def self.ci?
      pp ENV
      return ENV['CI'].present?
    rescue
      return false
    end

    def self.dir
      return File.expand_path('../..', __dir__)
    end

    def self.auth(username, password)
      config = Config.instance
      return false unless username == config['/sidekiq/auth/user']
      return true if password.crypt(Environment.hostname) == config['/sidekiq/auth/password']
      return true if password == config['/sidekiq/auth/password']
      return false
    end
  end
end
