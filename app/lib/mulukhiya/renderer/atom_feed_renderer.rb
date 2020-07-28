require 'rss'
require 'time'

module Mulukhiya
  class AtomFeedRenderer < Ginseng::Web::Renderer
    include Package
    attr_reader :entries, :channel

    def initialize(channel = {})
      super()
      @channel = {
        title: package_class.name,
        link: package_class.url,
        description: package_class.description,
        author: package_class.authors.first,
        date: Time.now,
        generator: package_class.user_agent,
      }
      @channel.merge!(channel)
      @entries = []
    end

    def type
      return 'application/atom+xml; charset=UTF-8'
    end

    def push(values)
      entries.push(values.to_h)
      @atom = nil
    end

    def atom
      @atom ||= RSS::Maker.make('atom') do |maker|
        maker.items.do_sort = true
        maker.channel.id = channel[:link]
        channel.each {|k, v| maker.channel.send("#{k}=", v)}
        entries.each do |entry|
          maker.items.new_item do |item|
            entry.each {|k, v| item.send("#{k}=", v)}
          end
        end
      end
      return @atom
    end

    def to_s
      return atom.to_s
    end
  end
end
