module Mulukhiya
  class TootURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @logger = Logger.new
    end

    def toot_id
      @config['/parser/toot/url/patterns'].each do |pattern|
        next unless matches = path.match(pattern)
        id = matches[1]
        return id.to_i if id.match?(/^[[:digit:]]+$/)
        return id
      end
      return nil
    end

    alias id toot_id

    def account_id
      return nil unless matches = %r{^/users/([[:word:]]+)/statuses/[[:digit:]]+}i.match(path)
      return matches[1]
    end

    def valid?
      return absolute? && id.present?
    end

    def local?
      return Ginseng::URI.parse(toot['account']['url']).host == Environment.domain_name
    rescue => e
      @logger.error(e)
      return false
    end

    def publicize!
      self.path = "/@#{account_id}/#{toot_id}" if account_id && toot_id
      return self
    end

    def publicize
      return clone.publicize!
    end

    def visibility
      return toot['visibility']
    end

    def public?
      return visibility == 'public'
    end

    def to_md
      template = Template.new('status_clipping.md')
      template[:account] = toot['account']
      template[:status] = TootParser.new(toot['content']).to_md
      template[:attachments] = toot['media_attachments']
      template[:url] = self
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
        if ['mastodon', 'pleroma'].member?(Environment.controller_name)
          @service = Environment.sns_class.new(uri)
        else
          @service = MastodonService.new(uri)
        end
        @service.token = nil
      end
      return @service
    end

    def toot
      unless @toot
        @toot = service.fetch_status(id)
        raise "Toot '#{self}' not found" unless @toot
        raise "Toot '#{self}' is invalid (#{toot['error']})" if @toot['error']
      end
      return @toot
    end

    alias status toot
  end
end
