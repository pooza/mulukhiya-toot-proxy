module MulukhiyaTootProxy
  class Environment < Ginseng::Environment
    def self.name
      return File.basename(dir)
    end

    def self.dir
      return MulukhiyaTootProxy.dir
    end

    def self.config
      return Config.instance
    end

    def self.sns_class
      return "MulukhiyaTootProxy::#{config['/controller'].classify}Service".constantize
    end

    def self.controller_class
      return "MulukhiyaTootProxy::#{config['/controller'].classify}Controller".constantize
    end

    def self.account_class
      return "MulukhiyaTootProxy::#{config['/controller'].classify}::Account".constantize
    end

    def self.health
      values = {version: Package.version, status: 200}
      ['Postgres', 'Redis'].each do |service|
        health = "MulukhiyaTootProxy::#{service}".constantize.health
        values[:status] = 503 unless health[:status] == 'OK'
        values[service.downcase] = health
      end
      return values
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
