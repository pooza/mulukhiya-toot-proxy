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
      return "MulukhiyaTootProxy::#{controller_name.camelize}Service".constantize
    end

    def self.controller_name
      return config['/controller']
    end

    def self.test_account
      return sns_class.new.account
    end

    def self.controller_class
      return "MulukhiyaTootProxy::#{controller_name.camelize}Controller".constantize
    end

    def self.mastodon?
      return controller_name == 'mastodon'
    end

    def self.dolphin?
      return controller_name == 'dolphin'
    end

    def self.account_class
      return "MulukhiyaTootProxy::#{controller_name.camelize}::Account".constantize
    end

    def self.status_class
      return "MulukhiyaTootProxy::#{controller_name.camelize}::Status".constantize
    end

    def self.attachment_class
      return "MulukhiyaTootProxy::#{controller_name.camelize}::Attachment".constantize
    end

    def self.parser_class
      case controller_name
      when 'mastodon'
        return MulukhiyaTootProxy::TootParser
      when 'dolphin'
        return MulukhiyaTootProxy::NoteParser
      end
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
      return false unless username == config['/sidekiq/auth/user']
      return true if password.crypt(Environment.hostname) == config['/sidekiq/auth/password']
      return true if password == config['/sidekiq/auth/password']
      return false
    end
  end
end
