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
        remove_filter(params['phrase'])
        sns.register_filter(phrase: params['phrase'])
      when 'unregister'
        remove_filter(params['phrase'])
      end
    end

    private

    def remove_filter(phrase)
      sns.filters.select {|f| f.is_a?(Enumerable) && f['phrase'] == phrase}.each do |filter|
        sns.unregister_filter(filter['id'])
      end
    end
  end
end
