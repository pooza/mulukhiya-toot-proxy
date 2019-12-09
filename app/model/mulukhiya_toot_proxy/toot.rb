module MulukhiyaTootProxy
  class Toot < Sequel::Model(:statuses)
    def account
      @account ||= Account[account_id]
      return @account
    end

    def local?
      return local
    end

    def uri
      unless @uri
        @uri = MastodonURI.parse(self[:url]) if self[:url].present?
        @uri = MastodonURI.parse(self[:uri]) if self[:uri].present?
      end
      return @uri
    end

    alias to_h values

    def to_md
      return uri.to_md if uri
      template = Template.new('toot_clipping.md')
      template[:account] = account.to_h
      template[:status] = TootParser.new(text).to_md
      template[:url] = uri.to_s
      return template.to_s
    end
  end
end
