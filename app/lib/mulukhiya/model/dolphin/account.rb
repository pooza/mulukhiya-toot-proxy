module Mulukhiya
  module Dolphin
    class Account < Mulukhiya::Misskey::Account
      def uri
        unless @uri
          if host
            @uri = NoteURI.parse("https://#{host}")
          else
            @uri = NoteURI.parse(Config.instance['/dolphin/url'])
          end
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def self.get(key)
        if key[:acct]
          acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, host: acct.domain)
        end
        return Account.first(key)
      end
    end
  end
end
