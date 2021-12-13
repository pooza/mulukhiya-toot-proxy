module Mulukhiya
  class UserConfig
    include Package
    include SNSMethods

    def initialize(account)
      @account = account if account.is_a?(account_class)
      if account.is_a?(Enumerable) && (token = account['/mulukhiya/token'])
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
      values = encrypt(values)
      @storage.update(@account.id, values)
      @values = @storage[@account.id]
    rescue => e
      Event.new(:alert).dispatch(e)
      logger.error(error: e)
    end

    def token
      return (self['/mulukhiya/token'] || self['/webhook/token']).decrypt
    rescue
      return self['/mulukhiya/token'] || self['/webhook/token']
    end

    def token=(token)
      token = (token.decrypt rescue token)
      update(
        webhook: {token: nil},
        mulukhiya: {token: token.encrypt},
      )
    end

    def tags
      return TagContainer.new(self['/tagging/user_tags'])
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

    def encrypt(arg)
      if arg.is_a?(Hash)
        arg.deep_stringify_keys!
        arg.each do |k, v|
          next if v.to_s.empty?
          if config['/user_config/encrypt_fields'].member?(k)
            plain = (v.decrypt rescue v.to_s)
            arg[k] = plain.encrypt
          else
            arg[k] = encrypt(v)
          end
        end
      end
      return arg
    end

    private

    def handle_user_tags(values)
      flatten = values.key_flatten
      if minutes = flatten['/tagging/minutes']
        Sidekiq.set_schedule("user_tag_initialize_#{@account.username}", {
          at: (minutes + Handler.create('user_tag').extra_minutes).to_i.minutes.after,
          class: 'Mulukhiya::UserTagInitializeWorker',
          args: [{account_id: @account.id}],
        })
        values['tagging']['minutes'] = nil
      elsif flatten.key?('/tagging/user_tags') && flatten['/tagging/user_tags'].empty?
        Sidekiq.remove_schedule("user_tag_initialize_#{@account.username}")
      end
    end
  end
end
