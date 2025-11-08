module Mulukhiya
  class UserDecorationInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.decoration?
      return super
    end

    def initialize_params(params)
      super
      @sns = info_agent_service
    end

    def perform(params = {})
      initialize_params(params)
      if id = params[:account_id]
        log(mode: 'single')
        clear_user_decorations(account_class[id])
      else
        log(mode: 'all')
        decorated_accounts.each do |account|
          clear_user_decorations(account)
        end
      end
    end

    def decorated_accounts
      return enum_for(__method__) unless block
      Postgres.exec(:decorated_accounts)
        .map {|row| row[:id]}
        .filter_map {|id| account_class[id] rescue nil}
        .each(&block)
    rescue => e
      e.log
      return []
    end

    def clear_user_decorations(account)
      account.avatar_decorations do |entry|
        next unless decoration = decoration_class[entry[:id]]
        next unless decoration.livecure?
        account.update(
          avatar_decorations: account.avatar_decorations.delete_if {|v| v[:id] == decoration.id},
        )
        log(acct: account.acct.to_s, decoration: decoration.to_h, message: 'removed')
      rescue => e
        e.log(account: account.acct.to_s, decoration_id: entry[:id])
      end
    rescue => e
      e.log
    end
  end
end
