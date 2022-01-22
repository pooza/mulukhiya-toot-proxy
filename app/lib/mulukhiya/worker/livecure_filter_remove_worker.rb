module Mulukhiya
  class LivecureFilterRemoveWorker < Worker
    def perform(params = {})
      params.deep_symbolize_keys!
      unless account = account_class[params[:account_id]]
        raise Ginseng::NotFoundError, "Account #{params[:account_id]} not found"
      end
      sns = sns_class.new
      sns.token = account.token
      sns.unregister_filter(params[:phrase])
      info_agent_service.notify(account, worker_config(:message))
    end
  end
end
