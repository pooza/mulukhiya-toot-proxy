module Mulukhiya
  module Misskey
    class Application < Sequel::Model(:app)
      include Package

      def scopes
        matches = permission.match(/{(.*?)}/)[1]
        return matches.split(',').to_set if matches
        raise Ginseng::GatewayError, "Invalid scopes '#{permission}'"
      rescue => e
        logger.error(error: e)
        return []
      end
    end
  end
end
