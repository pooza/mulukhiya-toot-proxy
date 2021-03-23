module Mulukhiya
  class FilterCommandHandler < CommandHandler
    def disable?
      return false unless controller_class.filter?
      return super
    end

    def exec
      params = parser.params.clone
      params['phrase'] ||= params['tag'].to_hashtag

      case params['action']
      when 'register', nil
        remove_filter(params['phrase'])
        sns.register_filter(phrase: params['phrase'])
      when 'unregister'
        remove_filter(params['phrase'])
      end
    end

    private

    def remove_filter(phrase)
      sns.filters.each do |filter|
        next unless filter.is_a?(Hash)
        next unless filter['phrase'] == phrase
        sns.unregister_filter(filter['id'])
      end
    end
  end
end
