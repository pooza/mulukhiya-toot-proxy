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
      values.deep_stringify_keys!
      handle_user_tags(values)
      handle_lemmy_password(values)
      @storage.update(@account.id, values)
      @values = @storage[@account.id]
    rescue => e
      logger.error(error: e)
    end

    def token
      return (self['/mulukhiya/token'] || self['/webhook/token']).decrypt
    rescue
      return self['/mulukhiya/token'] || self['/webhook/token']
    end

    def token=(token)
      token = token.decrypt rescue token
      update(
        webhook: {token: nil},
        mulukhiya: {token: token.encrypt},
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

    def to_json(*_args)
      return @values.to_json
    end

    alias to_s to_json

    private

    def handle_user_tags(values)
      flatten = values.key_flatten
      flatten['/tagging/user_tags'] ||= flatten['/tags'] if flatten.key?('/tags')
      if minutes = flatten['/tagging/minutes']
        Sidekiq.set_schedule("user_tag_initialize_#{@account.username}", {
          at: (minutes + config['/tagging/user_tags/extra_minutes']).to_i.minutes.after,
          class: 'Mulukhiya::UserTagInitializeWorker',
          args: [{account: @account.id}],
        })
        Sidekiq::Scheduler.reload_schedule!
        values['tagging']['minutes'] = nil
      elsif flatten.key?('/tagging/user_tags') && flatten['/tagging/user_tags'].empty?
        Sidekiq.remove_schedule("user_tag_initialize_#{@account.username}")
        Sidekiq::Scheduler.reload_schedule!
      end
    end

    def handle_lemmy_password(values)
      return unless password = values.dig('lemmy', 'password')
      values['lemmy']['password'] = password.encrypt
    end
  end
end
