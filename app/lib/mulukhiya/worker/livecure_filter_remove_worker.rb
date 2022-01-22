module Mulukhiya
  class LivecureFilterRemoveWorker < Worker
    def perform(params = {})
      params.deep_symbolize_keys!
      unless account = account_class[params[:account_id]]
        raise Ginseng::RequestError, "Account #{params[:account_id]} not found"
      end
      raise Ginseng::RequestError, 'phrase undefined' unless params[:phrase]
      sns = account.webhook.sns
      return unless filter = sns.filters.find {|v| v['phrase'] == params[:phrase]}
      sns.unregister_filter(filter['id'])
      info_agent_service.notify(account, worker_config(:message))
    end
  end
end
