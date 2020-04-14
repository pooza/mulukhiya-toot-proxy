module Mulukhiya
  module Dolphin
    class Account < Mulukhiya::Misskey::Account
      def recent_note
        rows = Postgres.instance.execute('recent_note', {id: id})
        return Status[rows.first['id']] if rows.present?
        return nil
      end

      alias recent_status recent_note

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
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, host: acct.domain)
        elsif key.key?(:token)
          return nil if key[:token].nil?
          return Account.first(key)
        end
        return Account.first(key)
      end
    end
  end
end
