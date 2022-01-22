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
        return unless handler_config(:minutes).present?
        Sidekiq.set_schedule("livecure_filter_remove_#{@account.username}", {
          at: handler_config(:minutes).after,
          class: 'Mulukhiya::LivecureFilterRemoveWorker',
          args: [{account_id: @account.id, phrase: params['phrase']}],
        })
      when 'unregister'
        sns.unregister_filter(params['phrase'])
      end
    end
  end
end
