module Mulukhiya
  class DecorationApplyWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def perform(params = {})
      initialize_params(params)
      account = account_class[params[:account_id]]
      apply_decoration(account)
    end

    def apply_decoration(account)
      service = sns_class.new
      service.token = account.user_config.token
      decoration_id = account.user_config['/decoration/id']
      return unless decoration_id
      unless account.user_config['/decoration/saved_state']
        current = service.fetch_account_detail
        account.user_config.update(decoration: {saved_state: current['avatarDecorations'] || []})
      end
      current_decorations = service.fetch_account_detail['avatarDecorations'] || []
      new_decorations = current_decorations.reject {|d| d['id'] == decoration_id}
      new_decorations.push({'id' => decoration_id})
      service.update_account(avatarDecorations: new_decorations)
      log(acct: account.acct.to_s, decoration_id:, message: 'applied')
    rescue => e
      e.log
    end
  end
end
