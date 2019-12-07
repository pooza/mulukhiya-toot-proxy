module MulukhiyaTootProxy
  class FilterCommandHandler < CommandHandler
    def dispatch
      params = @parser.params.clone
      params['phrase'] ||= Mastodon.create_tag(params['tag'].sub(/^#/, ''))

      case params['action']
      when 'register', nil
        mastodon.filters.each do |filter|
          next unless filter['phrase'] == params['phrase']
          mastodon.unregister_filter(filter['id'])
        end
        mastodon.register_filter(phrase: params['phrase'])
      when 'unregister'
        mastodon.filters.each do |filter|
          next unless filter['phrase'] == params['phrase']
          mastodon.unregister_filter(filter['id'])
        end
      end
    end
  end
end
