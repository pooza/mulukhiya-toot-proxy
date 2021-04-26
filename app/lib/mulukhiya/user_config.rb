module Mulukhiya
  class UserConfig
    include Package
    include SNSMethods

    def initialize(account)
      @account = account if account.is_a?(account_class)
      if account.is_a?(Hash) && (token = account['/mulukhiya/token'])
        @account ||= account_class.get(token: token)
      end
      @account ||= account_class[account]
      @storage = UserConfigStorage.new
      @values = @storage[@account.id]
    end

    def raw
      return JSON.parse(@storage.get(@account.id))
    end

    def [](key)
      return @values[key]
    end

    def update(values)
      config = values.deep_stringify_keys!
      handle_user_tags(config)
      handle_lemmy_password(config)
      @storage.update(@account.id, config)
      @values = @storage[@account.id]
    end

    def token
      return self['/mulukhiya/token'] || self['/webhook/token']
    end

    def token=(token)
      update(
        webhook: {token: nil},
        mulukhiya: {token: token},
      )
    end

    def tags
      return self['/tagging/user_tags']
    end

    def clear_tags
      update(tagging: {user_tags: nil})
    end

    alias to_h raw

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return @values["/handler/#{handler.underscore}/disable"] == true rescue false
    end

    private

    def handle_user_tags(config)
      return unless config['tagging'].is_a?(Hash)
      if minutes = config['tagging']['minutes']
        Sidekiq.set_schedule(task_name, create_schedule_params(minutes))
        config['tagging']['minutes'] = nil
      elsif config['tagging'].key?('user_tags') && config['tagging']['user_tags'].empty?
        Sidekiq.remove_schedule(task_name)
      end
      Sidekiq::Scheduler.reload_schedule!
    end

    def handle_lemmy_password(config)
      return unless password = config.dig('lemmy', 'password')
      config['lemmy']['password'] = password.encrypt
    end

    def task_name
      return "user_tag_initialize_#{@account.username}"
    end
  end
end
