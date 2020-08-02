module Mulukhiya
  module Dolphin
    class Account < Mulukhiya::Misskey::Account
      include Package

      def recent_status
        note = DolphinService.new.notes(account_id: id)&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_note recent_status

      def uri
        unless @uri
          if host
            @uri = NoteURI.parse("https://#{host}")
          else
            @uri = NoteURI.parse(config['/dolphin/url'])
          end
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(username: acct.username, host: acct.domain)
        end
        return nil if key.key?(:token) && key[:token].nil?
        return first(key)
      end
    end
  end
end
