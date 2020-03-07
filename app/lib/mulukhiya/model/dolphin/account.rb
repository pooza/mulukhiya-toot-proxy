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
    end
  end
end
