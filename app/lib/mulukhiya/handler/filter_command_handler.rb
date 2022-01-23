module Mulukhiya
  class FilterCommandHandler < CommandHandler
    def disable?
      return true unless controller_class.filter?
      return super
    end

    def exec
      params = parser.params.deep_symbolize_keys
      params[:phrase] ||= params[:tag].to_hashtag
      params[:minutes] ||= handler_config(:minutes)
      case params['action']
      when 'register', nil
        sns.filters(phrase: params[:phrase]).each {|f| sns.unregister_filter(f['id'])}
        sns.register_filter(phrase: params[:phrase])
        Sidekiq.set_schedule("livecure_filter_remove_#{sns.account.username}", {
          at: params[:minutes].minutes.after,
          class: 'Mulukhiya::LivecureFilterRemoveWorker',
          args: [{account_id: sns.account.id, phrase: params[:phrase]}],
        })
      when 'unregister'
        sns.filters(phrase: params[:phrase]).each {|f| sns.unregister_filter(f['id'])}
      end
    end
  end
end
