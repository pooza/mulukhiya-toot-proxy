module Mulukhiya
  class FilterUnregisterWorker < Worker
    def disable?
      return true unless controller_class.filter?
      return super
    end

    def perform(params = {})
      initialize_params(params)
      params[:phrase] ||= params[:tag]&.to_hashtag
      unless account = account_class[params[:account_id]]
        raise Ginseng::RequestError, "Account #{params[:account_id]} not found"
      end
      raise Ginseng::RequestError, 'phrase undefined' unless params[:phrase]
      sns = account.webhook.sns
      sns.filters(phrase: params[:phrase]).each {|f| sns.unregister_filter(f['id'])}
      info_agent_service&.notify(account, worker_config(:message))
    end
  end
end
