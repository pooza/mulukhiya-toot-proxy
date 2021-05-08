module Mulukhiya
  class RSS20FeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @http = HTTP.new
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = channel['title']
      @channel[:description] = channel['description']
    end

    def entries=(entries)
      entries.each {|v| push(v)}
    end

    def feed
      @feed ||= RSS::Maker.make(feed_type) do |maker|
        maker.items.do_sort = true
        maker.channel.id = channel[:link]
        channel.each {|k, v| maker.channel.send("#{k}=", v)}
        entries.each do |entry|
          maker.items.new_item do |item|
            if info = fetch_image(entry.dig('enclosure', 'url'))
              info.each {|k, v| item.enclosure.send("#{k}=", v)}
              entry.delete('enclosure')
            end
            entry.each {|k, v| item.send("#{k}=", v)}
          end
        end
      end
      return @feed
    end

    private

    def fetch_image(uri)
      return nil unless uri
      response = @http.get(uri)
      return {
        url: uri.to_s,
        type: response.headers['content-type'],
        length: response.headers['content-length'],
      }
    end
  end
end
