module MulukhiyaTootProxy
  class FavDropboxClippingHandler < Handler
    def disable?
      return true unless Postgres.config?
      return true if sns.account.config["/handler/#{underscore_name}/disable"].nil?
      return true if sns.account.disable?(underscore_name)
      return true if @config.disable?(underscore_name)
      return false
    rescue Ginseng::ConfigError
      return false
    end

    def handle_post_bookmark(body, params = {})
      return unless uri = Environment.status_class[body[message_key]].uri
      return unless uri.absolute?
      DropboxClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
      @result.push(url: uri.to_s)
    end
  end
end
