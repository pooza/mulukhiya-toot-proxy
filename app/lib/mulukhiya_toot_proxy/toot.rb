require 'sanitize'

module MulukhiyaTootProxy
  class Toot
    attr_reader :params

    def initialize(key)
      @params = Mastodon.lookup_toot(key[:id].to_i)
      raise Ginseng::NotFoundError, "Toot '#{key.to_json}' not found" unless @params.present?
      @config = Config.instance
    end

    def id
      return self[:id]&.to_i
    end

    def account
      @account ||= Account.new(id: self[:account_id])
      return @account
    end

    def local?
      return @params[:local]
    end

    def text
      @text ||= Toot.sanitize(self[:text])
      return @text
    end

    def uri
      unless @uri
        @uri = MastodonURI.parse(self[:url]) if self[:url].present?
        @uri = MastodonURI.parse(self[:uri]) if self[:uri].present?
      end
      return @uri
    end

    def to_md
      return uri.to_md if uri
      template = Template.new('toot_clipping.md')
      template[:account] = account.to_h
      template[:status] = text
      template[:url] = uri.to_s
      return template.to_s
    end

    alias to_h params

    def [](key)
      return @params[key]
    end

    def self.sanitize(text)
      text.gsub!(/<br.*?>/, "\n")
      text.gsub!(%r{</p.*?>}, "\n\n")
      text = Sanitize.clean(text)
      return text.strip
    end
  end
end
