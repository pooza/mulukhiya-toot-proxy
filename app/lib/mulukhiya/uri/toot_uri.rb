module Mulukhiya
  class TootURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @logger = Logger.new
    end

    def toot_id
      @config['/parser/toot/patterns'].each do |pattern|
        next unless matches = path.match(pattern)
        id = matches[1]
        return id.to_i if id.match?(/^[[:digit:]]+$/)
        return id
      end
      return nil
    end

    alias id toot_id

    def valid?
      return absolute? && id.present?
    end

    def to_md
      toot = service.fetch_status(id)
      raise "Toot '#{self}' not found" unless toot
      raise "Toot '#{self}' not found (#{toot['error']})" if toot['error']
      template = Template.new('toot_clipping.md')
      template[:account] = toot['account']
      template[:status] = TootParser.new(toot['content']).to_md
      template[:attachments] = toot['media_attachments']
      template[:url] = toot['url']
      return template.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        if ['mastodon', 'pleroma'].include?(Environment.controller_name)
          @service = Environment.sns_class.new(uri)
        else
          @service = MastodonService.new(uri)
        end
      end
      return @service
    end
  end
end
