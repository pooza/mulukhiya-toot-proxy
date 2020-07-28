require 'rss'
require 'time'

module Mulukhiya
  class AtomFeedRenderer < Ginseng::Web::Renderer
    include Package
    attr_reader :entries, :params

    def initialize(params = {})
      super()
      @params = {
        title: package_class.name,
        link: package_class.url.to_s,
        description: package_class.description,
        author: package_class.authors.first,
        date: Time.now,
        generator: package_class.user_agent,
      }
      @params.merge!(params)
      @entries = []
    end

    def type
      return 'application/atom+xml; charset=UTF-8'
    end

    def push(values)
      entries.push(values.to_h)
    end

    def to_s
      atom = RSS::Maker.make('atom') do |maker|
        maker.items.do_sort = true
        maker.channel.id = params[:link]
        params.symbolize_keys.each {|k, v| maker.channel.send("#{k}=", v)}
      end
      return atom.to_s
    end
  end
end
