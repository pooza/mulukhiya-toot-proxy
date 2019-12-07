module MulukhiyaTootProxy
  class FilterCommandHandler < CommandHandler
    def dispatch
      params = @parser.params.clone
      params['phrase'] ||= Mastodon.create_tag(params['tag'].sub(/^#/, ''))

      case params['action']
      when 'register', nil
        remove_filter(params['phrase'])
        mastodon.register_filter(phrase: params['phrase'])
      when 'unregister'
        remove_filter(params['phrase'])
      end
    end

    private

    def remove_filter(phrase)
      mastodon.filters.each do |filter|
        next unless filter['phrase'] == phrase
        mastodon.unregister_filter(filter['id'])
      end
    end
  end
end
