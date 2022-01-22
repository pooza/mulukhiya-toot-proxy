module Mulukhiya
  class FilterCommandHandler < CommandHandler
    def disable?
      return true unless controller_class.filter?
      return super
    end

    def exec
      params = parser.params.clone
      params['phrase'] ||= params['tag'].to_hashtag
      case params['action']
      when 'register', nil
        sns.unregister_filter(params['phrase'])
        sns.register_filter(phrase: params['phrase'])
        Sidekiq.set_schedule("livecure_filter_remove_#{sns.account.username}", {
          at: handler_config(:minutes).minutes.after,
          class: 'Mulukhiya::LivecureFilterRemoveWorker',
          args: [{account_id: sns.account.id, phrase: params['phrase']}],
        })
      when 'unregister'
        sns.unregister_filter(params['phrase'])
      end
    end
  end
end
