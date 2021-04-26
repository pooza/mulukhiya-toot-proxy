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
      values = values.deep_stringify_keys!
      handle_user_tags(values)
      handle_lemmy_password(values)
      @storage.update(@account.id, values)
      @values = @storage[@account.id]
    rescue => e
      logger.error(error: e)
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

    def handle_user_tags(values)
      return unless values['tagging'].is_a?(Hash)
      task_name = "user_tag_initialize_#{@account.username}"
      if minutes = values['tagging']['minutes']
        Sidekiq.set_schedule(task_name, {
          at: (minutes + config['/tagging/user_tags/extra_minutes']).to_i.minutes.after,
          class: 'Mulukhiya::UserTagInitializeWorker',
          args: [{account: @account.id}],
        })
        values['tagging']['minutes'] = nil
      elsif values['tagging'].key?('user_tags') && values['tagging']['user_tags'].empty?
        Sidekiq.remove_schedule(task_name)
      end
      Sidekiq::Scheduler.reload_schedule!
    end

    def handle_lemmy_password(values)
      return unless password = values.dig('lemmy', 'password')
      values['lemmy']['password'] = password.encrypt
    end
  end
end
